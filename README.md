# MoonSync

MoonSync is a MoonBit library for deterministic offline state merging. It is designed for notes, forms, configuration editors, and other small applications that need to keep working without a network connection.

## Current scope

- Last-writer-wins registers for key/value state.
- Observed-remove sets with concurrent-add preservation.
- RGA-style character sequences for short text.
- Globally unique operation IDs and duplicate-safe operation exchange.
- A runnable two-replica offline editing example.
- Checked edits and atomic merge validation, with conflicting-ID rejection.
- Versioned JSON exchange, restart snapshots, and exact receipt based delta sync.

The library does not provide a network transport, accounts, databases, web UI, or encryption. Applications store snapshot strings and exchange JSON payloads through their own storage and transport. Use `merge_checked` when you need error details; `merge` rejects a bad batch silently for compatibility.

## Run

Install the current official MoonBit toolchain from [moonbitlang.com/download](https://www.moonbitlang.com/download).
The source uses the current canonical `Int32` type spelling; older compilers
that only recognize `Int` are not supported. CI prints the exact toolchain
version and checks formatting and generated interfaces alongside all three backends.

```bash
moon check
moon test
moon run cmd/main
moon run cmd/recovery
```

The first example merges offline text edits. The recovery example restores a replica from a snapshot, edits on two devices, transfers JSON deltas, and verifies the resulting text is `Hello MoonBit` with zero operations left to synchronize. It uses in-memory strings; the application supplies actual file/browser storage.

## API sketch

```moonbit
let local = @moonsync.Replica::new("device-a")
local.set("title", "draft")
local.add("tags", "offline")
local.text_insert("body", 0, "hello")

let remote_ops = local.operations()
let peer = @moonsync.Replica::new("device-b")
let result = peer.merge_checked(remote_ops)
```

Register writes use a deterministic `(counter, replica)` ordering, with a Lamport counter that advances after observing remote operations. Text siblings use descending counters, then ascending MoonBit string comparison for replica IDs (shortlex in the tested toolchain). New local insertions therefore appear immediately after their selected predecessor. Set members use ascending MoonBit string comparison.

The tests cover convergence, observed removal, causal register writes, insertion offsets, Unicode, atomic rejection, defensive copies, JSON errors, snapshot recovery, and delivery gaps. The three-replica suite exercises 24 deterministic schedules with reverse and duplicate delivery; it is not a proof of all possible executions.

## Restart and synchronize

```moonbit
// Save this string atomically using the host application's storage.
let saved = local.snapshot()
match @moonsync.Replica::restore(saved) {
  Ok(restored) => {
    let missing = restored.missing_operations(peer.receipt())
    let payload = @moonsync.encode_operations(missing)
    match @moonsync.decode_operations(payload) {
      Ok(ops) => { let _ = peer.merge_checked(ops) }
      Err(_) => () // Report/retry using the application's error policy.
    }
  }
  Err(_) => () // Preserve the bad snapshot for diagnosis; do not reuse its identity.
}
```

Use nonempty unique replica IDs. Restore an identity on only one active writer, and save before acknowledging durable receipt. Never fork two writable copies of one snapshot. A `Receipt` records exact operation IDs, not just a maximum clock; a message arriving out of order cannot hide earlier missing operations. Serialize receipts with `Receipt::encode` and `Receipt::decode`. Receipts are O(number of operations), and are not compressed version vectors.

`try_text_insert` and `try_text_delete` return `Result[Unit, SyncError]`. Negative offsets, offsets past the end and deletions extending past the end are rejected atomically. Legacy `text_insert`/`text_delete` ignore an invalid request. `merge_checked` returns the number of new operations; exact duplicates return zero. ID conflicts, invalid clocks and known cross-key/type dependencies reject the entire batch. Missing dependencies are retained and checked again when they arrive. Validation is structural, not authentication.

## Integrate

The configured package is `0607272/moonsync`, version `0.1.0`. It has **not been published yet**. After publication, install it with:

```bash
moon add 0607272/moonsync@0.1.0
```

Add `"0607272/moonsync"` to the consuming package's `import` list in `moon.pkg` to use the `@moonsync` alias shown above.

## Limitations

This is an experimental library for short text and small operation logs. Exchange data with trusted peers; validation does not authenticate a device or constrain payload size. Callers must limit message size and operation count. Text offsets count MoonBit characters, not user-perceived grapheme clusters. Rendering recursively scans the log and may be expensive or exhaust the stack on large documents. Clock counters are signed 32-bit integers; do not run a replica to clock exhaustion. There is no operation compaction, compressed version vector, database adapter, network transport, encryption, or thread synchronization. Snapshots retain the entire history, including deleted text: deletion is not secure erasure.

## Project status

This is an original MoonBit implementation for the MoonBit Hackathon, inspired by standard CRDT concepts (LWW registers, observed-remove sets, RGA-style sequences). It is not a port of an existing implementation. JSON parsing and compiler-derived codecs use `moonbitlang/core/json`, from the Apache-2.0 MoonBit standard library. No third-party CRDT implementation was copied.

The suite contains 23 tests on each of Wasm, WasmGC and JavaScript. CI installs the current official toolchain, prints its version, and runs checks/builds/tests/examples on those three targets, plus formatting and generated-interface checks. See the [actual workflow results](https://github.com/0607272/MoonSync/actions/workflows/check.yml) for the current revision. Mooncakes publication is still pending.

## License

Apache-2.0. See [LICENSE](LICENSE).
