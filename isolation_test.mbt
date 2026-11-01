///|
test "exported removal tags cannot mutate a replica" {
  let a = @moonsync.Replica::new("a")
  a.add("tags", "draft")
  a.remove("tags", "draft")
  let exported = a.operations()
  match exported[1] {
    @moonsync.Remove(_, _, _, tags) => tags.clear()
    _ => abort("expected removal")
  }
  assert_eq(a.members("tags"), ([] : Array[String]))
}

///|
test "incoming removal tags cannot mutate a replica after merge" {
  let a = @moonsync.Replica::new("a")
  a.add("tags", "draft")
  a.remove("tags", "draft")
  let incoming = a.operations()
  let b = @moonsync.Replica::new("b")
  b.merge(incoming)
  match incoming[1] {
    @moonsync.Remove(_, _, _, tags) => tags.clear()
    _ => abort("expected removal")
  }
  assert_eq(b.members("tags"), ([] : Array[String]))
}
