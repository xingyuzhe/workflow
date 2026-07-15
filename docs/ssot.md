# SSOT — 产物归属

| 内容 | 权威文件 |
|------|----------|
| Why / 范围 / 能力清单 | `proposal.md` |
| 跨模块决策 | change 级 `design.md` |
| 模块结构 / 类型 / 对内接口 | `specs/<capability>/design.md` |
| 可验证行为 | `specs/<capability>/spec.md` |

规则同时写在 `openspec/config.yaml`（init 会覆盖目标项目中的该文件）与 `workflow-spec` schema 的 instructions 中。

同一段多行结构/类型内容不要在两个产物里各写一份——保留权威处，其余用链接指向。
