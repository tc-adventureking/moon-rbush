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
test "rectangle JSON exchanges the upstream coordinate fields" {
  let payload = @json.parse(
    "{\"id\":7,\"minX\":-0.125,\"minY\":0.5,\"maxX\":1.25,\"maxY\":0.5}",
  )
  let box = BBox::from_json(payload)
  assert_eq(box, BBox::new(-0.125, 0.5, 1.25, 0.5))
  assert_eq(
    box.to_json(),
    @json.parse("{\"minX\":-0.125,\"minY\":0.5,\"maxX\":1.25,\"maxY\":0.5}"),
  )
  for
    input in [
      "[]", "{\"minX\":0,\"minY\":0,\"maxX\":1}", "{\"minX\":\"0\",\"minY\":0,\"maxX\":1,\"maxY\":1}",
      "{\"minX\":null,\"minY\":0,\"maxX\":1,\"maxY\":1}", "{\"minX\":2,\"minY\":0,\"maxX\":1,\"maxY\":1}",
    ] {
    let value = @json.parse(input)
    assert_true(
      try {
        let _ = BBox::from_json(value)
        false
      } catch {
        InvalidBBox => true
        _ => false
      },
    )
  }
  let signed_zero = BBox::new(-0.0, 0.0, 0.0, 0.0)
  let round_trip = BBox::from_json(
    @json.parse(signed_zero.to_json().stringify()),
  )
  assert_eq(round_trip, signed_zero)
}

///|
test "margin preserves small widths at large offsets" {
  assert_eq(margin(BBox::new(0, 1.0e16, 1, 1.0e16)), 1.0)
}
