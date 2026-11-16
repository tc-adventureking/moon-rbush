///|
/// Closed, axis-aligned rectangle. Boundary contact counts as intersection.
#derive(Eq, Debug)
pub(all) struct BBox {
  min_x : Double
  min_y : Double
  max_x : Double
  max_y : Double
}

///|
#derive(Debug)
pub suberror RBushError {
  InvalidBBox
  InvalidSnapshot(String)
}

///|
pub fn BBox::new(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> BBox raise RBushError {
  let b = { min_x, min_y, max_x, max_y, }
  b.validate()
  b
}

///|
fn BBox::validate(self : BBox) -> Unit raise RBushError {
  for v in [self.min_x, self.min_y, self.max_x, self.max_y] {
    if v.is_nan() || v.is_inf() {
      raise InvalidBBox
    }
  }
  if self.min_x > self.max_x || self.min_y > self.max_y {
    raise InvalidBBox
  }
}

///|
pub fn BBox::intersects(self : BBox, b : BBox) -> Bool {
  b.min_x <= self.max_x &&
  b.min_y <= self.max_y &&
  b.max_x >= self.min_x &&
  b.max_y >= self.min_y
}

///|
pub fn BBox::contains(self : BBox, b : BBox) -> Bool {
  self.min_x <= b.min_x &&
  self.min_y <= b.min_y &&
  b.max_x <= self.max_x &&
  b.max_y <= self.max_y
}

///|
fn empty_bbox() -> BBox {
  { min_x: 1.0 / 0.0, min_y: 1.0 / 0.0, max_x: -1.0 / 0.0, max_y: -1.0 / 0.0, }
}

///|
fn union(a : BBox, b : BBox) -> BBox {
  {
    min_x: dmin(a.min_x, b.min_x),
    min_y: dmin(a.min_y, b.min_y),
    max_x: dmax(a.max_x, b.max_x),
    max_y: dmax(a.max_y, b.max_y),
  }
}

///|
fn area(b : BBox) -> Double {
  (b.max_x - b.min_x) * (b.max_y - b.min_y)
}

///|
fn margin(b : BBox) -> Double {
  (b.max_x - b.min_x) + (b.max_y - b.min_y)
}

///|
fn overlap(a : BBox, b : BBox) -> Double {
  dmax(
    0.0,
    dmin(a.max_x, b.max_x) - dmax(a.min_x, b.min_x),
  ) *
  dmax(
    0.0,
    dmin(a.max_y, b.max_y) - dmax(a.min_y, b.min_y),
  )
}

fn dmin(a : Double, b : Double) -> Double { if a < b { a } else { b } }
fn dmax(a : Double, b : Double) -> Double { if a > b { a } else { b } }

