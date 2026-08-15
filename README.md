# Workflow

面向 Cursor 与 Codex 的自包含变更工作流。它定义生命周期规则、每一步的产物、验收条件和授权边界；不依赖外部生命周期 CLI 或 npm 包，也不规定 agent 的通用实现方法。

## 部署到 Codex 项目（推荐）

```powershell
pwsh -File scripts/deploy.ps1 -Target D:\work\your-project -Yes
pwsh -File scripts/check-deployment.ps1 -Target D:\work\your-project
```

`deploy` 只发布 Codex 运行时 `.agents/skills/workflow`，并安装项目使用的 JSON 配置与 schema。它不会把源码专用的 `pack`、`cli` 或部署脚本复制到下游。

只有需要同时安装 Cursor 与 Codex、并保留完整源码布局时，才使用完整安装：

```powershell
pwsh -File scripts/init.ps1 -Target D:\work\your-project -Clients cursor,codex -Yes
pwsh -File scripts/doctor.ps1 -ProjectRoot D:\work\your-project
```

两种模式都会更新 workflow-owned 内容，保留 `.workflow/config.project.json` 与项目自有内容。破坏性边界见 [docs/BREAKING.md](docs/BREAKING.md)。

## 目录

| 路径 | 作用 |
|---|---|
| `.workflow/pack/` | 平台无关的生命周期与验收契约（源码仓库 SSOT） |
| `.workflow/cli/` | 仓库自带 CLI 源码（源码仓库） |
| `.workflow/schemas/workflow-contract/` | 本地 artifact contract 与模板 |
| `.workflow/changes/` · `.workflow/specs/` | change 与主规格数据 |
| `.workflow/config.workflow.json` | 工作流默认配置，部署时可更新 |
| `.workflow/config.project.json` | 项目私有配置，部署不覆盖 |
| `.workflow/config.json` | 前两者的生成结果，勿手改 |
| `.agents/skills/workflow/` | Codex 唯一发布运行时，内含 CLI、references 和元数据 |
| `.cursor/commands/workflow-*.md` | Cursor 生命周期入口 |
| `AGENTS.md` managed block | Codex 持久路由；保留块外内容 |

workflow 源码仓库同时保留 `.workflow` 真相源和 `.agents/skills/workflow` 生成物，用生成物自我迭代。下游只接收 `.agents/skills/workflow` 这一份运行时，以及 `.workflow` 下的项目数据、配置与 schema；不会接收源码专用的 `pack` 或 `cli`。

## 使用

Cursor 使用 `/workflow:<operation>`；Codex 使用 `$workflow <operation>`，自然语言表达同等生命周期意图也可以。

常见顺序：

```text
explore（可选） → new 或 ff → continue → grill（可选）
→ apply → verify → sync（可选，archive 也会同步） → archive
```

| 操作 | 产物或结果 |
|---|---|
| `explore` | 澄清问题与方案；默认不创建 change |
| `new` | 创建 change 与分支，开始逐步产出 artifacts |
| `ff` | 一次生成 apply 所需 artifacts |
| `continue` | 只推进下一个未完成 artifact |
| `grill` | 审查设计，可写 `review-notes.md` |
| `apply` | 按 artifacts 实现并记录完成证据 |
| `verify` | 对照规格给出 pass/fail 与剩余缺口，不归档 |
| `sync` | 将 delta 同步到 `.workflow/specs/` |
| `archive` | 校验、同步并归档 change；合并仍需单独授权 |
| `doctor` | 只读检查安装、schema、配对与漂移 |

本地 CLI 的机器接口位于 `.agents/skills/workflow/bin/workflow.ps1`，支持 `new`、`status`、`instructions`、`validate`、`sync`、`archive` 和 `doctor`。不得为运行本工作流安装或下载外部生命周期工具。

## 验证

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/tests/WorkflowDeploy.Tests.ps1
pwsh -NoProfile -File scripts/tests/WorkflowDeploy.Tests.ps1
```

- [架构](docs/architecture.md)
- [单一事实来源](docs/ssot.md)
- [升级边界](docs/BREAKING.md)
