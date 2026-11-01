///|
test "checked merge rejects conflicting IDs atomically" {
  let a = Replica::new("a")
  a.set("title", "original")
  let conflict = Register({ replica: "a", counter: 1, }, "title", "forged")
  let valid = Add({ replica: "b", counter: 1, }, "tags", "new")
  assert_true(a.merge_checked([valid, conflict]) is Err(ConflictingId))
  assert_eq(a.operations().length(), 1)
  assert_eq(a.get("title"), Some("original"))
  assert_true(a.merge_checked(a.operations()) is Ok(0))
}

///|
test "checked merge rejects invalid clocks and text references" {
  let a = Replica::new("a")
  assert_true(
    a.merge_checked([Add({ replica: "", counter: 1, }, "t", "x")]) is Err(_),
  )
  assert_true(
    a.merge_checked([Add({ replica: "b", counter: 0, }, "t", "x")]) is Err(_),
  )
  let id = { replica: "b", counter: 2, }
  assert_true(
    a.merge_checked([TextInsert(id, "body", Some(id), 'x')]) is Err(_),
  )
  let wrong = { replica: "b", counter: 1, }
  assert_true(
    a.merge_checked([Add(wrong, "tags", "x"), TextRemove(id, "body", wrong)])
    is Err(_),
  )
  assert_eq(a.operations().length(), 0)
}

///|
test "late text predecessor is accepted but must have the right type and key" {
  let a = Replica::new("a")
  let first = { replica: "b", counter: 1, }
  let second = { replica: "b", counter: 2, }
  assert_true(
    a.merge_checked([TextInsert(second, "body", Some(first), 'b')]) is Ok(1),
  )
  assert_eq(a.text("body"), "")
  assert_true(
    a.merge_checked([TextInsert(first, "wrong", None, 'a')]) is Err(_),
  )
  assert_true(a.merge_checked([TextInsert(first, "body", None, 'a')]) is Ok(1))
  assert_eq(a.text("body"), "ab")
}
