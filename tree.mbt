///|
priv enum Entry[T] {
  Item(T)
  Branch(Node[T])
}

///|
priv struct Node[T] {
  children : Array[Entry[T]]
  height : Int32
  leaf : Bool
  mut bbox : BBox
}

///|
/// A mutable dynamic 2D R-tree. Payload coordinates must stay unchanged while indexed.
pub struct RBush[T] {
  priv mut root : Node[T]
  priv max_entries : Int32
  priv min_entries : Int32
  priv to_bbox : (T) -> BBox
  priv compare_x : (T, T) -> Int32
  priv compare_y : (T, T) -> Int32
}

///|
/// Custom comparators must order payloads by increasing minimum coordinate.
pub fn[T] RBush::new(
  to_bbox : (T) -> BBox,
  max_entries~ : Int32 = 9,
  compare_min_x? : (T, T) -> Int32,
  compare_min_y? : (T, T) -> Int32,
) -> RBush[T] {
  let m = if max_entries < 4 { 4 } else { max_entries }
  {
    root: node([], 1, true),
    max_entries: m,
    min_entries: @double.ceil(m.to_double() * 0.4).to_int(),
    to_bbox,
    compare_x: compare_min_x.unwrap_or_else(() => {
      (a, b) => coord_cmp(to_bbox(a).min_x, to_bbox(b).min_x)
    }),
    compare_y: compare_min_y.unwrap_or_else(() => {
      (a, b) => coord_cmp(to_bbox(a).min_y, to_bbox(b).min_y)
    }),
  }
}

///|
fn coord_cmp(a : Double, b : Double) -> Int32 {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn[T] node(children : Array[Entry[T]], height : Int32, leaf : Bool) -> Node[T] {
  { children, height, leaf, bbox: empty_bbox(), }
}

///|
fn[T] RBush::entry_bbox(self : RBush[T], e : Entry[T]) -> BBox {
  match e {
    Item(t) => (self.to_bbox)(t)
    Branch(n) => n.bbox
  }
}

///|
fn[T] RBush::dist_bbox(
  self : RBush[T],
  n : Node[T],
  start : Int32,
  end : Int32,
) -> BBox {
  let mut b = empty_bbox()
  for i = start; i < end; i = i + 1 {
    b = union(b, self.entry_bbox(n.children[i]))
  }
  b
}

///|
fn[T] RBush::calc_bbox(self : RBush[T], n : Node[T]) -> Unit {
  n.bbox = self.dist_bbox(n, 0, n.children.length())
}

///|
fn[T] RBush::entry_compare(
  self : RBush[T],
  a : Entry[T],
  b : Entry[T],
  x : Bool,
) -> Int32 {
  match (a, b) {
    (Item(a), Item(b)) =>
      if x {
        (self.compare_x)(a, b)
      } else {
        (self.compare_y)(a, b)
      }
    _ => {
      let aa = self.entry_bbox(a)
      let bb = self.entry_bbox(b)
      if x {
        coord_cmp(aa.min_x, bb.min_x)
      } else {
        coord_cmp(aa.min_y, bb.min_y)
      }
    }
  }
}
// Stable sorting matches modern JavaScript Array.sort when minimum coordinates tie.

///|
fn[T] RBush::sort_entries(self : RBush[T], n : Node[T], x : Bool) -> Unit {
  n.children.mut_view().stable_sort_by((a, b) => self.entry_compare(a, b, x))
}

///|
fn[T] RBush::all_dist_margin(self : RBush[T], n : Node[T], x : Bool) -> Double {
  self.sort_entries(n, x)
  let m = self.min_entries
  let total = n.children.length()
  let mut left = self.dist_bbox(n, 0, m)
  let mut right = self.dist_bbox(n, total - m, total)
  let mut sum = margin(left) + margin(right)
  for i = m; i < total - m; i = i + 1 {
    left = union(left, self.entry_bbox(n.children[i]))
    sum += margin(left)
  }
  for i = total - m - 1; i >= m; i = i - 1 {
    right = union(right, self.entry_bbox(n.children[i]))
    sum += margin(right)
  }
  sum
}

///|
fn[T] RBush::split(self : RBush[T], n : Node[T]) -> Node[T] {
  let xm = self.all_dist_margin(n, true)
  let ym = self.all_dist_margin(n, false)
  if xm < ym {
    self.sort_entries(n, true)
  }
  let m = self.min_entries
  let total = n.children.length()
  let mut index = total - m
  let mut min_overlap = 1.0 / 0.0
  let mut min_area = 1.0 / 0.0
  for i = m; i <= total - m; i = i + 1 {
    let a = self.dist_bbox(n, 0, i)
    let b = self.dist_bbox(n, i, total)
    let o = overlap(a, b)
    let s = area(a) + area(b)
    if o < min_overlap {
      min_overlap = o
      index = i
      min_area = dmin(s, min_area)
    } else if o == min_overlap && s < min_area {
      min_area = s
      index = i
    }
  }
  let right = Array::makei(total - index, i => n.children[index + i])
  while n.children.length() > index {
    let _ = n.children.pop()
  }
  let sibling = node(right, n.height, n.leaf)
  self.calc_bbox(n)
  self.calc_bbox(sibling)
  sibling
}

///|
fn[T] RBush::split_root(self : RBush[T], a : Node[T], b : Node[T]) -> Unit {
  self.root = node([Branch(a), Branch(b)], a.height + 1, false)
  self.calc_bbox(self.root)
}

///|
fn[T] RBush::insert_entry(
  self : RBush[T],
  entry : Entry[T],
  level : Int32,
) -> Unit {
  let bbox = self.entry_bbox(entry)
  let path : Array[Node[T]] = []
  let mut current = self.root
  while true {
    path.push(current)
    if current.leaf || path.length() - 1 == level {
      break
    }
    let mut min_area = 1.0 / 0.0
    let mut min_enlargement = 1.0 / 0.0
    let mut chosen = 0
    for i = 0; i < current.children.length(); i = i + 1 {
      let b = self.entry_bbox(current.children[i])
      let a = area(b)
      let enlargement = area(union(b, bbox)) - a
      if enlargement < min_enlargement {
        min_enlargement = enlargement
        min_area = dmin(a, min_area)
        chosen = i
      } else if enlargement == min_enlargement && a < min_area {
        min_area = a
        chosen = i
      }
    }
    match current.children[chosen] {
      Branch(n) => current = n
      _ => abort("internal leaf mismatch")
    }
  }
  current.children.push(entry)
  current.bbox = union(current.bbox, bbox)
  let mut l = path.length() - 1
  while l >= 0 {
    if path[l].children.length() > self.max_entries {
      let sibling = self.split(path[l])
      if l == 0 {
        self.split_root(path[l], sibling)
      } else {
        path[l - 1].children.push(Branch(sibling))
      }
      l -= 1
    } else {
      break
    }
  }
  for i = l; i >= 0; i = i - 1 {
    path[i].bbox = union(path[i].bbox, bbox)
  }
}

///|
/// Validate the item's bbox before modifying the tree.
pub fn[T] RBush::insert(self : RBush[T], item : T) -> Unit raise RBushError {
  (self.to_bbox)(item).validate()
  self.insert_entry(Item(item), self.root.height - 1)
}
