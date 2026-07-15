# Init 破坏性说明

`scripts/init.ps1 -Yes` 会替换目标项目中的**工作流运行时**，不是合并安装。

## 会做什么

- 删除 `.cursor/skills` 下命名空间：`superpowers*`、`openspec*`、`grilling*`、`workflow*`
- 删除并重装工作流入口：`opsx-*` 命令、已知旧工作流 rules 目录等
- 覆盖 `openspec/config.workflow.yaml`，并重生成合并产物 `openspec/config.yaml`
- **永不覆盖** `openspec/config.project.yaml`（项目私有 rules/schema）
- 首次升级：若尚无 `config.project.yaml` 但已有 `config.yaml`，会把现有 `config.yaml` **改名**为 `config.project.yaml` 再合并
- 安装 `.cursor/workflow/pack/`、`openspec/schemas/workflow-spec/`、router、version/manifest

## 不会做什么

- 不删除业务规格 `openspec/specs/**`
- 不删除命名空间之外的用户自有 skills / rules / commands
- 不覆盖 `openspec/config.project.yaml`
## 用法

```powershell
pwsh -File path\to\workflow\scripts\init.ps1 -Target . -Yes
```

若仍存在上述工作流 skill 残留，`doctor.ps1` 会失败。
