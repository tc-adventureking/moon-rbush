///|
fn[T] check_node(tree : RBush[T], n : Node[T], root : Bool) -> Int32 raise {
  assert_true(n.children.length() <= tree.max_entries)
  assert_true(root || n.children.length() > 0)
  assert_eq(n.leaf, n.height == 1)
  assert_eq(n.bbox, tree.dist_bbox(n, 0, n.children.length()))
  let mut count = 0
  for child in n.children {
    match child {
      Item(_) => {
        assert_true(n.leaf)
        count += 1
      }
      Branch(c) => {
        assert_false(n.leaf)
        assert_eq(c.height, n.height - 1)
        count += check_node(tree, c, false)
      }
    }
  }
  count
}

///|
test "dynamic insertion splits root and preserves exact node unions" {
  for capacity in [1, 4, 9, 16] {
    let tree = RBush::new((b : BBox) => b, max_entries=capacity)
    for i = 0; i < 500; i = i + 1 {
      let x = (i * 79 % 101).to_double()
      let y = (i * 37 % 97).to_double()
      tree.insert(BBox::new(x, y, x + 2, y + 3))
      assert_eq(check_node(tree, tree.root, true), i + 1)
    }
    assert_true(tree.root.height > 1)
  }
}
