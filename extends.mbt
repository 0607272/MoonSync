///|
pub extend OpId with Eq::{equal, not_equal}

///|
pub extend OpId with Hash::{hash, hash_combine}

///|
pub extend OpId with Show::{output, to_string}

///|
pub extend OpId with ToJson::{to_json}

///|
pub extend OpId with @json.FromJson::{from_json}

///|
pub extend Operation with ToJson::{to_json}

///|
pub extend Operation with @json.FromJson::{from_json}
