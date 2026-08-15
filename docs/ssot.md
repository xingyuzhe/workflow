# SSOT — 产物归属

| 内容 | 权威文件 |
|---|---|
| Why / 范围 / 能力清单 | change `proposal.md` |
| 跨模块决策 | change `design.md` |
| 模块结构 / 类型 / 对内接口 | `specs/<capability>/design.md` |
| 可验证行为 | `specs/<capability>/spec.md` |
| Artifact 图、路径与模板 | `.workflow/schemas/workflow-contract/` |
| 生命周期与 acceptance 契约 | `.workflow/pack/` |
| 工作流默认规则（源码仓库） | `.workflow/rules.json` + `.workflow/rules/` |
| 工作流默认 MCP 定义（源码仓库） | `.workflow/mcp.json` |
| Change、主规格与归档 | `.workflow/changes/` + `.workflow/specs/` |

`.workflow/config.workflow.json` 是工作流默认配置，`.workflow/config.project.json` 是项目私有配置，`.workflow/config.json` 是生成结果。三者均使用严格 JSON；未知字段或非法类型必须显式失败。

源码仓库中的默认规则和 MCP 定义只用于生成客户端适配，不随 Codex artifact 发布。下游项目已有的 `.workflow/rules.json`、`.workflow/rules/` 和 `.workflow/mcp.json` 是项目输入：发布必须保留并编译它们，但它们不反向成为 Workflow 源码的事实来源。

`.cursor/`、`.agents/` 和 `.codex/` 中 workflow-owned 文件是客户端适配产物，不是新的事实来源。例外是下游发布后的 `.agents/skills/workflow`：它是唯一运行时分发单元，但下游 change/spec/config 仍以 `.workflow` 项目数据为权威。

`.workflow/.mutation.lock` 与 `.workflow/.transactions/` 只保存短期并发控制、回滚与中断恢复状态，不是行为或交付事实来源。`doctor` 只读报告其残留；后续 `sync` 或 `archive` 按 journal phase 恢复。

同一段结构或行为定义只保留在其权威 artifact 中，其余位置引用它。
