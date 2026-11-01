///|
test "register converges and breaks concurrent ties by replica" {
  let a = @moonsync.Replica::new("alice")
  let b = @moonsync.Replica::new("bob")
  a.set("title", "Alice")
  b.set("title", "Bob")
  a.merge(b.operations())
  b.merge(a.operations())
  assert_eq(b.get("title"), a.get("title"))
  assert_true(a.get("title") is Some(_))
}

///|
test "observed remove preserves a concurrent add" {
  let a = @moonsync.Replica::new("a")
  a.add("tags", "draft")
  let b = @moonsync.Replica::new("b")
  b.merge(a.operations())
  a.remove("tags", "draft")
  b.add("tags", "draft")
  a.merge(b.operations())
  b.merge(a.operations())
  assert_eq(a.members("tags"), ["draft"])
  assert_eq(b.members("tags"), a.members("tags"))
}

///|
test "observed remove deletes known adds and supports readd" {
  let a = @moonsync.Replica::new("a")
  a.add("tags", "draft")
  a.remove("tags", "draft")
  assert_eq(a.members("tags"), ([] : Array[String]))
  a.add("tags", "draft")
  assert_eq(a.members("tags"), ["draft"])
}

///|
test "concurrent text inserts converge in stable order" {
  let a = @moonsync.Replica::new("alice")
  let b = @moonsync.Replica::new("bob")
  a.text_insert("body", 0, "A")
  b.text_insert("body", 0, "B")
  a.merge(b.operations())
  b.merge(a.operations())
  assert_eq(a.text("body"), "BA")
  assert_eq(b.text("body"), "BA")
}

///|
test "text deletion removes only the selected character" {
  let replica = @moonsync.Replica::new("local")
  replica.text_insert("body", 0, "cat")
  replica.text_delete("body", 1, 1)
  assert_eq(replica.text("body"), "ct")
}

///|
test "a write after observing remote operations wins" {
  let a = @moonsync.Replica::new("a")
  let b = @moonsync.Replica::new("b")
  for _ in 0..<8 {
    a.set("title", "old")
  }
  b.merge(a.operations())
  b.set("title", "new")
  a.merge(b.operations())
  assert_eq(a.get("title"), Some("new"))
  assert_eq(b.get("title"), Some("new"))
}

///|
test "set member arrays have deterministic order" {
  let a = @moonsync.Replica::new("a")
  a.add("tags", "z")
  a.add("tags", "a")
  let b = @moonsync.Replica::new("b")
  let ops = a.operations()
  b.merge([ops[1], ops[0]])
  assert_eq(a.members("tags"), ["a", "z"])
  assert_eq(b.members("tags"), a.members("tags"))
}

///|
test "text insertion honors middle and leading offsets" {
  let a = @moonsync.Replica::new("a")
  a.text_insert("body", 0, "ac")
  a.text_insert("body", 1, "b")
  assert_eq(a.text("body"), "abc")
  a.text_insert("body", 0, "!")
  assert_eq(a.text("body"), "!abc")
}
