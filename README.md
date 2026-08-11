# Workflow

面向 Cursor 与 Codex 的 OpenSpec 流程工具包：双客户端入口、自定义 schema、生命周期交付契约，以及基于证据的验收。

## 安装到项目

需要 `-Yes`（会覆盖工作流入口与 `openspec/config.workflow.yaml`，并重生成合并后的 `config.yaml`；**不**覆盖 `config.project.yaml`）。说明见 [docs/BREAKING.md](docs/BREAKING.md)。

```powershell
pwsh -File scripts/init.ps1 -Target D:\work\your-project -Yes
pwsh -File scripts/doctor.ps1 -ProjectRoot D:\work\your-project
```

也支持 Git Bash 风格路径（会规范成 Windows 路径），例如 `-Target /d/work/your-project` → `D:\work\your-project`。

## 目录要点

| 路径 | 作用 |
|------|------|
| `.workflow/pack/` | 平台无关 prompts + gates（唯一 SSOT） |
| `.workflow/mcp.json` | 平台无关 MCP 定义，生成 Cursor/Codex 配置 |
| `.workflow/rules.json` · `.workflow/rules/` | 项目规则元数据与正文 SSOT |
| `.workflow/version.json` · `manifest.json` · `state.json` | 单一元数据与状态权威 |
| `openspec/schemas/workflow-spec/` | 默认 schema |
| `openspec/config.workflow.yaml` | 工作流 schema 选择器（init 可覆盖） |
| `openspec/config.project.yaml` | 项目私有规则（init **永不**覆盖） |
| `openspec/config.yaml` | 合并产物（`init` 或 `doctor -Fix` 生成，勿手改） |
| `.cursor/rules/workflow-router.mdc` | 唯一 alwaysApply 路由 |
| `.cursor/commands/opsx-*.md` | Cursor 命令 |
| `AGENTS.md` 的 workflow managed block | Codex 持久路由；保留块外项目内容 |
| `.agents/skills/openspec-workflow/` | Codex workflow skill 与按需 references |
| `.cursor/rules/` · `.agents/rules/` | 从中立规则源生成的客户端适配产物 |
| `.cursor/mcp.json` · `.codex/config.toml` managed block | 从中立 MCP 源生成的客户端适配产物 |
| `scripts/init.ps1` · `doctor.ps1` | 部署与健康检查 |

## 命令怎么用

在 Cursor 里输入 `/opsx:…`，或在 Codex 里使用 `$openspec-workflow`、旧命令别名及同等自然语言意图。两端均由 `.workflow/` 的中立源确定性生成。

### 推荐次序（一条变更）

```text
explore（可选）
    → new  或  ff
    → continue（缺啥补啥，可多次）
    → grill（可选）
    → apply
    → verify
    → sync（若要把 delta 合进主规格；也可留给 archive）
    → archive
```

旁路：随时 `/opsx:doctor` 做健康检查。仅活跃 OpenSpec 操作中的失败继续由该操作契约处理；普通 bug 和测试失败不自动进入 OpenSpec 工作流。

| 命令 | 作用 | 怎么用 |
|------|------|--------|
| `/opsx:explore` | 想清楚问题与方案，**默认不写代码、不建 change** | 有模糊需求时先用；结束后再 `new`/`ff` |
| `/opsx:new` | 新建 change，按 schema 逐步写 proposal → … | 已知要开变更；会建分支 `change/<name>` |
| `/opsx:ff` | 一口气写齐 apply 所需产物 | 目标清晰、想少来回时用；写完再决定 grill 或 apply |
| `/opsx:continue` | 只推进**下一个**未完成产物 | `new`/`ff` 中断后续用；可反复调用 |
| `/opsx:grill` | 审查设计并记录 `review-notes.md` | 设计争议大时用；**默认不阻断** apply |
| `/opsx:apply` | 按 artifacts 实现并提供完成证据 | 产物齐套后使用；具体方法由 agent 按项目规则与风险选择 |
| `/opsx:verify` | 对照规格检查实现，**不归档** | apply 告一段落后用；给出 pass/fail 与缺口 |
| `/opsx:sync` | 把 change 里的 delta 同步到 `openspec/specs/`（必须 `spec.md`+`design.md`） | 需要主库先更新、或 archive 前补配对时用 |
| `/opsx:archive` | 归档 change，并确保主规格成对；然后询问 merge/PR/保留/丢弃 | verify 通过（或你接受残留）后收尾 |
| `/opsx:doctor` | 跑 `scripts/doctor.ps1`：布局、schema、配对、残留技能等 | 安装后、同步/归档后、或怀疑部署损坏时 |

Doctor 默认只读；使用 `scripts/doctor.ps1 -Fix` 才会重新生成 workflow-owned 产物，然后再次严格检查。

说明：

- **`new` vs `ff`**：要分步讨论选 `new`+`continue`；要一次齐套选 `ff`。
- **`sync` vs `archive`**：`archive` 常会顺带更新主规格；若 CLI 只写出了 `spec.md`，仍须按 sync/archive prompt **补 `design.md`**，且 doctor 会查配对。
- 自然语言「开始写代码 / 实现吧」通常等价于 **apply**（见 router）。
- Shared workflow 不规定 TDD、调试步骤、测试频率或重试次数；项目如需这些方法，应在项目规则中按适用范围声明。

## 测试

```powershell
powershell -NoProfile -File scripts/tests/WorkflowDeploy.Tests.ps1
```

## 文档

- [docs/architecture.md](docs/architecture.md) — 架构与运行时契约  
- [docs/ssot.md](docs/ssot.md) — 产物单一事实来源  
- [docs/BREAKING.md](docs/BREAKING.md) — init 破坏性说明  
