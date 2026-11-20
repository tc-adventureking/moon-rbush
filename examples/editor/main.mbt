///|
struct Shape {
  id : Int32
  box : @rbush.BBox
}

///|
suberror PayloadError {
  InvalidPayload
}

///|
fn encode(s : Shape) -> Json {
  Json::object({
    "id": Json::number(s.id.to_double()),
    "minX": Json::number(s.box.min_x),
    "minY": Json::number(s.box.min_y),
    "maxX": Json::number(s.box.max_x),
    "maxY": Json::number(s.box.max_y),
  })
}

///|
fn number(o : Map[String, Json], key : String) -> Double raise {
  match o.get(key) {
    Some(Number(n, ..)) => n
    _ => raise InvalidPayload
  }
}

///|
fn decode(j : Json) -> Shape raise {
  let o = match j {
    Object(o) => o
    _ => raise InvalidPayload
  }
  let id = number(o, "id")
  if id.is_nan() ||
    id.is_inf() ||
    id < 0 ||
    id > 2147483647.0 ||
    id != id.floor() {
    raise InvalidPayload
  }
  { id: id.to_int(), box: @rbush.BBox::from_json(j), }
}

///|
fn scenario() -> Unit raise {
  let index = @rbush.RBush::new((s : Shape) => s.box, max_entries=4)
  let first = {
    id: 1,
    box: { min_x: 0.0, min_y: 0.0, max_x: 10.0, max_y: 10.0, },
  }
  let second = {
    id: 2,
    box: { min_x: 8.0, min_y: 8.0, max_x: 12.0, max_y: 12.0, },
  }
  index.load([first, second])
  let selection : @rbush.BBox = {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 10.0,
    max_y: 10.0,
  }
  let hits = index.search(selection)
  let contained = hits.filter(s => selection.contains(s.box))
  assert_eq(hits.length(), 2)
  assert_eq(contained.map(s => s.id), [1])
  println(
    "Intersecting: \{hits.length()}, fully contained: \{contained.length()}",
  )
  // Drag shape 2 away: remove its old bbox before inserting its replacement.
  assert_true(index.remove_by(second, (a, b) => a.id == b.id))
  index.insert({
    id: 2,
    box: { min_x: 20.0, min_y: 20.0, max_x: 24.0, max_y: 24.0, },
  })
  assert_eq(index.search(selection).map(s => s.id), [1])
  // Persist actual JSON text, parse it on reopening, then query and edit the restored tree.
  let saved = index.to_json(encode).stringify()
  let restored = @rbush.RBush::from_json(
    @json.parse(saved),
    (s : Shape) => s.box,
    decode,
    max_entries=4,
  )
  assert_eq(restored.to_json(encode), index.to_json(encode))
  assert_eq(restored.search(selection).map(s => s.id), [1])
  assert_true(restored.remove_by(first, (a, b) => a.id == b.id))
  restored.insert({
    id: 3,
    box: { min_x: 1.0, min_y: 1.0, max_x: 2.0, max_y: 2.0, },
  })
  assert_eq(restored.search(selection).map(s => s.id), [3])
  println("Reopened snapshot queried and edited successfully")
}

///|
fn main {
  try! scenario()
}
