# moon-rbush

纯 MoonBit 泛型动态二维 R-tree 库，移植自 [RBush 4.0.1](https://github.com/mourner/rbush/tree/v4.0.1)，支持 wasm、wasm-gc、JavaScript 和 native；核心只依赖 MoonBit 标准库。

## 功能

- **矩形 `BBox`**：有限有效坐标校验、相交与包含判断；闭区间语义，允许点框与零宽高矩形，边界接触算相交。
- **动态树 `RBush[T]`**：自定义载荷与包围盒回调，插入、R* 分裂、按值或自定义身份删除、空节点清理及清空。
- **查询与批装载**：`all`、剪枝 `search`、提前退出的 `collides`；OMT 批量构建、STLT 非空树合并及小批量插入。
- **JSON 快照**：保留上游原始根节点格式与完整拓扑，自定义载荷编解码，恢复前严格校验，失败时保留原树。

仓库源码也提供普通矩形的 JSON 编解码，可直接交换上游坐标字段。用法见[源码版矩形 JSON 交换](docs/USAGE.md#源码版矩形-json-交换)。

适用于地图视口、游戏碰撞候选和编辑器框选；不包含精确形状碰撞、经度环绕、最近邻查询或并发修改。

## 安装与使用

在 MoonBit 项目中安装：

```bash
moon add tc-adventureking/rbush@0.1.0
```

在消费者的 `moon.pkg` 中导入：

```moonbit
import { "tc-adventureking/rbush" }
```

消费者的 `main.mbt`：

```moonbit
fn main {
  let tree = @rbush.RBush::new((b : @rbush.BBox) => b)
  let box = try! @rbush.BBox::new(0, 0, 10, 10)
  try! tree.insert(box)
  let query = try! @rbush.BBox::new(10, 10, 20, 20)
  let hits = try! tree.search(query)
  println(hits.length()) // 1：边界接触也相交
}
```

`try!` 用于这里已知合法的固定输入；应用应处理 `RBushError` 和载荷解码错误。默认删除使用 MoonBit 值相等；移动条目须先用旧坐标删除，再插入新值。

[完整 API](pkg.generated.mbti) · [上游对照与契约](docs/COMPATIBILITY.md) · [使用场景](docs/USAGE.md)

## 示例与测试

安装 [MoonBit 工具链](https://www.moonbitlang.com/download/) 后，在源码仓库运行：

```bash
git clone https://github.com/tc-adventureking/moon-rbush.git
cd moon-rbush
moon run examples/map
moon run examples/game
moon run examples/editor
moon test
```

示例分别演示视口更新、阻挡回退与成功移动、拖动后保存和重新打开编辑。22 项公开测试覆盖四后端。上游对照包含 81 个场景、2428 次操作，核对查询结果与最终树结构。[验证范围与复现](docs/TESTING.md)

## 许可

项目代码使用 [MIT](LICENSE)，保留 RBush 原许可；内部 quickselect 移植使用 [ISC](QUICKSELECT_LICENSE)。固定来源与归属见 [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)。
