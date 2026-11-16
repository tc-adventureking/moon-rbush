test "queries match brute force and prune disjoint branches" {
  let items = Array::makei(2000, i => BBox::new((i % 50).to_double()*10, (i / 50).to_double()*10, (i % 50).to_double()*10+1, (i / 50).to_double()*10+1))
  let evaluations = Ref(0)
  let tree = RBush::new((b : BBox) => { evaluations.val += 1; b })
  for b in items { tree.insert(b) }
  assert_eq(tree.all().length(),items.length())
  for i = 0; i < 100; i = i + 1 {
    let x = (i * 17 % 500).to_double()
    let y = (i * 31 % 400).to_double()
    let q = BBox::new(x,y,x+20,y+30)
    let expected = items.filter(b => q.intersects(b))
    let actual = tree.search(q)
    assert_eq(actual.length(),expected.length())
    for b in actual { assert_true(expected.contains(b)) }
    assert_eq(tree.collides(q),expected.length() > 0)
  }
  evaluations.val = 0
  assert_eq(tree.search(BBox::new(0,0,1,1)).length(),1)
  assert_true(evaluations.val < 100)
  assert_eq(tree.search(BBox::new(-1,-1,1000,1000)).length(),2000)
  assert_false(tree.collides(BBox::new(-10,-10,-1,-1)))
  let bad = { min_x: 2.0, min_y: 0.0, max_x: 1.0, max_y: 1.0 }
  assert_true(try { let _ = tree.search(bad); false } catch { _ => true })
  assert_true(try { let _ = tree.collides(bad); false } catch { _ => true })
}

