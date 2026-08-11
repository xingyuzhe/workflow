# SSOT — 产物归属

| 内容 | 权威文件 |
|------|----------|
| Why / 范围 / 能力清单 | `proposal.md` |
| 跨模块决策 | change 级 `design.md` |
| 模块结构 / 类型 / 对内接口 | `specs/<capability>/design.md` |
| 可验证行为 | `specs/<capability>/spec.md` |
| Workflow prompts / gates | `.workflow/pack/` |
| 项目规则 | `.workflow/rules.json` + `.workflow/rules/` |
| MCP 定义 | `.workflow/mcp.json` |
| Workflow version / manifest / state | `.workflow/` 对应 JSON 文件 |

OpenSpec artifact 规则写在 `openspec/config.workflow.yaml`（工作流）与可选的 `openspec/config.project.yaml`（项目私有）；`init`、显式 sync 或 `doctor -Fix` 合并生成 CLI 读取的 `openspec/config.yaml`（勿手改）。默认 Doctor 只报告漂移。

`.cursor/`、`.agents/`、`.codex/` 中 workflow-owned 文件都是客户端适配产物，不是新的事实来源。

同一段多行结构/类型内容不要在两个产物里各写一份——保留权威处，其余用链接指向。
