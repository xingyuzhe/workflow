# Workflow 重新设计方案 (Composer)

> 基于对当前 openspec-v1.5.0 + superpowers-v6.1.1 + grilling 整合工作流的独立审查，以及与 deepseek / GLM 方案的交叉对比。本文提出以**阶段状态机 + 声明式定制 + 可观测性**为核心的差异化重设计。

---

## 一、当前设计的核心不足

以下问题按**对实际使用的影响**排序，前 5 项为结构性缺陷，后 5 项为工程化缺口。

### 1.1 流程是「隐式管道」，没有阶段状态

当前工作流在文档里画出了清晰的管道（explore → design → grill → apply → verify → archive），但**运行时没有任何持久化状态**告诉 AI「现在处于哪一阶段」。

AI 只能依赖：
- 对话上下文（易丢失）
- `openspec/changes/<name>/` 目录里有哪些 artifact（间接推断）
- bootstrap 路由表（按用户**本轮输入**匹配，不是按**变更进度**匹配）

**后果**：
- 用户说「继续」时，AI 可能在 `continue-change` 和 `apply-change` 之间猜错
- 设计未完成就进入实现，或 artifacts 已齐全却还在 explore
- 跨会话续接完全靠用户复述上下文

### 1.2 定制逻辑「烧进」制品，升级上游成本高

整合改造（删除 brainstorming、注入 branching-strategy、apply-change 质量集成等）是直接修改 `.cursor/skills/` 下的 SKILL.md 副本。

这意味着：
- 上游发新版 → 需要人工 diff 每个定制点
- workflow 仓库同时保留 v1.2.0 / v1.5.0、v4.3.1 / v6.1.1 四套目录，**测试 fixtures 仍停留在旧版本**
- 定制与上游的边界不清晰，无法自动验证「patches 是否仍适用」

**本质问题**：定制应该是**叠加层（overlay）**，而不是**分叉副本（fork）**。

### 1.3 bootstrap 承担过多职责，且每轮全量注入

`superpowers-bootstrap.mdc`（154 行，`alwaysApply: true`）同时承担：

| 职责 | 每轮是否需要 |
|------|-------------|
| 路径解析 | 是 |
| 24 个技能清单 | 部分（仅需索引） |
| 1% 规则 + Red Flags | 是（精简版） |
| OpenSpec Priority 路由表 | 是 |
| Tool Mapping | 否（技能内按需） |
| Skill Types / Platform / User Instructions | 否（按需） |

deepseek 和 GLM 都主张瘦身，但分歧在「Red Flags 留多少」。更深层的问题是：**bootstrap 是唯一的编排权威**，却没有机器可读的编排定义与之对应。

### 1.4 实施路径有三条入口，用户/AI 容易迷路

| 路径 | 触发场景 | 问题 |
|------|---------|------|
| `openspec-apply-change` | `/opsx:apply`、用户说「开始实现」 | 主路径，但步骤最多（含 grilling、expand tasks、TDD 等） |
| `executing-plans` | 已有 `docs/plans/` 下的计划文件 | 与 apply-change 的 Completion Sequence 有交叉引用 |
| `subagent-driven-development` | 大计划、多任务并行 | 依赖 bash 脚本，Windows 降级不明确 |

三者之间的**选择决策树**只散落在各 skill 的 Integration 段，bootstrap 路由表只写 `executing-plans or subagent-driven-development*`，没有帮助 AI 判断「当前应该用哪条」。

### 1.5 已知 bug 与不一致尚未修复

GLM 方案已验证的问题，当前代码仍存在：

1. **apply-change Step 3 引用尚未存在的 `contextFiles`**（Step 5 才返回）
2. **AskUserQuestion vs AskQuestion** 工具名不统一（openspec 用前者，branching-strategy 用后者）
3. **using-superpowers 磁盘存在但 bootstrap 声称已内嵌**，形成双权威风险
4. **grilling 仅挂在 apply-change**，设计阶段出口（new/ff/continue）无轻量提醒
5. **路径硬编码版本号**（`superpowers-v6.1.1`），与「部署后扁平化」方向矛盾

### 1.6 缺少部署后可观测性与自检

- 无 `.cursor/.workflow-version` 或等价物，用户报问题时无法快速定位版本
- 无 `workflow doctor` 自检：openspec CLI、git 状态、技能文件完整性、平台兼容性
- init.sh 全程 `read -p` 交互，**无法在 CI / 脚本化部署中使用**

### 1.7 grilling 过于轻量，与管道定位不匹配

