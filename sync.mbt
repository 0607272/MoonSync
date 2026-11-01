///|
/// An exact set of received operation IDs, including gaps in delivery.
pub struct Receipt {
  priv ids : Map[OpId, Bool]
}

///|
priv struct WireReceipt {
  version : Int
  ids : Array[OpId]
} derive(ToJson, FromJson)

///|
pub fn Replica::receipt(self : Replica) -> Receipt {
  let ids : Map[OpId, Bool] = Map::Map([])
  for op in self.ops {
    ids.set(op.id(), true)
  }
  { ids, }
}

///|
/// Return isolated copies of only those operations the peer has not acknowledged.
pub fn Replica::missing_operations(
  self : Replica,
  receipt : Receipt,
) -> Array[Operation] {
  self.ops
  .filter(fn(op) { !receipt.ids.contains(op.id()) })
  .map(fn(op) { op.copy() })
}

///|
pub fn Receipt::encode(self : Receipt) -> String {
  let ids = self.ids.keys().to_array()
  ids.sort_by(fn(a, b) { compare_ids(a, b) })
  ToJson::to_json(WireReceipt::{ version: 1, ids, }).stringify()
}

///|
pub fn Receipt::decode(text : String) -> Result[Receipt, SyncError] {
  let wire : WireReceipt = @json.from_json(@json.parse(text)) catch {
    _ => return Err(InvalidJson)
  }
  if wire.version != 1 {
    return Err(UnsupportedVersion)
  }
  let ids : Map[OpId, Bool] = Map::Map([])
  for id in wire.ids {
    if !valid_id(id) {
      return Err(InvalidOperation)
    }
    ids.set(id, true)
  }
  Ok({ ids, })
}
