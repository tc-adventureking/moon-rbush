///|
struct Entity {
  id : Int32
  box : @rbush.BBox
}

///|
fn scenario() -> Unit raise {
  // Entities are rectangles: a bbox intersection is an actual blocked movement.
  let index = @rbush.RBush::new((e : Entity) => e.box)
  let player = {
    id: 1,
    box: { min_x: 0.0, min_y: 0.0, max_x: 1.0, max_y: 1.0, },
  }
  let wall = {
    id: 2,
    box: { min_x: 3.0, min_y: 0.0, max_x: 4.0, max_y: 2.0, },
  }
  index.load([player, wall])
  let blocked_position : @rbush.BBox = {
    min_x: 2.5,
    min_y: 0.0,
    max_x: 3.5,
    max_y: 1.0,
  }
  // Remove the moving entity before testing a proposal, so it cannot collide with itself.
  assert_true(index.remove_by(player, (a, b) => a.id == b.id))
  let blocked = index.collides(blocked_position)
  assert_true(blocked)
  assert_eq(index.search(blocked_position).map(e => e.id), [2])
  if blocked {
    // Reject this proposal and put the old player back at its original position.
    index.insert(player)
    println("Blocked movement rejected")
  } else {
    index.insert({ id: 1, box: blocked_position, })
  }
  assert_eq(index.search(player.box).map(e => e.id), [1])
  let accepted = {
    id: 1,
    box: { min_x: 1.5, min_y: 0.0, max_x: 2.5, max_y: 1.0, },
  }
  assert_true(index.remove_by(player, (a, b) => a.id == b.id))
  let free = !index.collides(accepted.box)
  assert_true(free)
  if free {
    index.insert(accepted)
  } else {
    index.insert(player)
  }
  assert_true(index.search(player.box).is_empty())
  let actual = index.search(accepted.box)
  assert_eq(actual.map(e => e.id), [1])
  assert_eq(actual[0].box, accepted.box)
  assert_eq(index.all().length(), 2)
  println("Free movement accepted; old position is empty")
}

///|
fn main {
  try! scenario()
}