grilling 仅 13 行，是整个「设计审查」阶段的唯一技能，但：
- 无结构化输出（审查结论、待决事项、风险清单）
- 不与 OpenSpec artifact 格式绑定（proposal/design/specs 各审什么）
- 无 `recommends` 回写机制（审查后哪些 artifact 需要更新）

作为 explore 与 apply 之间的**质量关卡**，它目前更像一个对话风格提示，而非可审计的审查流程。

### 1.8 技能发现依赖 AI 自律，无结构约束

`using-git-worktrees` 设计为 internal，但路径解析把它和 `branching-strategy` 放在同一命名空间，仅靠 bootstrap 一行注释阻止直接调用。

frontmatter 扩展（phase/triggers/requires）是好方向，但：
- 上游 skill 没有这些字段
- 无部署时校验「requires 引用的技能是否存在」
- 无环检测（A requires B requires A）

### 1.9 Windows 适配是「希望 AI 自己翻译」

bootstrap 声明 `Bash → Shell`，但 SDD 三个脚本、`find`、`read -p` 等仍是 Unix 假设。当前策略是把适配责任推给 AI 运行时理解，**不可靠**。

### 1.10 测试与制品版本脱节

`test/fixtures/` 基于 superpowers-v4.3.1 + openspec-v1.2.0，当前部署版本是 v6.1.1 + v1.5.0。定制回归测试无法覆盖现行制品。

---

## 二、与已有方案的异同

| 维度 | DeepSeek | GLM | Composer（本文） |
|------|----------|-----|-----------------|
| 核心哲学 | trust the structure | 务实修复 + 结构优化 | **phase-aware + patch-based + observable** |
| bootstrap | ~40 行，Red Flags 外移 | ~60 行，保留精简 Red Flags | **拆成 router（~35 行）+ constitution（按需加载）** |
| 版本管理 | 符号链接 | versions.conf + 无版本号目录 | versions.conf + **部署时生成 skill-index.json** |
| 命令层 | 空占位注释 | 路由声明式 | **路由声明 + 指向 manifest 中的 phase** |
| 定制维护 | apply-customizations.sh | 同左 | **overlay patches（kustomize 模型）+ patch 适用性测试** |
| grilling | 仅 apply-change | 三入口 + 时序修复 | **结构化审查协议 + artifact 绑定 + 审查纪要输出** |
| 阶段感知 | 无 | 无 | **`.cursor/workflow/state.json` 阶段状态** |
| 可观测性 | 无 | .workflow-version | **version + manifest + doctor 命令** |
| 实施路径 | 未专门处理 | SDD 降级提示 | **显式决策树 skill：`implementation-mode`** |

---

## 三、重设计核心原则

### 3.1 三条设计原则

```
1. Phase-first     — 先知道「在哪」，再决定「做什么」
2. Overlay-not-fork — 上游 skill 保持原样，定制用 patches 叠加
3. Fail-visible    — 缺 CLI、缺文件、平台不兼容，部署时和运行时都要能发现
```

### 3.2 架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                     Cursor Session                          │
├─────────────────────────────────────────────────────────────┤
│  superpowers-router.mdc (~35 lines, alwaysApply)            │
│    → 读 .cursor/workflow/manifest.json（技能图 + 阶段定义）    │
│    → 读 .cursor/workflow/state.json（当前 change + phase）    │
│    → 路由到对应 skill                                       │
├─────────────────────────────────────────────────────────────┤
│  Skills (deployed, no version in path)                      │
│    superpowers/{skill}/SKILL.md   ← upstream + patches      │
│    openspec/{skill}/SKILL.md      ← upstream + patches      │
│    grilling/SKILL.md              ← workflow-native           │
│    workflow/{doctor,implementation-mode}/SKILL.md ← 新增    │
├─────────────────────────────────────────────────────────────┤
│  OpenSpec CLI + openspec/changes/<name>/artifacts           │
└─────────────────────────────────────────────────────────────┘
```

---

## 四、重新设计方案

### 4.1 目录结构

**workflow 源仓库：**

```
workflow/
├── versions.conf                      # 单一版本权威
├── manifest.template.json             # 技能图、阶段定义、路由表模板
├── patches/                           # 定制 overlay（不修改上游副本）
│   ├── openspec/
│   │   ├── openspec-apply-change.patch.yaml
│   │   ├── openspec-new-change.patch.yaml
│   │   └── ...
│   └── superpowers/
│       ├── delete-brainstorming.yaml
│       └── add-branching-strategy.yaml
├── upstream/                          # 纯净上游（git submodule 或 vendor）
│   ├── openspec-v1.5.0/
│   └── superpowers-v6.1.1/
├── scripts/
│   ├── init.sh                        # 支持 --yes 非交互
│   ├── build-skills.sh                # upstream + patches → 部署制品
│   └── workflow-doctor.sh
└── test/
    ├── patch-apply.test.sh            # patches 能否应用到新版上游
    └── deploy-integration.test.sh
