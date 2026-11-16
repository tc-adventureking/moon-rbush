# 上游对照与契约

移植参考为 [RBush 4.0.1](https://github.com/mourner/rbush/tree/v4.0.1)，固定 commit `c3f6ad06f1e47ccec58998461f3383aa90066ecd`；内部选择算法来自 quickselect 3.0.0。来源与许可见[归属说明](../THIRD_PARTY_NOTICES.md)。

## API 对照

| 上游 | MoonBit |
| --- | --- |
| `new RBush(maxEntries)` / `toBBox` | `RBush::new(to_bbox, max_entries?=9, compare_min_x?, compare_min_y?)` |
| `compareMinX` / `compareMinY` | 构造器可选 `(T,T)->Int` 回调；默认按 `to_bbox` 的最小坐标比较 |
| `all()` | `tree.all() -> Array[T]` |
| `search(bbox)` | `tree.search(bbox) -> Array[T] raise RBushError` |
| `collides(bbox)` | `tree.collides(bbox) -> Bool raise RBushError` |
| `insert(item)` | `tree.insert(item) -> Unit raise RBushError` |
| `load(items)` | `tree.load(Array[T]) -> Unit raise RBushError` |
| `remove(item, equalsFn?)` | `tree.remove(item)` 要求 `T: Eq`；或 `tree.remove_by(item, equals)`，均返回 `Bool raise RBushError` |
| `clear()` | `tree.clear() -> Unit` |
| `toJSON()` | `tree.to_json(encode: (T)->Json) -> Json` |
| `fromJSON(data)` | `tree.restore(json, decode)`；或 `RBush::from_json(json, to_bbox, decode, max_entries?=9, compare_min_x?, compare_min_y?)`，均可抛出 `Error` |

完整签名见 [pkg.generated.mbti](../pkg.generated.mbti)。修改方法不返回可链式调用的树：插入、装载、清空和恢复返回 `Unit`，删除返回是否移除一项。

## 坐标、查询与载荷

`BBox` 的公开字段为 `Double` 类型的 `min_x`、`min_y`、`max_x`、`max_y`，提供 `new`、`intersects` 和 `contains`。矩形使用闭区间：边、角接触算相交；点框、零宽或零高合法。

构造器和树的坐标入口拒绝 NaN、正负无穷以及最小值大于最大值；直接构造 `BBox` 字面量不会绕过树操作的校验。几何谓词直接计算参数，不额外校验，调用方须提供有效框。

`search` 返回相交条目，完全包含筛选由调用方完成。`all` 和 `search` 返回新数组，但不深拷贝载荷；结果不承诺排序。树查询剪去不相交分支，高度重叠的数据仍可能访问大部分条目。

默认 `remove` 使用 MoonBit **值相等**，对应上游 JavaScript 引用身份的语言适配。相等重复项可共存，一次删除只移除遍历遇到的第一个匹配项。需要唯一身份时存储 id，并使用 `remove_by(old_item, (a,b) => a.id == b.id)`。

索引期间不能原地修改载荷坐标。移动条目须**先用旧值、旧包围盒删除，再插入新值**；删除依赖传入旧框剪枝。检测实体移动时先移除自身，失败则恢复旧值，示例见[游戏场景](../examples/game/main.mbt)。

回调必须确定、稳定，不得改变已索引坐标，也不得重入或修改同一棵树。比较器须一致地按最小 x/y 递增排列，返回负数、零或正数。

## 容量与批装载

`max_entries` 默认 9，最小钳制到 4；分裂最小占用为 `ceil(max_entries * 0.4)`。`load` 在修改树前验证整批输入，任一框无效时整批不写入，并且不会重排调用方数组。此前提依赖回调保持确定且不重入。

装载使用 OMT 批量构建、STLT 非空树合并，小批量逐项插入；动态插入保留子树选择、R* 分裂和祖先包围盒调整。删除清理空分支，不要求保留节点继续满足分裂时的最小占用。

有限坐标仍可能使面积等启发式计算溢出。包围盒和查询可继续工作，但极值下分裂质量可能下降；不承诺普遍对数查询时间或固定速度优势。

## JSON 快照

快照直接使用上游**原始根节点**字段：`children`、`height`、`leaf`、`minX`、`minY`、`maxX`、`maxY`。叶子 children 为编码器返回的载荷 JSON，内部 children 为节点。空根的四个边界为 `null`，对应上游 Infinity 边界经 `JSON.stringify` 后的结果。

格式不加外层封装，也**不包含容量**。恢复时应传入原来的 `max_entries`；较小容量可能拒绝快照，其他配置也应一致。正负零按数值相等比较。

解码器签名为 `(Json) -> T raise Error`；纯函数或抛出具体错误类型的函数可包在 lambda 中传入。调用方负责 id 等载荷自身的 JSON 校验。解码器错误、无效载荷框或结构校验错误均不会替换原树。

恢复先构建新拓扑，再替换根，检查：

- 整数树高、叶子标志、子节点高度关系及叶子同高。
- 节点不超过容量，非根节点非空，空根必须为高度 1 的叶子。
- 非空节点边界有限、有序，精确等于子项并集；载荷边界由 `to_bbox` 计算并验证。
- 恢复高度和深度最多 64。

删除后占用不足但非空的节点可恢复，不强制最小占用。符合以上更严格条件的上游快照可读入；MoonBit 快照的载荷格式若满足上游 `toBBox`，也可交给其 `fromJSON`。

OMT 树高用整数幂计算，避免整幂边界的浮点对数舍入；分裂排序稳定，以对应现代 JavaScript。已测样本的完整树拓扑一致，包括容量及整幂边界；不承诺所有浮点输入、所有后端都与上游逐节点相同。

库不提供最近邻、三维、精确形状碰撞、经度环绕或并发修改；这些由调用方或其他实现处理。
