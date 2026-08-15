# 5.0 升级边界

`scripts/init.ps1 -Yes` 会替换目标项目中 workflow-owned 的旧运行时，不提供旧命令或旧目录兼容层。

## 会做什么

- 安装 `.agents/skills/workflow/`，其中包含本地 CLI、references 和元数据。
- 生成 `/workflow:*` Cursor 入口与 Codex managed guidance。
- 安装 `.workflow/schemas/workflow-contract/` 和 workflow 默认配置。
- 保留 `.workflow/config.project.yaml`，重建 `.workflow/config.yaml`。
- 将旧生命周期目录中的 changes、specs 和项目配置迁入 `.workflow` 后删除旧运行时命名空间。
- 更新标记过的 AGENTS 与 Codex TOML managed block。
- 删除 workflow-owned 的旧方法 gates 和旧部署脚本。

## 不会做什么

- 不删除项目 changes、业务 specs 或私有配置。
- 不删除无关 skills、rules、commands。
- 不修改 managed block 之外的 `AGENTS.md` 与 `.codex/config.toml` 内容。
- 不安装、下载或调用外部生命周期 CLI/package。
- 不向下游复制源码专用 `.workflow/pack` 或 `.workflow/cli`。

```powershell
pwsh -File path\to\workflow\scripts\init.ps1 -Target . -Yes
```

升级后使用 `scripts/doctor.ps1` 检查源码部署，或使用 `.agents/skills/workflow/bin/workflow.ps1 doctor` 检查发布态运行时。
