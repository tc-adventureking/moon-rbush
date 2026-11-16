///|
fn json_number(v : Double) -> Json {
  if v.is_inf() {
    Json::null()
  } else {
    Json::number(v)
  }
}

///|
fn[T] encode_node(n : Node[T], encode : (T) -> Json) -> Json {
  let children = n.children.map(e => {
    match e {
      Item(t) => encode(t)
      Branch(c) => encode_node(c, encode)
    }
  })
  Json::object({
    "children": Json::array(children),
    "height": Json::number(n.height.to_double()),
    "leaf": Json::boolean(n.leaf),
    "minX": json_number(n.bbox.min_x),
    "minY": json_number(n.bbox.min_y),
    "maxX": json_number(n.bbox.max_x),
    "maxY": json_number(n.bbox.max_y),
  })
}

///|
/// Export the raw upstream root schema (max_entries is deliberately not included).
pub fn[T] RBush::to_json(self : RBush[T], encode : (T) -> Json) -> Json {
  encode_node(self.root, encode)
}

///|
fn field(obj : Map[String, Json], key : String) -> Json raise RBushError {
  match obj.get(key) {
    Some(v) => v
    None => raise InvalidSnapshot("missing field: " + key)
  }
}

///|
fn number_field(
  obj : Map[String, Json],
  key : String,
) -> Double raise RBushError {
  match field(obj, key) {
    Number(v, ..) => {
      if v.is_nan() || v.is_inf() {
        raise InvalidSnapshot("nonfinite number")
      }
      v
    }
    _ => raise InvalidSnapshot("expected number: " + key)
  }
}

///|
fn[T] RBush::decode_node(
  self : RBush[T],
  json : Json,
  decode : (Json) -> T raise,
  root : Bool,
  depth : Int32,
) -> Node[T] raise {
  if depth > 64 {
    raise InvalidSnapshot("tree depth exceeds 64")
  }
  let obj = match json {
    Object(o) => o
    _ => raise InvalidSnapshot("expected node object")
  }
  let values = match field(obj, "children") {
    Array(a) => a
    _ => raise InvalidSnapshot("expected children array")
  }
  let leaf = match field(obj, "leaf") {
    True => true
    False => false
    _ => raise InvalidSnapshot("expected leaf boolean")
  }
  let h = number_field(obj, "height")
  if h < 1 || h > 64 || h != h.floor() {
    raise InvalidSnapshot("invalid height")
  }
  let height = h.to_int()
  if leaf != (height == 1) {
    raise InvalidSnapshot("leaf and height mismatch")
  }
  if values.length() > self.max_entries || (!root && values.is_empty()) {
    raise InvalidSnapshot("invalid node occupancy")
  }
  if values.is_empty() {
    if !leaf || !root {
      raise InvalidSnapshot("empty internal node")
    }
    for key in ["minX", "minY", "maxX", "maxY"] {
      match field(obj, key) {
        Null => ()
        _ => raise InvalidSnapshot("empty root bounds must be null")
      }
    }
    return node([], 1, true)
  }
  let bbox = {
    min_x: number_field(obj, "minX"),
    min_y: number_field(obj, "minY"),
    max_x: number_field(obj, "maxX"),
    max_y: number_field(obj, "maxY"),
  }
  bbox.validate()
  let n = node([], height, leaf)
  for value in values {
    if leaf {
      let item = decode(value)
      (self.to_bbox)(item).validate()
      n.children.push(Item(item))
    } else {
      let child = self.decode_node(value, decode, false, depth + 1)
      if child.height != height - 1 {
        raise InvalidSnapshot("child height mismatch")
      }
      n.children.push(Branch(child))
    }
  }
  self.calc_bbox(n)
  if n.bbox != bbox {
    raise InvalidSnapshot("node bounds differ from exact child union")
  }
  n
}

///|
/// Validate a complete snapshot before replacing this tree. Callback errors also leave it unchanged.
pub fn[T] RBush::restore(
  self : RBush[T],
  json : Json,
  decode : (Json) -> T raise,
) -> Unit raise {
  let root = self.decode_node(json, decode, true, 1)
  self.root = root
}

///|
/// Restore a new tree. Use the same capacity as the original tree (upstream omits it).
pub fn[T] RBush::from_json(
  json : Json,
  to_bbox : (T) -> BBox,
  decode : (Json) -> T raise,
  max_entries~ : Int32 = 9,
  compare_min_x? : (T, T) -> Int32,
  compare_min_y? : (T, T) -> Int32,
) -> RBush[T] raise {
  let tree = RBush::new(to_bbox, max_entries~, compare_min_x?, compare_min_y?)
  tree.restore(json, decode)
  tree
}
