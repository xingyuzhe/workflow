# Workflow

面向 Cursor 的 OpenSpec 流程工具包：命令入口、自定义 schema、`pack` 短提示，以及 apply 时的三条质量门禁。

## 安装到项目

需要 `-Yes`（会覆盖工作流相关文件与 `openspec/config.yaml`）。说明见 [docs/BREAKING.md](docs/BREAKING.md)。

```powershell
pwsh -File scripts/init.ps1 -Target D:\work\your-project -Yes
pwsh -File scripts/doctor.ps1 -ProjectRoot D:\work\your-project
```

也支持 Git Bash 风格路径（会规范成 Windows 路径），例如 `-Target /d/work/your-project` → `D:\work\your-project`。

## 目录要点

| 路径 | 作用 |
|------|------|
| `.cursor/workflow/pack/` | prompts + gates（源仓与部署同构） |
| `openspec/schemas/workflow-spec/` | 默认 schema |
| `.cursor/rules/workflow-router.mdc` | 唯一 alwaysApply 路由 |
| `.cursor/commands/opsx-*.md` | Cursor 命令 |
| `scripts/init.ps1` · `doctor.ps1` | 部署与健康检查 |

## 命令怎么用

在 Cursor 里输入 `/opsx:…`（或说同等意图，由 router 映射到同一 prompt）。命令会要求 agent **先读** `.cursor/workflow/pack/prompts/` 下对应文件再行动。

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

旁路：随时 `/opsx:doctor` 做健康检查。实现中遇测试/报错走 debug 门禁（router 也会映射「修 bug」类意图）。

| 命令 | 作用 | 怎么用 |
|------|------|--------|
| `/opsx:explore` | 想清楚问题与方案，**默认不写代码、不建 change** | 有模糊需求时先用；结束后再 `new`/`ff` |
| `/opsx:new` | 新建 change，按 schema 逐步写 proposal → … | 已知要开变更；会建分支 `change/<name>` |
| `/opsx:ff` | 一口气写齐 apply 所需产物 | 目标清晰、想少来回时用；写完再决定 grill 或 apply |
| `/opsx:continue` | 只推进**下一个**未完成产物 | `new`/`ff` 中断后续用；可反复调用 |
| `/opsx:grill` | 压测设计（一问一答），写 `review-notes.md` | 设计争议大时用；**默认不阻断** apply |
| `/opsx:apply` | 按 `tasks.md` 实现；强制 TDD/verify/debug 门禁 | 产物齐套后开干；勾选任务前要有运行证据 |
| `/opsx:verify` | 对照规格检查实现，**不归档** | apply 告一段落后用；给出 pass/fail 与缺口 |
| `/opsx:sync` | 把 change 里的 delta 同步到 `openspec/specs/`（必须 `spec.md`+`design.md`） | 需要主库先更新、或 archive 前补配对时用 |
| `/opsx:archive` | 归档 change，并确保主规格成对；然后询问 merge/PR/保留/丢弃 | verify 通过（或你接受残留）后收尾 |
| `/opsx:doctor` | 跑 `scripts/doctor.ps1`：布局、schema、配对、残留技能等 | 安装后、同步/归档后、或怀疑部署损坏时 |

说明：

- **`new` vs `ff`**：要分步讨论选 `new`+`continue`；要一次齐套选 `ff`。
- **`sync` vs `archive`**：`archive` 常会顺带更新主规格；若 CLI 只写出了 `spec.md`，仍须按 sync/archive prompt **补 `design.md`**，且 doctor 会查配对。
- 自然语言「开始写代码 / 实现吧」通常等价于 **apply**（见 router）。

## 测试

```powershell
powershell -NoProfile -File scripts/tests/WorkflowDeploy.Tests.ps1
```

## 文档

- [docs/architecture.md](docs/architecture.md) — 架构与运行时契约  
- [docs/ssot.md](docs/ssot.md) — 产物单一事实来源  
- [docs/BREAKING.md](docs/BREAKING.md) — init 破坏性说明  
