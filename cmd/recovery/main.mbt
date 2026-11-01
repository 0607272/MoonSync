///|
fn main {
  let phone = @moonsync.Replica::new("phone")
  phone.set("title", "Field notes")
  phone.text_insert("body", 0, "Moon")
  phone.add("tags", "offline")
  let laptop = @moonsync.Replica::new("laptop")
  laptop.merge(phone.operations())
  // These strings can be stored in a file or browser storage by the host application.
  let saved = laptop.snapshot()
  let restarted = match @moonsync.Replica::restore(saved) {
    Ok(replica) => replica
    Err(_) => abort("restore failed")
  }
  phone.text_insert("body", 4, "Bit")
  restarted.text_insert("body", 0, "Hello ")
  restarted.set("title", "Recovered notes")
  let receipt = match @moonsync.Receipt::decode(restarted.receipt().encode()) {
    Ok(receipt) => receipt
    Err(_) => abort("receipt failed")
  }
  let delta = phone.missing_operations(receipt)
  let payload = @moonsync.encode_operations(delta)
  let received = match @moonsync.decode_operations(payload) {
    Ok(ops) => ops
    Err(_) => abort("decode failed")
  }
  match restarted.merge_checked(received) {
    Ok(_) => ()
    Err(_) => abort("merge failed")
  }
  phone.merge(restarted.missing_operations(phone.receipt()))
  let converged = phone.text("body") == restarted.text("body") &&
    phone.get("title") == restarted.get("title")
  if !converged || phone.text("body") != "Hello MoonBit" {
    abort("recovery scenario did not converge")
  }
  println("restored text = \{restarted.text("body")}")
  println("phone delta operations = \{delta.length()}")
  println(
    "remaining operations = \{phone.missing_operations(restarted.receipt()).length()}",
  )
  println("replicas converge = \{converged}")
}
