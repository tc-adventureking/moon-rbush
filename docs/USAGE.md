# 使用方法

## 注册表安装

在已有 MoonBit 项目根目录运行：

```bash
moon add tc-adventureking/rbush@0.1.0
```

无需检出本仓库，也无需 `moon.work` 或本地依赖覆盖。

## 最小消费者

新建 `consumer` 目录，先写入 `consumer/moon.mod`：

```moonbit
name = "local/consumer"
version = "0.1.0"
```

然后在该目录添加依赖：

```bash
cd consumer
moon add tc-adventureking/rbush@0.1.0
```

添加后 `moon.mod` 包含模块依赖：

```moonbit
name = "local/consumer"
version = "0.1.0"
import { "tc-adventureking/rbush@0.1.0" }
```

`consumer/moon.pkg` 声明使用的包：

```moonbit
import { "tc-adventureking/rbush" }
options("is-main": true)
```

`consumer/main.mbt`：

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

在消费者目录运行 `moon run .`，输出 `1`。这里的 `try!` 仅用于固定合法输入；实际应用应处理无效包围盒和解码错误。完整契约见[兼容性说明](COMPATIBILITY.md)，公开签名见[生成接口](../pkg.generated.mbti)。

## 运行仓库示例

```bash
git clone https://github.com/tc-adventureking/moon-rbush.git
cd moon-rbush
moon run examples/map
moon run examples/game
moon run examples/editor
```

- [地图视口](../examples/map/main.mbt)：装载 POI、查询视口、删除和添加 POI，再验证更新后的可见集合。跨 180° 经线的视口须由调用方拆分查询。
- [矩形实体移动](../examples/game/main.mbt)：每次提案前移除旧实体，避免与自身相撞；受阻时恢复旧位置，空闲时插入新位置，并验证最终位置。示例实体本身是矩形；其他形状仍需对候选做精确检测。
- [编辑器框选](../examples/editor/main.mbt)：相交查询后筛选完全包含的形状，拖动形状，保存 JSON 文本，解析恢复后继续查询和修改。

这些是独立包，通过公开 API 使用库，无需地图服务、游戏引擎或图形界面。

## 可选：本地源码开发

开发本库或联调修改时，可以使用[本地工作区](https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html#dependency-management)。这不是注册表安装的前置条件。

```text
workspace/
  moon-rbush/       # 此仓库的源码检出
  consumer/
    moon.work
    moon.mod
    moon.pkg
    main.mbt
```

在上述消费者的 `moon.work` 中添加：

```moonbit
members = [".", "../moon-rbush"]
```

其他三个文件沿用最小消费者配置。工作区成员会从本地源码解析；验证已发布包时应移除这份 `moon.work`，使用正常注册表解析。

## 源码版矩形 JSON 交换

接入仓库源码后，在消费包的 `moon.pkg` 中同时导入 `moonbitlang/core/json`。以下函数读取只有矩形条目的 RBush 快照，再导出同样的原始根节点格式。`capacity` 传入原树容量。

```moonbit
fn reexport_snapshot(text : String, capacity : Int32) -> String raise {
  let tree = @rbush.RBush::from_json(
    @json.parse(text),
    (b : @rbush.BBox) => b,
    j => @rbush.BBox::from_json(j),
    max_entries=capacity,
  )
  tree.to_json(b => b.to_json()).stringify()
}
```

矩形编解码使用 `minX`、`minY`、`maxX`、`maxY`。若载荷还包含 ID 或样式等字段，可以使用自己的类型和编解码器保留这些数据。[编辑器示例](../examples/editor/main.mbt)
