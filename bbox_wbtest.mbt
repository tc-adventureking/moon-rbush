///|
test "closed rectangles and validation" {
  let a = BBox::new(0, 0, 2, 2)
  assert_true(a.intersects(BBox::new(2, 2, 3, 3)))
  assert_true(a.contains(BBox::new(1, 1, 1, 1)))
  assert_false(a.intersects(BBox::new(3, 0, 4, 1)))
  let invalid = try {
    let _ = BBox::new(2, 0, 1, 1)
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}

///|
test "margin preserves small widths at large offsets" {
  assert_eq(margin(BBox::new(0, 1.0e16, 1, 1.0e16)), 1.0)
}
