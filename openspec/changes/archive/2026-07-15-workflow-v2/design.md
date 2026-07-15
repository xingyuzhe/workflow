## Context

v1 workflow 将 OpenSpec 与 Superpowers 整合成「双技能操作系统」。绿场 v2 只保留流程编排 + 质量门禁 + 规格 SSOT。**产品立场：不考虑与 v1 运行时兼容或双轨共存。**

约束：服务 Cursor；保留 OpenSpec CLI；Windows/PowerShell 一等；per-capability `spec.md`+`design.md` 由 schema 浅 fork + prompts/config 强制。

## Goals / Non-Goals

**Goals:**

- 真同构 pack + `workflow-spec` 浅 fork + 三硬门禁 + 短 prompt（含 branch/finish/grill）
- 破坏性 init：无条件清除工作流旧栈；覆盖 config.yaml
- doctor / version / manifest；state 分期（M3）
- M1 末源仓硬切到 v2

**Non-Goals:**

- v1 兼容 flag、双轨迁移脚本、legacy skill 参考树
- 重写 OpenSpec CLI；Superpowers 技能框架；默认 SDD
- v2.0 overlay-patch CI / GUI / Linux 一等脚本（可 v2.1）

## Decisions

### D1：真同构 pack

**决策**：源仓与目标均为 `.cursor/workflow/pack/`（prompts、gates、grill）；init 原样同步。

### D2：`workflow-spec` 浅 fork

**决策**：SSOT 在 `openspec/schemas/workflow-spec/`；从 `spec-driven` fork 改名；模板/instructions 写明配对与 SSOT。**不**改 artifact 图；**不**做 CLI 文件系统硬校验。配对执行靠 prompts + 被覆盖的 `openspec/config.yaml`。

### D3：三硬门禁内联 apply

**决策**：`pack/gates/{tdd,verify,debug}.md`；branch/finish 为短 prompt，非门禁。

### D4：state 分期

**决策**：M1–M2 若存在则读，缺文件不阻断；M3 起维护。权威始终为 `openspec status`。

### D5：破坏性清理（无兼容逃生）

**决策**：

- **无** `--keep-v1-skills`
- 删除 `.cursor/skills` 下工作流命名空间：`superpowers*`、`openspec*`、`grilling*`、`workflow*`（含版本化目录）
- 删除工作流拥有的入口后重装：`opsx-*` commands、`*superpowers*bootstrap*`、旧 workflow router 等匹配文件；再写入 v2 router/commands
- 整文件覆盖 `openspec/config.yaml` 为工作流模板
- 残留 v1 工作流 skills → **doctor 失败**

### D6：grilling = pack 短文件

**决策**：`pack/prompts/grill.md`；产出 `review-notes.md`。

### D7：PowerShell 一等

**决策**：正式入口 `scripts/init.ps1`、`scripts/doctor.ps1`（或等价）。bash 非 v2.0 必交付。

### D8：M1 末源仓硬切

**决策**：pack/schema/router 可部署后删除源仓 v1 skills 默认树；硬切前打/确认 tag `v1-final`（仅考古）。不留 `legacy/` 参考树。

### D9：无双轨迁移产品

**决策**：升级 = 跑破坏性 init + 短 BREAKING 说明。不维护迁移脚本套件。业务 `openspec/specs` 内容 init **不删**（那是业务规格，不是 v1 工作流运行时）。

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| 硬切/覆盖毁掉本地改过的 opsx 或 config | BREAKING 文档；git 可回滚 |
| M1 硬切前无 tag | checklist 强制 `v1-final` |
| 浅 fork 配对被跳过 | prompts + doctor 抽查配对文件 |
| 仅 PS | 声明 Windows-first |

## Migration Plan

1. Tag `v1-final`（考古）
2. 实现 M1 → 源仓硬切
3. 业务仓直接跑 v2 `init.ps1 -Yes`（接受破坏性替换）
4. 宣布 v1 不再演进

详设见 [docs/workflow-v2-redesign.md](../../docs/workflow-v2-redesign.md)。
