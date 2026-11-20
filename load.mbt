///|
fn tile_widths(count : Int32, fanout : Int32) -> (Int32, Int32) {
  let tile_size = 1 + (count - 1) / fanout
  let tiles_per_strip = fanout.to_double().sqrt().ceil().to_int64()
  let strip_size = (tile_size.to_int64() * tiles_per_strip).min(
    count.to_int64(),
  )
  (strip_size.to_int(), tile_size)
}

///|
fn[T] RBush::build(
  self : RBush[T],
  items : Array[T],
  left : Int32,
  end : Int32,
  height0 : Int32,
) -> Node[T] {
  let count = end - left
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
  let (strip_size, tile_size) = tile_widths(count, m)
  multi_select(items, left, end - 1, strip_size, self.compare_x)
  // Bound each advance by the remaining range before adding it to an index.
  for i = left; i < end; {
    let strip_end = i + strip_size.min(end - i)
    multi_select(items, i, strip_end - 1, tile_size, self.compare_y)
    for j = i; j < strip_end; {
      let tile_end = j + tile_size.min(strip_end - j)
      n.children.push(Branch(self.build(items, j, tile_end, height - 1)))
      continue tile_end
    }
    continue strip_end
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
  let mut built = self.build(items.copy(), 0, items.length(), 0)
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
