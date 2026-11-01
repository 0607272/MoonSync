# MoonSync

MoonSync is a MoonBit library for deterministic offline state merging. It is designed for notes, forms, configuration editors, and other small applications that need to keep working without a network connection.

## Current scope

- Last-writer-wins registers for key/value state.
- Observed-remove sets with concurrent-add preservation.
- RGA-style character sequences for short text.
- Globally unique operation IDs and duplicate-safe operation exchange.
- A runnable two-replica offline editing example.

The library does not provide a network protocol, accounts, databases, web UI, or encryption. Applications exchange `Replica::operations()` through their own transport and call `Replica::merge()` when operations arrive.

## Run

Requires MoonBit 0.10.14 or newer.

```bash
moon check
moon test
moon run cmd/main
```

The example creates two offline replicas, edits the same text independently, exchanges their operation logs, and prints whether both replicas converge.

## API sketch

```moonbit
let local = @moonsync.Replica::new("device-a")
local.set("title", "draft")
local.add("tags", "offline")
local.text_insert("body", 0, "hello")

let remote_ops = local.operations()
local.merge(remote_ops)
```

Register writes use a deterministic `(counter, replica)` ordering, with a Lamport counter that advances after observing remote operations. Text siblings use descending counters, then ascending MoonBit string comparison for replica IDs (shortlex in the tested toolchain). New local insertions therefore appear immediately after their selected predecessor. Set members use ascending MoonBit string comparison.

The tests cover convergence, observed removal, concurrent insertion, deletion, causal register writes, reordered set operations, and insertion at leading and middle offsets.

## Integrate

The configured package is `0607272/moonsync`, version `0.1.0`. It has **not been published yet**. After publication, install it with:

```bash
moon add 0607272/moonsync@0.1.0
```

Add `"0607272/moonsync"` to the consuming package's `import` list in `moon.pkg` to use the `@moonsync` alias shown above.

## Limitations

This is an experimental in-memory library for short text and small operation logs. Use distinct replica IDs and only exchange operations created by trusted replicas; conflicting operations with reused IDs are unsupported. Keep replica state alive between edits to avoid reusing counters. Operation export is a shallow copy, so callers must not mutate nested remove-tag arrays. Text offsets count MoonBit characters, not grapheme clusters; callers must supply valid nonnegative offsets. Traversal is recursive and rendering scans the full log. There is no JSON codec, persistence, version vector, compaction, transport, or untrusted-input validation in this version.

## Project status

This is an original MoonBit implementation for the MoonBit Hackathon, inspired by standard CRDT concepts. It is not a port of an existing implementation. The local repository retains actual development commits; remote upload and Mooncakes publication are pending.

## License

Apache-2.0. See [LICENSE](LICENSE).
