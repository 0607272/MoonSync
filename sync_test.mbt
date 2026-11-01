///|
test "delta exchange fills holes left by out of order delivery" {
  let a = @moonsync.Replica::new("a")
  a.set("one", "1")
  a.set("two", "2")
  a.set("three", "3")
  let b = @moonsync.Replica::new("b")
  let ops = a.operations()
  b.merge([ops[2]])
  let missing = a.missing_operations(b.receipt())
  assert_eq(missing.length(), 2)
  b.merge(missing)
  assert_eq(b.get("one"), Some("1"))
  assert_eq(b.get("two"), Some("2"))
  assert_eq(a.missing_operations(b.receipt()).length(), 0)
  assert_true(b.merge_checked(missing) is Ok(0))
}

///|
test "receipt serialization and delta mutations remain isolated" {
  let a = @moonsync.Replica::new("a")
  a.add("tags", "x")
  a.remove("tags", "x")
  let b = @moonsync.Replica::new("b")
  let wire = b.receipt().encode()
  match @moonsync.Receipt::decode(wire) {
    Ok(receipt) => {
      let missing = a.missing_operations(receipt)
      assert_eq(missing.length(), 2)
      match missing[1] {
        @moonsync.Remove(_, _, _, tags) => tags.clear()
        _ => abort("expected remove")
      }
      assert_eq(a.members("tags"), ([] : Array[String]))
    }
    Err(_) => abort("receipt rejected")
  }
  assert_true(@moonsync.Receipt::decode("{}") is Err(_))
  assert_true(@moonsync.Receipt::decode("{\"version\":2,\"ids\":[]}") is Err(_))
}