```

**部署到目标项目后：**

```
target-project/
├── .cursor/
│   ├── commands/
│   │   └── opsx-*.md                  # 路由声明式
│   ├── rules/
│   │   └── superpowers-router.mdc     # 瘦身路由（非 constitution）
│   ├── skills/
│   │   ├── superpowers/               # 无版本号
│   │   ├── openspec/
│   │   ├── grilling/
│   │   └── workflow/                  # doctor, implementation-mode
│   └── workflow/
│       ├── manifest.json              # 技能图、阶段、路由（部署时生成）
│       ├── state.json                 # 运行时阶段状态（AI 读写）
│       └── version.json               # 部署元数据
└── openspec/
```

### 4.2 manifest.json：机器可读的编排定义

部署时由 `build-skills.sh` 从模板 + 实际 skill frontmatter 生成：

```json
{
  "workflow_version": "2026.07.10+abc1234",
  "superpowers_version": "v6.1.1",
  "openspec_version": "v1.5.0",
  "phases": ["explore", "design", "review", "implement", "verify", "archive"],
  "skills": {
    "openspec-explore": {
      "phase": "explore",
      "path": ".cursor/skills/openspec/openspec-explore/SKILL.md",
      "triggers": ["explore", "how to", "compare", "/opsx:explore"],
      "next": ["openspec-new-change", "openspec-ff-change"]
    },
    "grilling": {
      "phase": "review",
      "path": ".cursor/skills/grilling/SKILL.md",
      "triggers": ["grill", "stress-test", "review design"],
      "requires_artifacts": ["proposal", "design", "specs"],
      "outputs": ["review-notes.md"],
      "optional": true
    },
    "openspec-apply-change": {
      "phase": "implement",
      "requires": ["branching-strategy"],
      "recommends": ["grilling", "writing-plans"]
    }
  },
  "implementation_modes": {
    "single_session": "openspec-apply-change",
    "plan_file": "executing-plans",
    "parallel_tasks": "subagent-driven-development",
    "platform_fallback": {
      "windows_no_git_bash": "executing-plans"
    }
  }
}
```

**价值**：
- bootstrap 只需说「读 manifest 路由」，不必硬编码 24 个技能
- 可用脚本校验 requires 引用完整性、环检测
- 为未来的 UI（阶段进度条）提供数据基础

### 4.3 state.json：跨会话阶段续接

```json
{
  "active_change": "add-user-auth",
  "phase": "design",
  "branch": "change/add-user-auth",
  "artifacts_complete": ["proposal"],
  "artifacts_pending": ["design", "specs", "tasks"],
  "last_skill": "openspec-continue-change",
  "updated_at": "2026-07-10T09:30:00+08:00",
  "pending_decisions": [
    "OAuth provider: GitHub vs Google"
  ]
}
```

**规则**（写入 router）：
- 进入任何 OpenSpec skill 时，AI 先读 `state.json`，再读 `openspec status --json`，两者不一致时以 CLI 为准并更新 state
- 退出 skill 时更新 `phase` 和 `last_skill`
- `openspec-explore` 的「仍待确认（关键）」列表同步写入 `pending_decisions`

这是与 deepseek/GLM 方案的**最大差异**：不只是瘦身 bootstrap，而是给 AI 一个**可持久化的流程锚点**。

### 4.4 bootstrap 拆分：router + constitution

**superpowers-router.mdc（~35 行，alwaysApply）**

```markdown
# Workflow Router

<SUBAGENT-STOP>...</SUBAGENT-STOP>

**Boot sequence** (every message):
1. Read `.cursor/workflow/manifest.json` if exists
2. Read `.cursor/workflow/state.json` if exists
3. If 1% chance a skill applies → load it BEFORE responding

**Skill paths** (try in order):
1. `.cursor/skills/superpowers/{name}/SKILL.md`
2. `.cursor/skills/openspec/{name}/SKILL.md`
3. `.cursor/skills/grilling/{name}/SKILL.md`
4. `.cursor/skills/workflow/{name}/SKILL.md`

