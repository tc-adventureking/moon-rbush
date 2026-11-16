fn[T] collect_all(n : Node[T], out : Array[T]) -> Unit {
  let pending = [n]
  while pending.length() > 0 {
    let current = pending.unsafe_pop()
    for e in current.children { match e { Item(t) => out.push(t); Branch(c) => pending.push(c) } }
  }
}
pub fn[T] RBush::all(self : RBush[T]) -> Array[T] {
  let out = []
  collect_all(self.root,out)
  out
}
// Returns visited node count as private instrumentation for pruning tests.
fn[T] RBush::search_nodes(self : RBush[T], bbox : BBox) -> (Array[T], Int) {
  let out = []
  let mut visited = 1
  if !bbox.intersects(self.root.bbox) { return (out, visited) }
  let pending = [self.root]
  while pending.length() > 0 {
    let n = pending.unsafe_pop()
    for e in n.children {
      let b = self.entry_bbox(e)
      if bbox.intersects(b) {
        match e {
          Item(t) => out.push(t)
          Branch(c) => {
            visited += 1
            if bbox.contains(b) { collect_all(c,out) } else { pending.push(c) }
          }
        }
      }
    }
  }
  (out,visited)
}
/// Return all items intersecting a valid closed query rectangle.
pub fn[T] RBush::search(self : RBush[T], bbox : BBox) -> Array[T] raise RBushError {
  bbox.validate()
  self.search_nodes(bbox).0
}
/// Stop at the first intersection; traverses only overlapping branches.
pub fn[T] RBush::collides(self : RBush[T], bbox : BBox) -> Bool raise RBushError {
  bbox.validate()
  if !bbox.intersects(self.root.bbox) { return false }
  let pending = [self.root]
  while pending.length() > 0 {
    let n = pending.unsafe_pop()
    for e in n.children {
      let b = self.entry_bbox(e)
      if bbox.intersects(b) {
        match e { Item(_) => return true; Branch(c) => { if bbox.contains(b) { return true }; pending.push(c) } }
      }
    }
  }
  false
}
