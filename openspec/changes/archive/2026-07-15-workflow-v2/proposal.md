## Why

当前 workflow 是「OpenSpec + Superpowers 两套技能操作系统」的整合产物：技能发现靠 AI 自律、定制烧进 fork、部署复制整棵技能树。模型编码能力变强后，这套形态的 token 成本与维护成本过高，而真正有价值的是 **流程编排 + 质量门禁 + 规格 SSOT**。现在需要一代绿场产品：以 OpenSpec 为中心，把技能宇宙降成薄编排层。**不考虑与 v1 运行时并存或双轨兼容。**

## What Changes

- **BREAKING**：不部署 Superpowers/OpenSpec 技能树；质量能力改为 apply 内联门禁（TDD / verification / systematic-debugging）
- **BREAKING**：源仓与部署真同构为 `.cursor/workflow/pack/`；废除版本化 skill 目录与 bootstrap 双权威
- **BREAKING**：init **无条件**清除工作流命名空间下的旧 skills / 工作流入口文件；**无** `--keep-v1-skills`；整文件覆盖 `openspec/config.yaml`
- 新增自定义 schema **`workflow-spec`**（浅 fork；per-capability `spec.md`+`design.md`、SSOT 写在模板与 config）
- 新增极薄 router + `/opsx:*` 命令路由；branch/finish/grill 为 pack 短 prompt（非硬门禁）
- 新增 doctor / version&manifest；`state.json` 于 M3 起维护（权威仍为 `openspec status`）
- 部署脚本以 **PowerShell** 为一等（`init.ps1` / `doctor.ps1`）
- v1 仅作 git 考古（可选 tag `v1-final`）；**不**提供双轨迁移工具或兼容运行时

## Capabilities

### New Capabilities

- `workflow-runtime`: 命令入口、router、phase 状态、与 OpenSpec CLI 的编排契约
- `quality-gates`: TDD / verification / debugging 门禁（非独立技能框架）
- `schema-pack`: `workflow-spec`、artifact 规则、per-capability design 配对与 SSOT
- `design-review`: grilling 与 `review-notes.md`
- `deploy-kit`: init / doctor / version&manifest；破坏性替换工作流文件

### Modified Capabilities

（无既有 `openspec/specs/` 主规格；本变更为绿场首批能力。）

## Impact

- 重写本仓库 `.cursor/` 工作流相关布局与 `scripts/`（PS 取代 bash 作为正式入口）
- 业务项目：**重跑 v2 init 即接受破坏性替换**；旧 skill 路径与旧 config 不作保留承诺
- 依赖：OpenSpec CLI + Cursor rules/commands；不依赖 Superpowers
- 历史 redesign 文档仅考古，不驱动 v2 运行时
