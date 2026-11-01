///|
test "JSON operation exchange round trips all kinds and Unicode" {
  let a = @moonsync.Replica::new("device-a")
  a.set("title", "笔记\n\"quoted\"")
  a.add("tags", "离线")
  a.remove("tags", "离线")
  a.text_insert("body", 0, "你好🌙")
  a.text_delete("body", 1, 1)
  let wire = @moonsync.encode_operations(a.operations())
  match @moonsync.decode_operations(wire) {
    Ok(ops) => {
      assert_true(ops == a.operations())
      let b = @moonsync.Replica::new("device-b")
      assert_true(b.merge_checked(ops) is Ok(_))
      assert_eq(b.get("title"), a.get("title"))
      assert_eq(b.text("body"), a.text("body"))
      assert_eq(b.members("tags"), a.members("tags"))
    }
    Err(_) => abort("valid wire payload rejected")
  }
}

///|
test "JSON decoder rejects malformed schema version and operation data" {
  assert_true(@moonsync.decode_operations("not json") is Err(_))
  assert_true(@moonsync.decode_operations("{}") is Err(_))
  assert_true(
    @moonsync.decode_operations("{\"version\":2,\"operations\":[]}") is Err(_),
  )
  assert_true(
    @moonsync.decode_operations(
      "{\"version\":1,\"operations\":[[\"Add\",{\"replica\":\"b\",\"counter\":0},\"k\",\"v\"]]}",
    )
    is Err(_),
  )
  assert_true(
    @moonsync.decode_operations(@moonsync.encode_operations([])) is Ok([]),
  )
}
