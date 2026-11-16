///|
struct Entity {
  id : Int32
  box : @rbush.BBox
}

///|
fn main {
  let index = @rbush.RBush::new((e : Entity) => e.box)
  let player = {
    id: 1,
    box: { min_x: 0.0, min_y: 0.0, max_x: 1.0, max_y: 1.0, },
  }
  let wall = {
    id: 2,
    box: { min_x: 3.0, min_y: 0.0, max_x: 4.0, max_y: 2.0, },
  }
  index.load([player, wall]) catch {
    _ => abort("valid boxes")
  }
  let removed = index.remove_by(player, (a, b) => a.id == b.id) catch {
    _ => abort("valid box")
  }
  assert_true(removed) catch {
    _ => abort("expected player")
  }
  let moved = {
    id: 1,
    box: { min_x: 2.5, min_y: 0.0, max_x: 3.5, max_y: 1.0, },
  }
  let blocked = index.collides(moved.box) catch { _ => abort("valid box") }
  println("Movement has collision candidates: \{blocked}")
  let candidates = index.search(moved.box) catch { _ => abort("valid box") }
  assert_eq(candidates.map(e => e.id), [2]) catch {
    _ => abort("expected wall candidate")
  }
  for e in candidates {
    println("Candidate entity: \{e.id}")
  }
  // Here the caller can run narrow-phase shape tests before accepting movement.
  index.insert(moved) catch {
    _ => abort("valid box")
  }
  assert_eq(index.all().length(), 2) catch {
    _ => abort("expected two entities")
  }
  println("Indexed entities after movement: \{index.all().length()}")
}
