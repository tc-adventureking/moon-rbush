///|
fn[T] RBush::build(
  self : RBush[T],
  items : Array[T],
  left : Int32,
  right : Int32,
  height0 : Int32,
) -> Node[T] {
  let count = right - left + 1
  if count <= self.max_entries {
    let n = node(Array::makei(count, i => Item(items[left + i])), 1, true)
    self.calc_bbox(n)
    return n
  }
  let mut m = self.max_entries
  let mut height = height0
  if height == 0 {
    // Integer powers avoid log/ceil rounding drift at exact powers of max_entries.
    height = 1
    let mut power = m.to_int64()
    while power < count.to_int64() {
      power *= m.to_int64()
      height += 1
    }
    let lower = power / m.to_int64()
    m = ((count.to_int64() + lower - 1) / lower).to_int()
  }
  let n = node([], height, false)
  let n2 = (count + m - 1) / m
  let n1 = n2 * m.to_double().sqrt().ceil().to_int()
  multi_select(items, left, right, n1, self.compare_x)
  for i = left; i <= right; i = i + n1 {
    let r2 = if i + n1 - 1 < right { i + n1 - 1 } else { right }
    multi_select(items, i, r2, n2, self.compare_y)
    for j = i; j <= r2; j = j + n2 {
      let r3 = if j + n2 - 1 < r2 { j + n2 - 1 } else { r2 }
      n.children.push(Branch(self.build(items, j, r3, height - 1)))
    }
  }
  self.calc_bbox(n)
  n
}

///|
/// Validate the whole batch before mutation; copies the input before OMT partitioning.
/// Nonempty trees use small-tree/large-tree (STLT) insertion.
pub fn[T] RBush::load(
  self : RBush[T],
  items : Array[T],
) -> Unit raise RBushError {
  for item in items {
    (self.to_bbox)(item).validate()
  }
  if items.is_empty() {
    return
  }
  if items.length() < self.min_entries {
    for item in items {
      self.insert_entry(Item(item), self.root.height - 1)
    }
    return
  }
  let mut built = self.build(items.copy(), 0, items.length() - 1, 0)
  if self.root.children.is_empty() {
    self.root = built
  } else if self.root.height == built.height {
    self.split_root(self.root, built)
  } else {
    if self.root.height < built.height {
      let old = self.root
      self.root = built
      built = old
    }
    self.insert_entry(Branch(built), self.root.height - built.height - 1)
  }
}
