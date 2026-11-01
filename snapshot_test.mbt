///|
test "snapshot restores identity state and next operation clock" {
  let a = @moonsync.Replica::new("phone")
  let remote = @moonsync.Replica::new("laptop")
  for _ in 0..<6 {
    remote.set("title", "remote")
  }
  a.merge(remote.operations())
  a.text_insert("body", 0, "恢复")
  a.add("tags", "saved")
  a.remove("tags", "saved")
  let saved = a.snapshot()
  match @moonsync.Replica::restore(saved) {
    Ok(restored) => {
      assert_eq(restored.text("body"), a.text("body"))
      assert_eq(restored.get("title"), a.get("title"))
      assert_true(restored.operations() == a.operations())
      restored.set("title", "after restart")
      a.merge(restored.operations())
      assert_eq(a.get("title"), Some("after restart"))
      assert_eq(a.operations().length(), restored.operations().length())
    }
    Err(_) => abort("valid snapshot rejected")
  }
}

///|
test "restore rejects malformed version identity and clock" {
  assert_true(@moonsync.Replica::restore("{}") is Err(_))
  assert_true(
    @moonsync.Replica::restore(
      "{\"version\":2,\"replica\":\"a\",\"clock\":0,\"operations\":[]}",
    )
    is Err(_),
  )
  assert_true(
    @moonsync.Replica::restore(
      "{\"version\":1,\"replica\":\"\",\"clock\":0,\"operations\":[]}",
    )
    is Err(_),
  )
  assert_true(
    @moonsync.Replica::restore(
      "{\"version\":1,\"replica\":\"a\",\"clock\":-1,\"operations\":[]}",
    )
    is Err(_),
  )
  assert_true(
    @moonsync.Replica::restore(
      "{\"version\":1,\"replica\":\"a\",\"clock\":0,\"operations\":[[\"Add\",{\"replica\":\"b\",\"counter\":3},\"t\",\"v\"]]}",
    )
    is Err(_),
  )
}
