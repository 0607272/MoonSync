///|
fn transfer(source : @moonsync.Replica, target : @moonsync.Replica) -> Unit {
  let delta = source.missing_operations(target.receipt())
  match @moonsync.decode_operations(@moonsync.encode_operations(delta)) {
    Ok(ops) =>
      assert_true(target.merge_checked(ops) is Ok(_)) catch {
        _ => abort("merge rejected")
      }
    Err(_) => abort("wire rejected")
  }
}

///|
test "three replicas converge through partitions retries and reverse delivery" {
  for seed in 0..<24 {
    let a = @moonsync.Replica::new("a")
    let b = @moonsync.Replica::new("b")
    let c = @moonsync.Replica::new("c")
    a.text_insert("body", 0, "你好")
    a.add("tags", "shared")
    transfer(a, b)
    transfer(a, c)
    a.text_insert("body", 1, "A")
    a.remove("tags", "shared")
    b.text_delete("body", 0, 1)
    b.add("tags", "shared")
    c.text_insert("body", 2, "🌙")
    c.set("title", "c")
    a.set("title", "a")
    b.set("title", "b")
    let peers = [a, b, c]
    for round in 0..<9 {
      let source = peers[(seed + round) % 3]
      let target = peers[(seed * 7 + round + 1) % 3]
      let ops = source.operations()
      for offset in 0..<ops.length() {
        let op = ops[ops.length() - offset - 1]
        assert_true(target.merge_checked([op, op]) is Ok(_))
      }
    }
    for source in peers {
      for target in peers {
        transfer(source, target)
      }
    }
    for peer in peers {
      assert_eq(peer.text("body"), "A好🌙")
      assert_eq(peer.members("tags"), ["shared"])
      assert_eq(peer.get("title"), a.get("title"))
      assert_eq(peer.operations().length(), a.operations().length())
      assert_eq(peer.missing_operations(a.receipt()).length(), 0)
    }
  }
}

///|
test "deletion arriving before insertion still tombstones the late node" {
  let a = @moonsync.Replica::new("a")
  a.text_insert("body", 0, "x")
  a.text_delete("body", 0, 1)
  let ops = a.operations()
  let b = @moonsync.Replica::new("b")
  assert_true(b.merge_checked([ops[1]]) is Ok(1))
  assert_true(b.merge_checked([ops[0]]) is Ok(1))
  assert_eq(b.text("body"), "")
}
