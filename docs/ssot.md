# SSOT — 产物归属

| 内容 | 权威文件 |
|------|----------|
| Why / 范围 / 能力清单 | `proposal.md` |
| 跨模块决策 | change 级 `design.md` |
| 模块结构 / 类型 / 对内接口 | `specs/<capability>/design.md` |
| 可验证行为 | `specs/<capability>/spec.md` |

规则写在 `openspec/config.workflow.yaml`（工作流）与可选的 `openspec/config.project.yaml`（项目私有）；`init` 合并生成 CLI 读取的 `openspec/config.yaml`（勿手改）。`workflow-spec` schema 的 instructions 中也有对应约束。

同一段多行结构/类型内容不要在两个产物里各写一份——保留权威处，其余用链接指向。
