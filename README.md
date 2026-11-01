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

Register writes use a deterministic `(counter, replica)` ordering. Text operations use stable operation IDs and tombstones, so concurrent inserts and deletes can be replayed in any arrival order. The test suite covers convergence, duplicate-safe merging, observed removal, concurrent text insertion, and text deletion.

## Project status

This repository is an original MoonBit implementation for the MoonBit Hackathon. It is not a port of an existing CRDT implementation. The public package name is currently `username/moonsync` as a template; replace `username` with the applicant's Mooncakes/GitHub namespace before publishing.

## License

Apache-2.0. See [LICENSE](LICENSE).
