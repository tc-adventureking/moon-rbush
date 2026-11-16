///|
test "removal condenses empty branches and preserves duplicate multiplicity" {
  let tree = RBush::new((b : BBox) => b, max_entries=4)
  let items = Array::makei(150, i => {
    BBox::new(i.to_double(), 0, i.to_double() + 1, 1)
  })
  for b in items {
    tree.insert(b)
    tree.insert(b)
  }
  for i = 0; i < items.length(); i = i + 1 {
    assert_true(tree.remove(items[i]))
    assert_eq(check_node(tree, tree.root, true), 300 - i - 1)
    assert_true(tree.search(items[i]).contains(items[i]))
  }
  for b in items {
    assert_true(tree.remove(b))
  }
  assert_eq(tree.root.height, 1)
  assert_true(tree.all().is_empty())
  assert_false(tree.remove(items[0]))
  tree.insert(items[0])
  tree.clear()
  assert_false(tree.collides(items[0]))
}

///|
test "custom equality removes a unique id" {
  let tree = RBush::new((t : (Int32, BBox)) => t.1)
  let b = BBox::new(0, 0, 1, 1)
  tree.insert((1, b))
  tree.insert((2, b))
  assert_true(tree.remove_by((2, b), (a, b) => a.0 == b.0))
  assert_eq(tree.all()[0].0, 1)
}
