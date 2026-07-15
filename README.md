# Workflow

面向 Cursor 的 OpenSpec 流程工具包：命令入口、自定义 schema、`pack` 短提示，以及 apply 时的三条质量门禁。

## 安装到项目

需要 `-Yes`（会覆盖工作流相关文件与 `openspec/config.yaml`）。说明见 [docs/BREAKING.md](docs/BREAKING.md)。

```powershell
pwsh -File scripts/init.ps1 -Target path\to\project -Yes
pwsh -File scripts/doctor.ps1 -ProjectRoot path\to\project
```

## 目录要点

| 路径 | 作用 |
|------|------|
| `.cursor/workflow/pack/` | prompts + gates（源仓与部署同构） |
| `openspec/schemas/workflow-spec/` | 默认 schema |
| `.cursor/rules/workflow-router.mdc` | 唯一 alwaysApply 路由 |
| `.cursor/commands/opsx-*.md` | Cursor 命令 |
| `scripts/init.ps1` · `doctor.ps1` | 部署与健康检查 |

## 命令

`/opsx:explore` · `/opsx:new` · `/opsx:ff` · `/opsx:continue` · `/opsx:grill` · `/opsx:apply` · `/opsx:verify` · `/opsx:sync` · `/opsx:archive` · `/opsx:doctor`

## 测试

```powershell
powershell -NoProfile -File scripts/tests/WorkflowDeploy.Tests.ps1
```

## 文档

- [docs/architecture.md](docs/architecture.md) — 架构与运行时契约  
- [docs/ssot.md](docs/ssot.md) — 产物单一事实来源  
- [docs/BREAKING.md](docs/BREAKING.md) — init 破坏性说明  