**Phase-aware routing** (when `openspec/` exists):
| state.phase / user intent | Load |
|---------------------------|------|
| explore / 怎么想 | openspec-explore |
| design / 新功能 | openspec-new-change or ff-change |
| review / grill | grilling |
| implement / 开始写代码 | openspec-apply-change |
| verify / 检查完成度 | openspec-verify-change |
| archive / 收尾 | openspec-archive-change |
| fix / debug | systematic-debugging |

**Internal** (do NOT call directly): using-git-worktrees

**Top 5 rationalization traps**: [精简表，5 行]

**Constitution** (load only when skill-check needs detail):
→ `.cursor/skills/workflow/constitution/SKILL.md`
```

**workflow/constitution/SKILL.md（按需加载）**
- 完整 Red Flags 表
- Skill Types（Rigid vs Flexible）
- Platform Adaptation 细则
- User Instructions 优先级
- TDD 灰区处理规则

这样每轮固定注入从 154 行降到 ~35 行，但纪律性内容不丢失，只是改为按需加载。

### 4.5 overlay patches 替代 fork 副本

定制不再直接改 `.cursor/skills/openspec-v1.5.0/`，而是：

```yaml
# patches/openspec/openspec-apply-change.patch.yaml
target: openspec-apply-change/SKILL.md
operations:
  - action: insert_after
    anchor: "**Steps**"
    content: |
      0. **Read workflow state**
         - Load `.cursor/workflow/state.json`
         - Confirm `active_change` matches selected change
  - action: insert_after
    anchor: "2. **Ensure isolated workspace"
    # ... branching-strategy injection
  - action: replace
    from: "from `contextFiles`"
    to: "from `openspec status --change <name> --json` artifact paths, or run Step 5 first if needed"
```

`build-skills.sh` 流程：
```
upstream → 应用 patches → 校验（skill 存在、anchor 可匹配）→ 输出到 staging → init.sh 部署
```

**升级上游时**：只需重跑 patch 测试，失败则人工调整 anchor。

### 4.6 grilling 升级为结构化审查协议

将 grilling 从 13 行扩展到 ~80 行，但保持「一次一问」风格：

```markdown
## Inputs
- Required: proposal.md, design.md, specs/
- Optional: tasks.md (if exists, review scope only)

## Outputs
- Write `openspec/changes/<name>/review-notes.md`:
  - Confirmed decisions
  - Open questions (with recommended answers)
  - Risks (severity: high/medium/low)
  - Artifact updates needed (if any)

## Protocol
1. Read artifacts from change directory (NOT contextFiles)
2. Walk design tree: one question per decision point
3. Look up codebase facts; ask user only for decisions
4. After each section, summarize alignment gap
5. Do NOT proceed to implementation until user confirms shared understanding
6. Update state.json: phase → "review", pending_decisions → [...]
```

审查入口挂载点（同意 GLM 方案，并增加 state 更新）：
- `new-change` / `ff-change` / `continue-change` 末尾：轻量提示
- `apply-change` Step 3：正式提供（修复 contextFiles 时序）

### 4.7 新增 implementation-mode 决策技能

解决「三条实施路径」混乱：

```markdown
# implementation-mode

When user wants to implement, BEFORE choosing a skill:

1. Check state.json phase — must be >= design complete
2. Ask (single question):
   - A) Follow OpenSpec tasks directly (default, most changes)
   - B) Execute existing plan files in docs/plans/
   - C) Parallel subagent per task (large changes, requires Git Bash)

3. Route:
   A → openspec-apply-change
   B → executing-plans
   C → subagent-driven-development (or B on Windows without Git Bash)
```

在 manifest 的 `implementation_modes` 中声明平台降级，AI 不需要每次重新推理。

### 4.8 workflow-doctor：部署时 + 故障时自检

新增 `workflow-doctor` skill + `scripts/workflow-doctor.sh`：

| 检查项 | 失败时建议 |
|--------|-----------|
| openspec CLI 可用 | `npm i -g @fission-ai/openspec` |
| manifest.json 存在且合法 | 重新运行 init.sh |
| skills 目录完整（与 manifest 一致） | 重新部署 |
| git 仓库初始化 | 提示 git init |
| 平台：Git Bash 可用性 | 建议 executing-plans 替代 SDD |
| state.json 与 openspec status 一致性 | 自动修复或提示 |

init.sh 末尾自动运行 doctor；用户遇到异常时可用 `/opsx:doctor`。

### 4.9 init.sh 改进清单

1. 读取 `versions.conf`，消除硬编码
2. 新增 `--yes` / `--non-interactive` 跳过所有 `read -p`
3. 调用 `build-skills.sh` 生成制品（非直接复制 fork 副本）
4. 部署目录名**不带版本号**（`superpowers/`、`openspec/`）
5. 写入 `.cursor/workflow/version.json` + `manifest.json`
6. 初始化空的 `state.json`
7. 可选 `--exclude=writing-skills`（目标项目不需要元技能）
8. 部署后自动运行 `workflow-doctor.sh`

### 4.10 命令文件：路由声明 + 阶段提示

```markdown
---
name: /opsx-apply
id: opsx-apply
category: Workflow
description: Implement tasks from an OpenSpec change
---

