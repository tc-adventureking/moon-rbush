///|
fn decode_bbox(j : Json) -> BBox raise {
  BBox::from_json(j)
}

///|
test "snapshots roundtrip raw topology including underfilled deletion nodes" {
  let tree = RBush::new((b : BBox) => b, max_entries=4)
  let items = Array::makei(200, i => {
    BBox::new(i.to_double(), 0, i.to_double() + 1, 1)
  })
  tree.load(items)
  for i = 0; i < 180; i = i + 1 {
    let _ = tree.remove(items[i])
  }
  let json = tree.to_json(BBox::to_json)
  let restored = RBush::from_json(
    @json.parse(json.stringify()),
    (b : BBox) => b,
    decode_bbox,
    max_entries=4,
  )
  assert_eq(restored.to_json(BBox::to_json), json)
  assert_eq(check_node(restored, restored.root, true), 20)
  tree.clear()
  let empty = tree.to_json(BBox::to_json)
  tree.restore(@json.parse(empty.stringify()), decode_bbox)
  assert_eq(tree.to_json(BBox::to_json), empty)
}

///|
test "invalid hierarchy or payload leaves existing tree untouched" {
  let tree = RBush::new((b : BBox) => b, max_entries=4)
  tree.insert(BBox::new(0, 0, 1, 1))
  let original = tree.to_json(BBox::to_json)
  for change in ["height", "leaf", "children", "minX"] {
    let altered = match @json.parse(original.stringify()) {
      Object(o) => o
      _ => abort("object")
    }
    altered[change] = match change {
      "height" => Json::number(2)
      "leaf" => Json::boolean(false)
      "children" => Json::array([])
      _ => Json::number(-1)
    }
    assert_true(
      try {
        tree.restore(Json::object(altered), decode_bbox)
        false
      } catch {
        _ => true
      },
    )
    assert_eq(tree.to_json(BBox::to_json), original)
  }
  assert_true(
    try {
      tree.restore(original, _ => raise InvalidSnapshot("decode failed"))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(tree.to_json(BBox::to_json), original)
}

///|
test "restore rejects capacity, unions and malformed node fields" {
  let tree = RBush::new((b : BBox) => b, max_entries=4)
  tree.load(
    Array::makei(20, i => BBox::new(i.to_double(), 0, i.to_double() + 1, 1)),
  )
  let original = tree.to_json(BBox::to_json)
  let rejects : Array[(String, Json)] = [
    ("height", Json::number(65)),
    ("height", Json::number(1.5)),
    ("leaf", Json::number(1)),
    ("minX", Json::null()),
    ("children", Json::array([Json::null()])),
  ]
  for (key, value) in rejects {
    let o = match @json.parse(original.stringify()) {
      Object(o) => o
      _ => abort("object")
    }
    o[key] = value
    assert_true(
      try {
        tree.restore(Json::object(o), decode_bbox)
        false
      } catch {
        _ => true
      },
    )
    assert_eq(tree.to_json(BBox::to_json), original)
  }
  let too_small = RBush::new((b : BBox) => b, max_entries=4)
  let large = RBush::new((b : BBox) => b, max_entries=9)
  large.load(
    Array::makei(9, i => BBox::new(i.to_double(), 0, i.to_double(), 0)),
  )
  assert_true(
    try {
      too_small.restore(large.to_json(BBox::to_json), decode_bbox)
      false
    } catch {
      _ => true
    },
  )
  assert_true(too_small.all().is_empty())
}

///|
test "signed zero bounds restore by numeric equality" {
  let tree = RBush::new((b : BBox) => b)
  tree.insert(BBox::new(-0.0, -0.0, 0.0, 0.0))
  let saved = tree.to_json(BBox::to_json)
  let obj = object(saved)
  obj["minX"] = Json::number(0.0)
  obj["minY"] = Json::number(0.0)
  tree.restore(Json::object(obj), decode_bbox)
  assert_eq(tree.search(BBox::new(0, 0, 0, 0)).length(), 1)
}

///|
test "restore rejects actual child height mismatch and empty nonroot internal nodes atomically" {
  let tree = RBush::new((b : BBox) => b, max_entries=4)
  tree.load(
    Array::makei(20, i => BBox::new(i.to_double(), 0, i.to_double() + 1, 1)),
  )
  let original = tree.to_json(BBox::to_json)
  assert_eq(tree.root.height, 3)
  let leaf = RBush::new((b : BBox) => b, max_entries=4)
  leaf.insert(BBox::new(0, 0, 1, 1))
  for mode in ["child height mismatch", "invalid node occupancy"] {
    let altered = object(@json.parse(original.stringify()))
    let children = array(altered["children"])
    if mode == "child height mismatch" {
      // This child is valid by itself, but height 1 cannot belong to a height-3 parent.
      children[0] = leaf.to_json(BBox::to_json)
    } else {
      let child = object(children[0])
      assert_eq(child["leaf"], Json::boolean(false))
      assert_eq(child["height"], Json::number(2))
      child["children"] = Json::array([])
    }
    let reached_expected_check = try {
      tree.restore(Json::object(altered), decode_bbox)
      false
    } catch {
      InvalidSnapshot(message) => message == mode
      _ => false
    }
    assert_true(reached_expected_check)
    assert_eq(tree.to_json(BBox::to_json), original)
  }
}
