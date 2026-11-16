# Moon RBush

A generic, mutable 2D R-tree for MoonBit, ported from [RBush 4.0.1](https://github.com/mourner/rbush/tree/v4.0.1). It supports rectangle queries, dynamic insertion/deletion, OMT bulk construction, STLT batch insertion, and topology-preserving JSON snapshots. No third-party runtime dependencies.

Useful for map viewports, game broadphase collision candidates, and editor rectangle selection. Queries prune disjoint branches; highly overlapping data can still require visiting most entries. This library does not perform exact shape collision, geographic wrapping, nearest-neighbor queries, or concurrent mutation.

## Run

Install the [MoonBit toolchain](https://www.moonbitlang.com/download/). Verified with `moonc v0.10.20+65efd5b93` and `moon 0.1.20261104`.

```sh
git clone https://github.com/tc-adventureking/moon-rbush.git
cd moon-rbush
moon test
moon run examples/map
moon run examples/game
moon run examples/editor
```

The map example loads POIs, queries a viewport, removes/adds POIs and verifies the updated viewport. The game example removes the moving rectangle before each collision check, restores its old position on rejection, then accepts a free move. The editor example distinguishes intersection from containment, drags a shape, saves/parses JSON text, restores, queries and edits the reopened tree. Examples are separate packages using only the public API.

For a separate application, place this checkout at `workspace/moon-rbush` and create `workspace/consumer` with the following four files. This uses the toolchain's [local workspace resolution](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#dependency-management), without requiring a registry release.

`consumer/moon.work`:

```moonbit
members = [".", "../moon-rbush"]
```

`consumer/moon.mod`:

```moonbit
name = "local/consumer"
version = "0.1.0"
import { "tc-adventureking/rbush@0.1.0" }
```

`consumer/moon.pkg`:

```moonbit
import { "tc-adventureking/rbush" }
options("is-main": true)
```

`consumer/main.mbt`:

```moonbit
fn main {
  let tree = @rbush.RBush::new((b : @rbush.BBox) => b)
  let box = try! @rbush.BBox::new(0, 0, 1, 1)
  try! tree.insert(box)
  println(tree.all().length())
}
```

Run `cd workspace/consumer` then `moon run .`; it prints `1`. The workspace member resolves locally; the declared version does not trigger a registry download. The generated public interface is in `pkg.generated.mbti`.

```moonbit
let tree = @rbush.RBush::new((b : @rbush.BBox) => b)
let box = @rbush.BBox::new(0, 0, 10, 10) // raises RBushError on invalid coordinates
tree.insert(box)
let hits = tree.search(@rbush.BBox::new(5, 5, 15, 15))
let removed = tree.remove(box)
```

Handle raised errors in your application; the runnable examples show complete packages.

## API and semantics

| Upstream | MoonBit |
| --- | --- |
| `new RBush(maxEntries)` / `toBBox` | `RBush::new(to_bbox, max_entries?=9, compare_min_x?, compare_min_y?)` |
| `compareMinX` / `compareMinY` | Optional constructor comparison callbacks `(T,T)->Int`; defaults use `to_bbox` minima |
| `all()` | `tree.all() -> Array[T]` |
| `search(bbox)` | `tree.search(bbox) -> Array[T] raise RBushError` |
| `collides(bbox)` | `tree.collides(bbox) -> Bool raise RBushError` |
| `insert(item)` | `tree.insert(item) -> Unit raise RBushError` |
| `load(items)` | `tree.load(Array[T]) -> Unit raise RBushError` |
| `remove(item, equalsFn?)` | `tree.remove(item)` with `T: Eq`, or `tree.remove_by(item, equals)`, returning `Bool raise RBushError` |
| `clear()` | `tree.clear() -> Unit` |
| `toJSON()` | `tree.to_json(encode: (T)->Json) -> Json` |
| `fromJSON(data)` | `tree.restore(json, decode)` or `RBush::from_json(json, to_bbox, decode, max_entries?=9, compare_min_x?, compare_min_y?)`, raising `Error` |

`BBox` has public `Double` fields `min_x`, `min_y`, `max_x`, `max_y`, plus `new`, `intersects`, and `contains`. Rectangles are closed: touching edges/corners intersect. Points and zero-width/height rectangles are legal. Tree operations validate coordinates even if you construct a `BBox` literal: NaN, infinities and reversed bounds are rejected. Geometry predicates operate directly on their arguments; use valid boxes.

Capacity is clamped to at least 4; minimum split occupancy is `ceil(max_entries * 0.4)`. `load` validates the **entire** batch before modifying the tree and does not reorder the caller's array. It uses OMT for packing, STLT for merging nonempty trees and individual insertion for small batches. `all` and `search` return new arrays; payload values are not deep-copied. No sorted result order is promised. Mutation methods return `Unit`, rather than JavaScript's chainable tree; removal returns whether one entry was removed.

MoonBit default removal uses **value equality**, adapting JavaScript's reference identity. Equal duplicates are retained and each removal deletes only the first matching entry in traversal order. For unique identities, store an id and use `remove_by(old_item, (a,b) => a.id == b.id)`. Keep indexed payload coordinates unchanged: **remove the old value, then insert the new value** when moving an item. Removal uses the supplied old bbox for traversal.

Callbacks must be deterministic, must not mutate indexed payload coordinates, and must not reenter/mutate the tree. Comparators must consistently order entries by increasing minimum x/y, returning negative/zero/positive. Coordinates can be finite while derived area calculations overflow; tree bounding boxes and queries remain valid, but heuristic split quality can degrade at extreme magnitudes.

## Snapshots

Snapshots use the original **raw root** schema: `children`, `height`, `leaf`, `minX`, `minY`, `maxX`, `maxY`. Leaf children are payload JSON returned by your encoder; internal children are nodes. Empty-root bounds are `null`, matching `JSON.stringify` of upstream Infinity bounds. There is no wrapper or embedded capacity. Restore with the **same `max_entries`** configuration; a smaller capacity can reject the snapshot. Signed zero is compared numerically.

The decoder has signature `(Json) -> T raise Error`; wrap a pure or specifically typed throwing function in a lambda when needed. Decoder failures leave an existing tree unchanged. Restoration validates integer heights, leaf flags, equal child heights, maximum occupancy, nonempty nonroot nodes, finite ordered bounds, callback-derived payload bboxes, and exact unions. Underfilled nodes left by deletion are accepted. Maximum restored height/depth is 64. Restoration builds a fresh topology before replacing the root. The caller owns payload JSON validation, including ids and application constraints.

Upstream snapshots are accepted if their data satisfies these stricter validity checks. A MoonBit snapshot can be consumed by upstream `fromJSON` when its payload format matches upstream `toBBox`. OMT height uses integer powers to avoid floating logarithm rounding at exact powers; split sorting is stable to match modern JavaScript. Exact topology matched the checked upstream fixtures, including tested power boundaries; this is not a promise of identical topology for every possible floating-point input/backend.

## Verification

```sh
moon test --target wasm-gc
moon test --target wasm
moon test --target js       # verified with Node 26.13.1
moon test --target native   # C compiler required
node scripts/generate_oracle.mjs --check  # Node >=20.11, internet required
```

The checked-in oracle is reproducible from SHA256-verified official RBush commit `c3f6ad06f1e47ccec58998461f3383aa90066ecd` and quickselect 3.0.0 source. It covers 81 scenarios / 2428 operations, comparing query sets, collisions, final contents, and complete final tree topology. MoonBit tests also check exact node unions, height/capacity invariants, 1500 random mutations against a brute-force multiset, invalid-input atomicity, malformed snapshots, duplicate removal, comparator callbacks, boundary contact, extreme finite coordinates, and quickselect's sampled path. A counting `to_bbox` callback demonstrates selective-query pruning without a timing claim. Fixtures are checked in, so normal tests run offline; the generator is only needed to reproduce/check the independent oracle.

## License

MIT. Original RBush copyright and license are retained in [LICENSE](LICENSE). The internal quickselect port is ISC; see [QUICKSELECT_LICENSE](QUICKSELECT_LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for pinned sources and attribution.
