# 验证范围与复现

## 已验证环境

- `moon 0.1.20261104`（940aa18）与 `moonc v0.10.20+65efd5b93`。
- wasm-gc、wasm、JavaScript、native 四后端均通过构建与测试；JavaScript 实测 Node.js 26.13.1，native 需要 C 工具链。
- 20 项公开测试、三个完整消费者场景；独立工作区消费及公开错误处理已实测。

[CI 配置](../.github/workflows/ci.yml)固定上述编译器/core 版本与 Node.js 版本，构建、测试并执行三个场景，另设上游 oracle 复现任务。配置中的工具安装 actions 固定到具体提交。

## 本地执行

```bash
moon build --target wasm-gc
moon test --target wasm-gc
moon test --target wasm
moon test --target js
moon test --target native
moon run examples/map
moon run examples/game
moon run examples/editor
moon fmt --check
```

按目标构建可将第一条命令的 `wasm-gc` 换成 `wasm`、`js` 或 `native`；示例同样可加 `--target`。基础测试使用已检入的 oracle 数据，无需联网或安装 npm 依赖。

## 独立上游 oracle

```bash
node scripts/generate_oracle.mjs --check
```

需要 Node.js 20.11 或更高版本及网络访问。此命令从官方源获取 RBush 4.0.1 固定 commit `c3f6ad06f1e47ccec58998461f3383aa90066ecd` 与 quickselect 3.0.0，校验 SHA256 后执行原始 JavaScript，并核对已检入数据。去掉 `--check` 会重新生成 fixture，修改后须审阅差异。

当前为 **81 个场景、2428 次操作**，比较查询结果集合、碰撞判断、最终内容及完整最终树拓扑。覆盖容量下限、非平方容量、整幂边界、重复坐标、同高/异高合并、随机增删、极值点框，以及确定性的清空后重新插入和查询；非平方容量另保留复杂最终拓扑样本。

## 其他检查

- 1500 次随机变更：逐步核对精确排序多重集、全部索引内容与节点不变式。
- 动态树：节点容量、高度、精确子项包围盒并集，删除重复项和空分支。
- 输入：闭区间边界、零面积、NaN/无穷/反向坐标、极大有限值，以及无效插入和批装载的原子性。
- 恢复：完整拓扑与空根往返，删除后占用不足的节点，容量错误、真正子树高度不匹配、空非根内部节点和解码失败时原树不变，正负零数值比较。
- 扩展：泛型非恒等载荷、最小坐标比较器与 quickselect 的采样分支和分区。
- 剪枝：用计数 `to_bbox` 回调验证选择性查询不扫描所有条目；这是访问证据，不是时间基准或普遍加速承诺。

这些检查支持当前范围内的结果，不等同于所有输入零缺陷、所有浮点输入的完全同构或特定性能保证。API 边界见[兼容性说明](COMPATIBILITY.md)，实际操作见[使用方法](USAGE.md)。
