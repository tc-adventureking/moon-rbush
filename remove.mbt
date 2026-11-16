pub fn[T] RBush::clear(self : RBush[T]) -> Unit { self.root = node([],1,true) }
fn[T] RBush::remove_node(self : RBush[T], n : Node[T], bbox : BBox, item : T, equals : (T,T) -> Bool) -> Bool {
  if n.leaf {
    for i = 0; i < n.children.length(); i = i + 1 {
      match n.children[i] {
        Item(t) => if equals(item,t) { let _ = n.children.remove(i); self.calc_bbox(n); return true }
        _ => ()
      }
    }
  } else if n.bbox.contains(bbox) {
    for i = 0; i < n.children.length(); i = i + 1 {
      match n.children[i] {
        Branch(c) => if self.remove_node(c,bbox,item,equals) {
          if c.children.is_empty() { let _ = n.children.remove(i) }
          self.calc_bbox(n)
          return true
        }
        _ => ()
      }
    }
  }
  false
}
/// Remove the first match in traversal order. The supplied item needs its original bbox.
pub fn[T] RBush::remove_by(self : RBush[T], item : T, equals : (T,T) -> Bool) -> Bool raise RBushError {
  let bbox = (self.to_bbox)(item)
  bbox.validate()
  let removed = self.remove_node(self.root,bbox,item,equals)
  if self.root.children.is_empty() { self.clear() }
  removed
}
/// MoonBit value equality replaces JavaScript's default reference identity.
pub fn[T : Eq] RBush::remove(self : RBush[T], item : T) -> Bool raise RBushError {
  self.remove_by(item,(a,b) => a == b)
}
