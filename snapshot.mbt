///|
priv struct SavedReplica {
  version : Int32
  replica : String
  clock : Int32
  operations : Array[Operation]
} derive(ToJson, FromJson)

///|
/// Serialize identity, clock and full operation log. The caller stores this string atomically.
pub fn Replica::snapshot(self : Replica) -> String {
  ToJson::to_json(SavedReplica::{
    version: 1,
    replica: self.id,
    clock: self.next,
    operations: self.operations(),
  }).stringify()
}

///|
/// Restore a saved replica. Never edit two live copies of the same restored identity.
pub fn Replica::restore(text : String) -> Result[Replica, SyncError] {
  let saved : SavedReplica = @json.from_json(@json.parse(text)) catch {
    _ => return Err(InvalidJson)
  }
  if saved.version != 1 {
    return Err(UnsupportedVersion)
  }
  if saved.replica == "" || saved.clock < 0 || saved.clock >= 2147483647 {
    return Err(InvalidReplica)
  }
  let restored = Replica::new(saved.replica)
  match restored.merge_checked(saved.operations) {
    Err(e) => return Err(e)
    Ok(_) => ()
  }
  if saved.clock < restored.next {
    return Err(InvalidReplica)
  }
  restored.next = saved.clock
  Ok(restored)
}
