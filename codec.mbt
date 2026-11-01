///|
priv struct WireLog {
  version : Int32
  operations : Array[Operation]
} derive(ToJson, FromJson)

///|
/// Version 1 operation envelope. This does not encrypt or authenticate the payload.
pub fn encode_operations(operations : Array[Operation]) -> String {
  ToJson::to_json(WireLog::{ version: 1, operations, }).stringify()
}

///|
/// Decode and validate a versioned operation log before exposing it to callers.
pub fn decode_operations(text : String) -> Result[Array[Operation], SyncError] {
  let wire : WireLog = @json.from_json(@json.parse(text)) catch {
    _ => return Err(InvalidJson)
  }
  if wire.version != 1 {
    return Err(UnsupportedVersion)
  }
  let check = Replica::new("decode")
  match check.merge_checked(wire.operations) {
    Err(e) => Err(e)
    Ok(_) => Ok(check.operations())
  }
}
