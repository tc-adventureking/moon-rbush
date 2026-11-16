fn encode_bbox(b : BBox) -> Json {
  Json::object({"minX":Json::number(b.min_x),"minY":Json::number(b.min_y),"maxX":Json::number(b.max_x),"maxY":Json::number(b.max_y)})
}
fn decode_bbox(j : Json) -> BBox raise {
  let o = match j { Object(o) => o; _ => raise InvalidSnapshot("payload object expected") }
  BBox::new(number_field(o,"minX"),number_field(o,"minY"),number_field(o,"maxX"),number_field(o,"maxY"))
}
test "snapshots roundtrip raw topology including underfilled deletion nodes" {
  let tree = RBush::new((b : BBox) => b,max_entries=4)
  let items = Array::makei(200,i => BBox::new(i.to_double(),0,i.to_double()+1,1))
  tree.load(items)
  for i = 0; i < 180; i = i + 1 { let _ = tree.remove(items[i]) }
  let json = tree.to_json(encode_bbox)
  let restored = RBush::from_json(json,(b : BBox) => b,decode_bbox,max_entries=4)
  assert_eq(restored.to_json(encode_bbox),json)
  assert_eq(check_node(restored,restored.root,true),20)
  tree.clear()
  let empty = tree.to_json(encode_bbox)
  tree.restore(empty,decode_bbox)
  assert_eq(tree.to_json(encode_bbox),empty)
}
test "invalid hierarchy or payload leaves existing tree untouched" {
  let tree = RBush::new((b : BBox) => b,max_entries=4)
  tree.insert(BBox::new(0,0,1,1))
  let original = tree.to_json(encode_bbox)
  for change in ["height","leaf","children","minX"] {
    let altered = match @json.parse(original.stringify()) { Object(o) => o; _ => abort("object") }
    altered[change] = match change { "height" => Json::number(2); "leaf" => Json::boolean(false); "children" => Json::array([]); _ => Json::number(-1) }
    assert_true(try { tree.restore(Json::object(altered),decode_bbox); false } catch { _ => true })
    assert_eq(tree.to_json(encode_bbox),original)
  }
  assert_true(try { tree.restore(original,_ => raise InvalidSnapshot("decode failed")); false } catch { _ => true })
  assert_eq(tree.to_json(encode_bbox),original)
}
test "restore rejects capacity, unions and malformed child heights" {
  let tree = RBush::new((b : BBox) => b,max_entries=4)
  tree.load(Array::makei(20,i => BBox::new(i.to_double(),0,i.to_double()+1,1)))
  let original = tree.to_json(encode_bbox)
  let rejects : Array[(String,Json)] = [("height",Json::number(65)),("height",Json::number(1.5)),("leaf",Json::number(1)),("minX",Json::null()),("children",Json::array([Json::null()]))]
  for (key,value) in rejects {
    let o = match @json.parse(original.stringify()) { Object(o) => o; _ => abort("object") }
    o[key] = value
    assert_true(try { tree.restore(Json::object(o),decode_bbox); false } catch { _ => true })
    assert_eq(tree.to_json(encode_bbox),original)
  }
  let too_small = RBush::new((b : BBox) => b,max_entries=4)
  let large = RBush::new((b : BBox) => b,max_entries=9)
  large.load(Array::makei(9,i => BBox::new(i.to_double(),0,i.to_double(),0)))
  assert_true(try { too_small.restore(large.to_json(encode_bbox),decode_bbox); false } catch { _ => true })
  assert_true(too_small.all().is_empty())
}
