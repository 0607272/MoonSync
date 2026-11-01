///|
/// Validate a complete candidate log before appending anything. Returns new operation count.
/// Missing dependencies are allowed; any dependency that arrives later is rechecked.
pub fn Replica::merge_checked(
  self : Replica,
  incoming : Array[Operation],
) -> Result[Int32, SyncError] {
  let all : Map[OpId, Operation] = Map::Map([])
  for op in self.ops {
    all.set(op.id(), op)
  }
  let mut added = 0
  for op in incoming {
    let id = op.id()
    if !valid_id(id) {
      return Err(InvalidOperation)
    }
    match all.get(id) {
      Some(old) if old != op => return Err(ConflictingId)
      Some(_) => ()
      None => {
        all.set(id, op)
        added += 1
      }
    }
  }
  for op in all.values() {
    let id = op.id()
    match op {
      TextInsert(_, key, Some(parent), _) | TextRemove(_, key, parent) => {
        if !valid_id(parent) || parent.counter >= id.counter {
          return Err(InvalidOperation)
        }
        match all.get(parent) {
          Some(TextInsert(_, k, _, _)) if k == key => ()
          Some(_) => return Err(InvalidOperation)
          None => ()
        }
      }
      Remove(_, key, value, tags) =>
        for tag in tags {
          if !valid_id(tag) || tag.counter >= id.counter {
            return Err(InvalidOperation)
          }
          match all.get(tag) {
            Some(Add(_, k, v)) if k == key && v == value => ()
            Some(_) => return Err(InvalidOperation)
            None => ()
          }
        }
      _ => ()
    }
  }
  self.merge_validated(incoming)
  Ok(added)
}

///|
fn valid_id(id : OpId) -> Bool {
  id.replica != "" && id.counter > 0 && id.counter < 2147483647
}
