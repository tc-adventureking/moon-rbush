///|
fn object(j : Json) -> Map[String, Json] {
  match j {
    Object(o) => o
    _ => abort("object expected")
  }
}

///|
fn array(j : Json) -> Array[Json] {
  match j {
    Array(a) => a
    _ => abort("array expected")
  }
}

///|
fn ids(items : Array[Json]) -> Json {
  let result = items.map(j => {
    match object(j)["id"] {
      Number(n, ..) => n.to_int()
      _ => abort("id")
    }
  })
  result.sort()
  Json::array(result.map(i => Json::number(i.to_double())))
}

///|
test "independent RBush 4.0.1 oracle: 73 scenarios and exact tree topology" {
  for case in oracle_cases() {
    let c = object(case)
    let capacity = number_field(c, "capacity").to_int()
    let tree = RBush::new(
      (j : Json) => try! decode_bbox(j),
      max_entries=capacity,
    )
    for operation in array(c["ops"]) {
      let op = object(operation)
      match op["kind"] {
        String("load") => tree.load(array(op["items"]))
        String("insert") => tree.insert(op["item"])
        String("remove") => {
          let _ = tree.remove_by(op["item"], (a, b) => {
            object(a)["id"] == object(b)["id"]
          })
        }
        String("clear") => tree.clear()
        String("search") =>
          assert_eq(ids(tree.search(decode_bbox(op["bbox"]))), op["result"])
        String("collides") =>
          assert_eq(
            Json::boolean(tree.collides(decode_bbox(op["bbox"]))),
            op["result"],
          )
        _ => abort("unknown operation")
      }
      let _ = check_node(tree, tree.root, true)
    }
    assert_eq(ids(tree.all()), c["all"])
    assert_eq(tree.to_json(j => j), c["snapshot"])
    let restored = RBush::from_json(
      c["snapshot"],
      (j : Json) => try! decode_bbox(j),
      j => j,
      max_entries=capacity,
    )
    assert_eq(restored.to_json(j => j), c["snapshot"])
  }
}

///|
fn sorted_boxes(items : Array[BBox]) -> Array[BBox] {
  let sorted = items.copy()
  sorted.sort_by((a, b) => {
    for
      pair in [
        (a.min_x, b.min_x),
        (a.min_y, b.min_y),
        (a.max_x, b.max_x),
        (a.max_y, b.max_y),
      ] {
      let c = coord_cmp(pair.0, pair.1)
      if c != 0 {
        return c
      }
    }
    0
  })
  sorted
}

///|
test "random mixed mutations maintain brute-force multiset and invariants" {
  let tree = RBush::new((b : BBox) => b, max_entries=5)
  let live : Array[BBox] = []
  let mut state = 12345U
  for step = 0; step < 1500; step = step + 1 {
    state = state * 1664525U + 1013904223U
    let x = (state % 100U).reinterpret_as_int().to_double()
    let b = BBox::new(x, x / 2, x + 1, x / 2 + 1)
    if step % 13 == 0 {
      tree.load([b, b])
      live.push(b)
      live.push(b)
    } else if step % 3 == 0 && !live.is_empty() {
      let at = (state % live.length().reinterpret_as_uint()).reinterpret_as_int()
      let old = live.remove(at)
      assert_true(tree.remove(old))
    } else {
      tree.insert(b)
      live.push(b)
    }
    assert_eq(check_node(tree, tree.root, true), live.length())
    assert_eq(sorted_boxes(tree.all()), sorted_boxes(live))
    let q = BBox::new(x, 0, x + 5, 100)
    let expected = live.filter(v => q.intersects(v))
    assert_eq(sorted_boxes(tree.search(q)), sorted_boxes(expected))
    assert_eq(tree.collides(q), !expected.is_empty())
  }
}
