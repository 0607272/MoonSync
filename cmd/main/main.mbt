///|
/// Runnable offline merge demonstration.
fn main {
  let alice = @moonsync.Replica::new("alice")
  let bob = @moonsync.Replica::new("bob")
  alice.text_insert("body", 0, "A")
  bob.text_insert("body", 0, "B")
  alice.set("title", "offline note")
  alice.merge(bob.operations())
  bob.merge(alice.operations())
  let title = match alice.get("title") {
    Some(value) => value
    None => "<missing>"
  }
  println("title = \{title}")
  println("merged body = \{alice.text("body")}")
  println("replicas converge = \{alice.text("body") == bob.text("body")}")
}
