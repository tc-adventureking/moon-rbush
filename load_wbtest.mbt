test "OMT height boundaries, ties, and atomic validation" {
  for capacity in [4,9,16] {
    for size in [0,1,3,4,9,16,17,63,64,65,80,81,82,255,256,257,728,729,730,2000] {
      let items = Array::makei(size,i => BBox::new((i%19).to_double(),(i%23).to_double(),(i%19).to_double()+1,(i%23).to_double()+1))
      let before = items.copy()
      let tree = RBush::new((b : BBox) => b,max_entries=capacity)
      tree.load(items)
      assert_eq(items,before)
      assert_eq(check_node(tree,tree.root,true),size)
      let q = BBox::new(5,5,10,10)
      assert_eq(tree.search(q).length(),items.filter(b => q.intersects(b)).length())
      let bad = { min_x: 2.0, min_y: 0.0, max_x: 1.0, max_y: 1.0 }
      assert_true(try { tree.load([BBox::new(0,0,1,1),bad]); false } catch { _ => true })
      assert_eq(check_node(tree,tree.root,true),size)
    }
  }
}
