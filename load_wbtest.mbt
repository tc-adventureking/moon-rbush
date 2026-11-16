///|
test "OMT height boundaries, ties, and atomic validation" {
  for capacity in [4, 9, 16] {
    for
      size in [
        0, 1, 3, 4, 9, 16, 17, 63, 64, 65, 80, 81, 82, 255, 256, 257, 728, 729, 730,
        2000,
      ] {
      let items = Array::makei(size, i => {
        BBox::new(
          (i % 19).to_double(),
          (i % 23).to_double(),
          (i % 19).to_double() + 1,
          (i % 23).to_double() + 1,
        )
      })
      let before = items.copy()
      let tree = RBush::new((b : BBox) => b, max_entries=capacity)
      tree.load(items)
      assert_eq(items, before)
      assert_eq(check_node(tree, tree.root, true), size)
      let q = BBox::new(5, 5, 10, 10)
      assert_eq(
        tree.search(q).length(),
        items.filter(b => q.intersects(b)).length(),
      )
      let bad = { min_x: 2.0, min_y: 0.0, max_x: 1.0, max_y: 1.0, }
      assert_true(
        try {
          tree.load([BBox::new(0, 0, 1, 1), bad])
          false
        } catch {
          _ => true
        },
      )
      assert_eq(check_node(tree, tree.root, true), size)
    }
  }
}

///|
test "STLT batches with smaller equal and taller tree heights" {
  for
    pair in [
      (1, 0),
      (1, 1),
      (4, 4),
      (4, 300),
      (300, 4),
      (300, 300),
      (500, 2000),
    ] {
    let (first, second) = pair
    let tree = RBush::new((b : BBox) => b, max_entries=4)
    let items = Array::makei(first + second, i => {
      BBox::new(
        (i % 41).to_double(),
        (i % 37).to_double(),
        (i % 41).to_double() + 0.5,
        (i % 37).to_double() + 0.5,
      )
    })
    tree.load(items[:first].to_owned())
    tree.load(items[first:].to_owned())
    assert_eq(check_node(tree, tree.root, true), first + second)
    for i = 0; i < 20; i = i + 1 {
      let q = BBox::new(
        i.to_double(),
        i.to_double(),
        i.to_double() + 3,
        i.to_double() + 5,
      )
      assert_eq(
        tree.search(q).length(),
        items.filter(b => q.intersects(b)).length(),
      )
    }
  }
}
