///|
/// A globally unique operation identifier.
pub struct OpId {
  replica : String
  counter : Int
}

///|
pub impl Eq for OpId with fn equal(self, other) {
  self.replica == other.replica && self.counter == other.counter
}

///|
pub impl Hash for OpId with fn hash(self) {
  let hasher = Hasher()
  hasher.combine(self.replica)
  hasher.combine(self.counter)
  hasher.finalize()
}

///|
pub impl Hash for OpId with fn hash_combine(self, hasher) {
  hasher.combine(self.replica)
  hasher.combine(self.counter)
}

///|
pub impl Show for OpId with fn output(self, logger) {
  logger.write_string(self.replica)
  logger.write_string("#")
  logger.write_string(self.counter.to_string())
}

///|
pub enum Operation {
  Register(OpId, String, String)
  Add(OpId, String, String)
  Remove(OpId, String, String, Array[OpId])
  TextInsert(OpId, String, OpId?, Char)
  TextRemove(OpId, String, OpId)
}

///|
/// A mutable offline replica. Operations are retained so a replica can exchange them later.
pub struct Replica {
  id : String
  mut next : Int
  ops : Array[Operation]
}

///|
pub fn Replica::new(id : String) -> Replica {
  { id, next: 0, ops: [], }
}

///|
fn Replica::fresh_id(self : Replica) -> OpId {
  self.next += 1
  { replica: self.id, counter: self.next, }
}

///|
/// Set a register value. Concurrent writes use `(counter, replica)` as a stable tie-break.
pub fn Replica::set(self : Replica, key : String, value : String) -> Unit {
  self.ops.push(Register(self.fresh_id(), key, value))
}

///|
/// Add a value to an observed-remove set.
pub fn Replica::add(self : Replica, key : String, value : String) -> Unit {
  self.ops.push(Add(self.fresh_id(), key, value))
}

///|
/// Remove all add operations for `value` currently observed by this replica.
pub fn Replica::remove(self : Replica, key : String, value : String) -> Unit {
  let observed = self.observed_adds(key, value)
  self.ops.push(Remove(self.fresh_id(), key, value, observed))
}

///|
fn Replica::observed_adds(
  self : Replica,
  key : String,
  value : String,
) -> Array[OpId] {
  let adds : Map[OpId, Bool] = Map::Map([])
  let removed : Map[OpId, Bool] = Map::Map([])
  for op in self.ops {
    match op {
      Add(id, k, v) if k == key && v == value => adds.set(id, true)
      Remove(_, k, v, ids) if k == key && v == value =>
        for id in ids {
          removed.set(id, true)
        }
      _ => ()
    }
  }
  let out : Array[OpId] = []
  adds.each(fn(id, _) { if !removed.contains(id) { out.push(id) } })
  out
}

///|
/// Return all operations known by this replica.
pub fn Replica::operations(self : Replica) -> Array[Operation] {
  self.ops.map(fn(op) { op.copy() })
}

///|
/// Merge operations received from another offline replica. Duplicate operations are ignored.
pub fn Replica::merge(self : Replica, incoming : Array[Operation]) -> Unit {
  let known : Map[OpId, Bool] = Map::Map([])
  for op in self.ops {
    known.set(op.id(), true)
  }
  for op in incoming {
    if !known.contains(op.id()) {
      known.set(op.id(), true)
      self.ops.push(op.copy())
      let id = op.id()
      if id.counter >= self.next {
        self.next = id.counter
      }
    }
  }
}

///|
/// Read the deterministically selected register value.
pub fn Replica::get(self : Replica, key : String) -> String? {
  let mut best : (OpId, String)? = None
  for op in self.ops {
    match op {
      Register(id, k, value) if k == key =>
        match best {
          None => best = Some((id, value))
          Some((old, _)) if id.counter > old.counter ||
            (id.counter == old.counter && id.replica.compare(old.replica) > 0) =>
            best = Some((id, value))
          _ => ()
        }
      _ => ()
    }
  }
  best.map(fn(x) { x.1 })
}

///|
/// Return the visible members of an observed-remove set.
pub fn Replica::members(self : Replica, key : String) -> Array[String] {
  let adds : Map[OpId, String] = Map::Map([])
  let removed : Map[OpId, Bool] = Map::Map([])
  for op in self.ops {
    match op {
      Add(id, k, value) if k == key => adds.set(id, value)
      Remove(_, k, _, ids) if k == key =>
        for id in ids {
          removed.set(id, true)
        }
      _ => ()
    }
  }
  let result : Array[String] = []
  adds.each(fn(id, value) {
    if !removed.contains(id) && !result.contains(value) {
      result.push(value)
    }
  })
  result.sort_by(fn(a, b) { a.compare(b) })
  result
}

///|
/// Insert text at a visible character offset.
pub fn Replica::text_insert(
  self : Replica,
  key : String,
  index : Int,
  text : String,
) -> Unit {
  let visible = self.text_nodes(key)
  let mut after : OpId? = if index == 0 {
    None
  } else {
    Some(visible[index - 1].0)
  }
  for ch in text {
    let id = self.fresh_id()
    self.ops.push(TextInsert(id, key, after, ch))
    after = Some(id)
  }
}

///|
/// Delete `count` visible characters starting at `index`.
pub fn Replica::text_delete(
  self : Replica,
  key : String,
  index : Int,
  count : Int,
) -> Unit {
  let visible = self.text_nodes(key)
  for i = index, n = 0; i < visible.length() && n < count; i = i + 1, n = n + 1 {
    self.ops.push(TextRemove(self.fresh_id(), key, visible[i].0))
  }
}

///|
/// Render a text CRDT as a string.
pub fn Replica::text(self : Replica, key : String) -> String {
  String::from_array(self.text_nodes(key).map(fn(x) { x.1 }))
}

///|
fn Replica::text_nodes(self : Replica, key : String) -> Array[(OpId, Char)] {
  let removed : Map[OpId, Bool] = Map::Map([])
  let nodes : Array[(OpId, OpId?, Char)] = []
  for op in self.ops {
    match op {
      TextInsert(id, k, after, ch) if k == key => nodes.push((id, after, ch))
      TextRemove(_, k, target) if k == key => removed.set(target, true)
      _ => ()
    }
  }
  let result : Array[(OpId, Char)] = []
  fn visit(
    after : OpId?,
    nodes : Array[(OpId, OpId?, Char)],
    removed : Map[OpId, Bool],
    result : Array[(OpId, Char)],
  ) -> Unit {
    let children = nodes.filter(fn(n) { n.1 == after })
    children.sort_by(fn(a, b) { compare_ids(a.0, b.0) })
    for node in children {
      if !removed.contains(node.0) {
        result.push((node.0, node.2))
      }
      visit(Some(node.0), nodes, removed, result)
    }
  }
  visit(None, nodes, removed, result)
  result
}

///|
fn compare_ids(a : OpId, b : OpId) -> Int {
  if a.counter > b.counter {
    -1
  } else if a.counter < b.counter {
    1
  } else {
    a.replica.compare(b.replica)
  }
}

///|
fn Operation::id(self : Operation) -> OpId {
  match self {
    Register(id, _, _) => id
    Add(id, _, _) => id
    Remove(id, _, _, _) => id
    TextInsert(id, _, _, _) => id
    TextRemove(id, _, _) => id
  }
}

///|
fn Operation::copy(self : Operation) -> Operation {
  match self {
    Remove(id, key, value, tags) => Remove(id, key, value, tags.copy())
    _ => self
  }
}
