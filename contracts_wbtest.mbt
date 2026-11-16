test "all coordinate entry points reject NaN, infinity and reversed literals atomically" {
  let good = BBox::new(0,0,1,1)
  let tree = RBush::new((b : BBox) => b)
  tree.insert(good)
  for bad in [
    { min_x: 0.0/0.0, min_y: 0.0, max_x: 1.0, max_y: 1.0 },
    { min_x: 0.0, min_y: 0.0, max_x: 1.0/0.0, max_y: 1.0 },
    { min_x: 0.0, min_y: -1.0/0.0, max_x: 1.0, max_y: 1.0 },
    { min_x: 2.0, min_y: 0.0, max_x: 1.0, max_y: 1.0 },
    { min_x: 0.0, min_y: 2.0, max_x: 1.0, max_y: 1.0 },
  ] {
    assert_true(try { tree.insert(bad); false } catch { _ => true })
    assert_true(try { tree.load([good,bad]); false } catch { _ => true })
    assert_true(try { let _ = tree.search(bad); false } catch { _ => true })
    assert_true(try { let _ = tree.collides(bad); false } catch { _ => true })
    assert_true(try { let _ = tree.remove(bad); false } catch { _ => true })
    assert_eq(tree.all().length(),1)
  }
}
test "finite extreme coordinates remain searchable when heuristic areas overflow" {
  let tree = RBush::new((b : BBox) => b,max_entries=4)
  let items = [BBox::new(-1.0e308,-1.0e308,1.0e308,1.0e308),BBox::new(1.0e308,0,1.0e308,0),BBox::new(-1.0e308,0,-1.0e308,0)]
  for _ in 0..<20 { tree.load(items) }
  assert_eq(check_node(tree,tree.root,true),60)
  for q in items {
    assert_eq(tree.search(q).length(),tree.all().filter(b => q.intersects(b)).length())
    assert_true(tree.collides(q))
    assert_true(tree.remove(q))
  }
}
test "custom coordinate comparators work in insert and load" {
  let xcalls = Ref(0)
  let ycalls = Ref(0)
  let tree = RBush::new((b : BBox) => b,max_entries=4,
    compare_min_x=(a,b) => { xcalls.val += 1; coord_cmp(a.min_x,b.min_x) },
    compare_min_y=(a,b) => { ycalls.val += 1; coord_cmp(a.min_y,b.min_y) })
  let items = Array::makei(100,i => BBox::new((i%13).to_double(),(i%17).to_double(),(i%13).to_double()+1,(i%17).to_double()+1))
  tree.load(items)
  for b in items { tree.insert(b) }
  assert_true(xcalls.val > 0 && ycalls.val > 0)
  assert_eq(check_node(tree,tree.root,true),200)
  let q = BBox::new(3,4,8,9)
  assert_eq(tree.search(q).length(),items.filter(b => q.intersects(b)).length()*2)
}
