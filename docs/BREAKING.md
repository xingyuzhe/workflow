# Init 破坏性说明

`scripts/init.ps1 -Yes` 会替换目标项目中的**工作流运行时**，不是合并安装。

## 会做什么

- 删除 `.cursor/skills` 下命名空间：`superpowers*`、`openspec*`、`grilling*`、`workflow*`
- 删除并重装工作流入口：`opsx-*` 命令、已知旧工作流 rules 目录等
- 覆盖 `openspec/config.workflow.yaml`，并重生成合并产物 `openspec/config.yaml`
- **永不覆盖** `openspec/config.project.yaml`（项目私有 rules/schema）
- 首次升级：若尚无 `config.project.yaml` 但已有 `config.yaml`，会把现有 `config.yaml` **改名**为 `config.project.yaml` 再合并
- 安装 `.workflow/pack/`、`openspec/schemas/workflow-spec/`，并在 `.workflow/` 写唯一 version/manifest
- 从 `.workflow/mcp.json` 和 `.workflow/rules.json` 生成 Cursor/Codex 适配产物
- 安装 `.agents/skills/openspec-workflow/` 及其生成 references
- 更新 `AGENTS.md` 中标记的 workflow managed block；块外项目内容保持不变
- 只清理各客户端 `.workflow-managed.json` 记录的旧规则产物；不宽泛删除未受管文件
- 更新 `.codex/config.toml` 中标记的 MCP managed block；块外 TOML 保持不变

## 不会做什么

- 不删除业务规格 `openspec/specs/**`
- 不删除命名空间之外的用户自有 skills / rules / commands
- 不覆盖 `openspec/config.project.yaml`
- 不覆盖 `AGENTS.md` / `.codex/config.toml` 的 managed block 之外内容

`doctor.ps1` 默认不写文件；显式 `-Fix` 才修复生成产物。
## 用法

```powershell
pwsh -File path\to\workflow\scripts\init.ps1 -Target . -Yes
```

若仍存在上述工作流 skill 残留，`doctor.ps1` 会失败。
