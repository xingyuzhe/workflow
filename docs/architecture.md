# Workflow — 架构与现状

本仓库是给 Cursor 用的 **OpenSpec 流程产品**：命令驱动、自定义 schema、短 prompt 包，以及 apply 阶段的三条质量门禁。源仓布局与部署到目标项目后的布局相同。

当前版本：`2.0.0`（见 `.cursor/workflow/version.json`）。

---

## 定位

- **是**：OpenSpec 变更生命周期编排 + Cursor `/opsx:*` 入口 + 质量门禁
- **不是**：可发现的 Agent「技能操作系统」；不部署技能目录树作为运行时

---

## 架构

```
/opsx:* 命令  +  workflow-router.mdc（唯一 alwaysApply）
        │
        ▼
.cursor/workflow/pack/
  prompts/   ← 各阶段短提示
  gates/     ← tdd · verify · debug（仅 apply 强制）
        │
        ▼
OpenSpec CLI  +  openspec/schemas/workflow-spec
        │
        ▼
version.json · manifest.json · state.json（本地辅助）
doctor.ps1
```

---

## 仓库布局（源 = 部署）

```
workflow/
├── openspec/
│   ├── schemas/workflow-spec/     # 项目级 schema（浅 fork spec-driven）
│   ├── config.workflow.yaml       # 工作流模板（init 可覆盖）
│   ├── config.project.yaml        # 项目私有（init 永不覆盖）
│   ├── config.yaml                # 合并产物（CLI 只读；自动重生成）
│   ├── specs/                     # 本产品自身的主规格
│   └── changes/                   # 变更与 archive
├── .cursor/
│   ├── workflow/
│   │   ├── pack/prompts/          # explore new ff continue grill apply …
│   │   ├── pack/gates/            # tdd verify debug
│   │   ├── version.json
│   │   ├── manifest.json
│   │   └── state.json             # gitignore；权威仍是 openspec status
│   ├── rules/workflow-router.mdc
│   └── commands/opsx-*.md
├── scripts/
│   ├── init.ps1
│   ├── doctor.ps1
│   ├── lib/WorkflowDeploy.psm1
│   └── tests/WorkflowDeploy.Tests.ps1
└── docs/
    ├── architecture.md            # 本文
    ├── ssot.md
    └── BREAKING.md                # init 破坏性说明
```

---

## 运行时契约

### 命令 → prompt

| 命令 | 加载 |
|------|------|
| `/opsx:explore` | `pack/prompts/explore.md` |
| `/opsx:new` | `new.md` + `branch.md` |
| `/opsx:ff` | `ff.md` + `branch.md` |
| `/opsx:continue` | `continue.md` |
| `/opsx:grill` | `grill.md` |
| `/opsx:apply` | `apply.md` + `gates/*` |
| `/opsx:verify` | `verify.md` |
| `/opsx:sync` | `sync.md` |
| `/opsx:archive` | `archive.md` + `finish.md` |
| `/opsx:doctor` | `doctor.md` |

意图路由见 `workflow-router.mdc`（例如「start coding」→ apply）。

### 质量门禁

仅在 **apply** 强制：

1. **TDD** — 逻辑改动 RED→GREEN→REFACTOR；文档/配置等可豁免；不确定则询问  
2. **Verify** — 勾选 task 前必须有运行证据  
3. **Debug** — 失败时复现→假设→最小验证→再改；连续 3 次失败则暂停  

`branch` / `finish` / `grill` 是短 prompt，**不是**与上述同级的硬门禁。

### Schema 与产物

- 默认 schema 名：`workflow-spec`（`openspec/schemas/workflow-spec/`）
- 每个 capability：同批产出 `spec.md` + `design.md`（靠 schema 模板说明 + 合并后的 `config.yaml` rules + prompts；非 CLI 文件系统硬校验）
- Artifact 归属见 [ssot.md](ssot.md)

### 状态文件

`.cursor/workflow/state.json`（可选维护）：`active_change`、`phase`、`branch`、`updated_at`。  
与 `openspec status` 冲突时以 **CLI 为准**；缺失不阻断 apply。

---

## 部署

入口：PowerShell（`scripts/init.ps1` / `doctor.ps1`）。

```powershell
pwsh -File scripts/init.ps1 -Target path\to\project -Yes
pwsh -File scripts/doctor.ps1 -ProjectRoot path\to\project
```

`init -Yes` 会：

1. 清除目标项目中工作流命名空间下的 `.cursor/skills`（`superpowers*` / `openspec*` / `grilling*` / `workflow*`）
2. 删除并重装工作流入口（`opsx-*`、旧工作流 rules 目录等）
3. 同步 pack、router、commands、`workflow-spec` schema
4. 覆盖 `openspec/config.workflow.yaml`；迁移/保留 `config.project.yaml`；合并生成 `config.yaml`
5. 写入 version / manifest，并跑 doctor（失败则非零退出）

**不会删除**业务规格 `openspec/specs/**`，也**不会覆盖** `config.project.yaml`。  
破坏性细节见 [BREAKING.md](BREAKING.md)。

### 配置隔离

| 文件 | 归属 | 升级时 |
|------|------|--------|
| `config.workflow.yaml` | workflow | 可覆盖 |
| `config.project.yaml` | 本项目 | 永不覆盖 |
| `config.yaml` | 合并产物 | `doctor`/`init` 自动重生成 |

rules 按 artifact 键拼接（workflow 在前、project 在后、去重保序）；`schema` 等标量以 workflow 为基，project 显式提供则覆盖。

本仓自举：源路径与目标路径相同时，不会先删后拷毁掉现有 pack。

---

## 健康检查

Doctor 校验：manifest 所列文件、router、schema 文件、**`openspec schema which workflow-spec` 解析到项目本地**、工作流 skill 命名空间不得残留，以及 **`openspec/specs`（与未归档 change 的 `specs/`）下每个 capability 必须 `spec.md`+`design.md` 成对**。

---

## 非目标

- 重写 OpenSpec CLI  
- 以技能目录树作为默认运行时  
- 默认多 Agent SDD  
- GUI、overlay patch CI  
- Linux/bash 作为一等部署入口（当前以 PowerShell 为准）
