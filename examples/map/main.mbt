///|
struct POI {
  id : Int32
  name : String
  lon : Double
  lat : Double
}

///|
fn bounds(p : POI) -> @rbush.BBox {
  { min_x: p.lon, min_y: p.lat, max_x: p.lon, max_y: p.lat, }
}

///|
fn scenario() -> Unit raise {
  let index = @rbush.RBush::new(bounds)
  let park = { id: 1, name: "Park", lon: 112.92, lat: 27.85, }
  let library = { id: 2, name: "Library", lon: 112.91, lat: 27.86, }
  index.load([park, library])
  let viewport = @rbush.BBox::new(112.90, 27.84, 112.93, 27.86)
  let visible = index.search(viewport)
  assert_eq(visible.length(), 2)
  println("Visible POIs: \{visible.length()}")
  for p in visible {
    println(p.name)
  }
  assert_true(index.remove_by(park, (a, b) => a.id == b.id))
  index.insert({ id: 3, name: "Cafe", lon: 112.915, lat: 27.85, })
  index.insert({ id: 4, name: "Distant station", lon: 113.10, lat: 28.10, })
  let updated = index.search(viewport).map(p => p.id)
  updated.sort()
  assert_eq(updated, [2, 3])
  println("Updated viewport IDs: \{updated[0]}, \{updated[1]}")
}

///|
fn main {
  try! scenario()
}