Skill: openspec-apply-change
Path: .cursor/skills/openspec/openspec-apply-change/SKILL.md
Phase: implement
Prerequisite: design artifacts complete (proposal, specs, tasks)

Read state: .cursor/workflow/state.json
```

即使 bootstrap 规则被用户误删，命令文件仍能引导 AI 到正确 skill 并提示前置条件。

---

## 五、迁移路径

### Phase 0：零结构改动（1-2 天，立即收益）

| # | 改动 | 风险 |
|---|------|------|
| 1 | 修复 apply-change Step 3 contextFiles 时序 | 极低 |
| 2 | 统一 AskUserQuestion →「向用户提问确认」 | 极低 |
| 3 | new/ff/continue 末尾加 grilling 轻量提示 | 极低 |
| 4 | init.sh 写 version.json | 极低 |
| 5 | init.sh 加 --yes 非交互模式 | 低 |
| 6 | 删除或移走 using-superpowers（避免双权威） | 低 |

### Phase 1：manifest + router 拆分（3-5 天）

| # | 改动 | 风险 |
|---|------|------|
| 7 | 引入 manifest.template.json + 部署时生成 | 低 |
| 8 | bootstrap 拆为 router + constitution | 中（需验证 AI 会按需加载 constitution） |
| 9 | 部署目录去掉版本号 + versions.conf | 低 |
| 10 | 命令文件改路由声明式 | 极低 |

### Phase 2：patches + 状态机（1-2 周）

| # | 改动 | 风险 |
|---|------|------|
| 11 | 现有定制提取为 patches/ | 中 |
| 12 | build-skills.sh + patch 测试 | 中 |
| 13 | state.json 读写协议写入各 OpenSpec skill | 中 |
| 14 | grilling 结构化升级 + review-notes 输出 | 低 |
| 15 | implementation-mode 技能 | 低 |
| 16 | workflow-doctor | 低 |

### Phase 3：测试与观测（持续）

| # | 改动 | 风险 |
|---|------|------|
| 17 | 测试 fixtures 升级到 v6.1.1 + v1.5.0 | 低 |
| 18 | deploy-integration 端到端测试 | 低 |
| 19 | frontmatter requires 环检测 | 低 |

---

## 六、三方案选型建议

| 如果你最在乎… | 推荐 |
|--------------|------|
| 最快减少 token、最小改动 | DeepSeek Phase 1 |
| Windows 友好、部署简洁、务实 | GLM 方案 |
| 长期可维护、跨会话续接、上游升级 | **Composer 方案** |

Composer 方案**不是**另起炉灶，而是吸收 deepseek/GLM 的共识（bootstrap 瘦身、无版本号目录、删除双权威、grilling 多入口、contextFiles 修复），并补上两者都未触及的三块：

1. **阶段状态机**（state.json）— 解决「AI 不知道自己在哪」
2. **overlay patches** — 解决「定制 fork 不可维护」
3. **manifest + doctor** — 解决「部署后不可观测、不可自检」

---

## 七、开放问题（需实际验证）

1. **state.json 由谁维护**：AI 写入可靠吗？是否需要在 openspec CLI 侧增加原生 phase 字段？
2. **constitution 按需加载**：AI 是否真的会在需要时加载，还是会像 using-superpowers 一样被跳过？
3. **patch anchor 脆弱性**：上游 skill 改一个标题，patch 就断——需要 CI 在 upstream 更新时自动跑 patch-apply 测试
4. **state.json 与多人协作**：多人同时改同一 change 时，state 可能冲突——是否需要 gitignore state.json，仅作本地会话辅助？

建议在 Phase 0 完成后，用 3-5 次真实变更（小功能 / bugfix / 大功能各一）做对照实验，记录：
- AI 是否正确使用 state.json
- 跨会话续接是否改善
- grilling 审查纪要是否有实际价值
- patch 流程在上游小版本更新时是否可持续

---

*文档版本：2026-07-10 | 基于 workflow 仓库当前制品审查*
