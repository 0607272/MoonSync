///|
test "checked editing rejects invalid ranges without partial operations" {
  let a = @moonsync.Replica::new("a")
  a.text_insert("body", 0, "cat")
  let before = a.operations().length()
  assert_true(a.try_text_insert("body", -1, "x") is Err(_))
  assert_true(a.try_text_insert("body", 4, "x") is Err(_))
  assert_true(a.try_text_delete("body", 0, -1) is Err(_))
  assert_true(a.try_text_delete("body", 2, 2) is Err(_))
  assert_eq(a.operations().length(), before)
  assert_eq(a.text("body"), "cat")
  assert_true(a.try_text_insert("body", 3, "!") is Ok(_))
  assert_true(a.try_text_delete("body", 4, 0) is Ok(_))
  assert_true(a.try_text_delete("body", 0, 4) is Ok(_))
  assert_eq(a.text("body"), "")
}

///|
test "legacy text methods ignore invalid ranges instead of panicking" {
  let a = @moonsync.Replica::new("a")
  a.text_insert("body", -1, "x")
  a.text_delete("body", -1, 2)
  assert_eq(a.text("body"), "")
  assert_eq(a.operations().length(), 0)
}
