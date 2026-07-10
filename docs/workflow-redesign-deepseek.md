# Workflow 重新设计方案 (DeepSeek)

> 基于当前 openspec-v1.5.0 + superpowers-v6.1.1 + grilling 整合工作流的分析，提出结构重构方案。

---

## 一、当前设计的问题诊断

### 1.1 bootstrap 规则过重

`superpowers-bootstrap.mdc` 150 行，`alwaysApply: true`。每轮对话注入 150 行上下文，其中 Red Flags 表（12 行）、Skill Types、Platform Adaptation、User Instructions 在绝大多数回合完全用不到。有效部分仅前 55 行（路径解析 + 技能清单）。token 浪费且稀释关键指令注意力。

### 1.2 命令文件与 skill 文件两层冗余

`/opsx:apply` → 读 10 行薄包装 `.md` → 指向 247 行 `SKILL.md`。中间层不提供额外价值。且薄包装的 `description` 与 `SKILL.md` frontmatter 的 `description` 存在信息冗余和不一致。

### 1.3 两套并行的技能发现机制

bootstrap 规则（alwaysApply）和 `using-superpowers/SKILL.md` 都在教 AI 如何发现和加载技能，但内容不完全一致：
- bootstrap 有 OpenSpec Priority 路由表、TDD 灰区处理规则
- using-superpowers 有 Platform Adaptation、User Instructions 优先级规则

AI 同时面对两套指令，可能在它们之间摇摆。

### 1.4 版本号硬编码散落各处

`init.sh` 中 `SP_VERSION="superpowers-v6.1.1"` 和 `OS_VERSION="openspec-v1.5.0"` 硬编码。skills/rules/commands 目录名硬编码版本号。升级时需要在整个仓库搜索替换。

### 1.5 跨版本共存价值存疑

`.cursor/skills/` 下同时保留 openspec-v1.2.0 和 v1.5.0、superpowers-v4.3.1 和 v6.1.1。实际部署只用最新版。旧版本回滚需求可通过 git tag 满足，无需常驻工作目录。

### 1.6 using-git-worktrees 仍是一级入口

bootstrap 路径解析第一条是 `superpowers-v6.1.1/{skill-name}`，`branching-strategy` 和 `using-git-worktrees` 都在此目录下。设计意图是 `branching-strategy` 作为统一入口、`using-git-worktrees` 为委托目标，但没有任何机制阻止 AI 绕过前者直接调用后者。纯靠 AI 理解和自律。

### 1.7 Windows 适配是符号化的

bootstrap 声明了 `Bash → Shell` 的映射，但多个 skill 硬编码 `#!/usr/bin/env bash`、`ls -d`、`pwd -P`、`find` 等 Unix 命令。SDD 三个辅助脚本仅 bash 版本。实际 Cursor on Windows 的 Shell 工具大概率是 PowerShell。

---

## 二、重新设计方案

### 核心哲学

> **trust the structure, not the rules** — 让文件目录结构和 frontmatter 元信息自身携带发现逻辑，AI 按需加载，而非每次对话注入全部规则。

### 2.1 bootstrap 瘦身：150 行 → ~40 行

只保留每次对话必须知道的内容：路径解析 + 技能清单 + 触发规则 + 意图路由表。

```markdown
# Superpowers Bootstrap

**Skill roots** (try in order):
1. `.cursor/skills/superpowers/{skill}/SKILL.md`
2. `.cursor/skills/openspec/{skill}/SKILL.md`
3. `.cursor/skills/grilling/{skill}/SKILL.md`

**The 1% rule:** If any chance a skill applies, read it before responding.

**Intent routing:**
| User says | Load |
|-----------|------|
| Build X / New feature | openspec-new-change or openspec-ff-change |
| Explore / How to / Compare | openspec-explore |
| Continue / Resume | openspec-continue-change |
| Implement / Start coding | openspec-apply-change |
| Review design / Stress-test / Grill | grilling |
| Fix bug / Debug | systematic-debugging |
| Write plan / Spec to tasks | writing-plans |
| Execute plan / Run tasks | executing-plans or subagent-driven-development |
| Review code / Check PR | requesting-code-review |
| Complete work / Merge / PR | finishing-a-development-branch |
```

其余内容（Red Flags 表、Skill Types、Platform Adaptation、User Instructions、TDD 灰区处理详细规则）移到 `using-superpowers/SKILL.md`，AI 仅在需要时加载。

### 2.2 取消命令薄包装层

不留 10 个 `opsx-*.md` 文件。bootstrap 中的路由表直接告诉 AI：用户输入 `/opsx:apply` → 读 `openspec-apply-change/SKILL.md`。

命令文件只保留一个空占位（让 Cursor 的 `/` 菜单能列出选项），body 内容为注释：

```markdown
---
name: /opsx-apply
id: opsx-apply
category: Workflow
description: Implement tasks from an OpenSpec change
---

<!-- Routed by superpowers-bootstrap.mdc → openspec-apply-change/SKILL.md -->
```

### 2.3 技能文件自描述 frontmatter

给 `SKILL.md` 的 YAML frontmatter 增加结构化字段，让 AI 不需要读完整个文件就能判断是否适用：

```yaml
---
name: openspec-new-change
description: Start a new OpenSpec change using the artifact workflow
phase: design
triggers:
  - "new feature"
  - "start a change"
  - "create a proposal"
  - "/opsx:new"
requires:
  - branching-strategy
recommends:
  - grilling
platform: any
---
```

字段说明：

| 字段 | 类型 | 说明 |
|------|------|------|
| `phase` | enum | `explore` / `design` / `implement` / `review` / `archive` |
| `triggers` | string[] | 用户输入匹配任一关键词即触发 |
| `requires` | string[] | 必须先执行的前置技能（AI 按顺序先加载） |
| `recommends` | string[] | 建议搭配的技能（AI 主动提议但不强制执行） |
| `platform` | string | `any` / `unix-only` / `requires-git` |

这样 bootstrap 甚至不需要硬编码完整的路由表——AI 可以通过扫描 frontmatter 来自动发现匹配的技能。

### 2.4 版本管理：current 符号链接

```
.cursor/skills/
├── openspec/                  # 符号链接 → openspec-v1.6.0
├── superpowers/               # 符号链接 → superpowers-v7.0.0
├── openspec-v1.5.0/           # 上一版（仅保留一个，用于快速回滚）
├── superpowers-v6.1.1/        # 上一版
└── grilling/                  # 无版本（内容极少）
```

bootstrap 的路径始终指向 `openspec/` 和 `superpowers/`（不带版本号）。

升级流程：
```bash
# 1. 解包新版到版本化目录
tar xf openspec-v1.6.0.tar.gz -C .cursor/skills/
# 2. 应用定制 patches（自动化脚本）
bash scripts/apply-customizations.sh openspec-v1.6.0
# 3. 更新符号链接
ln -sfn openspec-v1.6.0 .cursor/skills/openspec
# 4. 删除过时的旧版（可选）
rm -rf .cursor/skills/openspec-v1.4.0
```

### 2.5 平台适配：部署时选择

init.sh 在部署时检测环境并选择对应版本：

```bash
# Detect platform
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)  PLATFORM="git-bash" ;;
    Linux)                 PLATFORM="linux" ;;
    Darwin)                PLATFORM="macos" ;;
    *)                     PLATFORM="unknown" ;;
esac

# Copy platform-appropriate scripts
case "$PLATFORM" in
    git-bash|linux|macos)
        cp scripts/unix/* .cursor/skills/superpowers/subagent-driven-development/scripts/
        ;;
    *)
        cp scripts/powershell/* .cursor/skills/superpowers/subagent-driven-development/scripts/
        ;;
esac
```

不在 skill 文件中混合 bash/powershell 双份代码块，避免文件膨胀。

### 2.6 取消 using-superpowers 作为一级技能

既然 bootstrap 已经 alwaysApply，`using-superpowers/SKILL.md` 就是纯冗余。移到 `compat/` 目录：

```
.cursor/skills/compat/
└── using-superpowers/
    └── SKILL.md              # 仅用于非 Cursor 环境兼容
```

bootstrap 中不再推荐加载它。`using-superpowers` 的 skill 清单中也不再列出它。

### 2.7 using-git-worktrees 添加 internal 标记

```yaml
---
name: using-git-worktrees
description: Git worktree fallback — do NOT call directly, use branching-strategy
phase: internal
platform: requires-git
---
```

bootstrap 中明确标注：
```markdown
**Internal skills** (do NOT call directly):
- using-git-worktrees → called by branching-strategy only
```

---

## 三、新旧对比

| 维度 | 当前 | 重新设计 |
|------|------|---------|
| bootstrap 大小 | 150 行 alwaysApply | ~40 行 alwaysApply |
| 每轮注入 token | ~150 行 | ~40 行 + 按需加载 |
| 命令层 | 10 个薄包装文件（各 10 行） | 0-10 个空占位（无实际内容） |
| 技能发现 | bootstrap + using-superpowers 两套 | 单一权威源（bootstrap） |
| 版本共存 | 4 个版本目录常驻 | current 符号链接 + 1 个回退版 |
| 版本升级 | 全局搜索替换版本号 | 更新符号链接 |
| 平台适配 | 运行时靠 AI 理解 `Bash → Shell` | 部署时选择平台脚本 |
| frontmatter | 2 字段 (name + description) | 6 字段 (phase/triggers/requires/recommends/platform) |
| using-superpowers | 一级技能，14 个之一 | compat/ 兼容层 |
| using-git-worktrees | 一级技能，可被直接调用 | internal 标记，禁止直接调用 |

---

## 四、迁移路径

从当前设计迁移到新设计，建议分 3 个阶段：

### Phase 1：无损优化（不改变行为）

1. bootstrap 瘦身：提取冗余内容到 using-superpowers（已验证内容一致）
2. 命令文件 body 替换为注释（CUrsor 菜单仍然可见）
3. 给 using-git-worktrees 加 internal 标记

**风险**：极低。AI 行为不变，仅减少 token 消耗。

### Phase 2：结构改进（小风险）

4. 引入 current 符号链接方案
5. init.sh 改为读取符号链接目标而非硬编码版本号
6. 清理旧版本目录（保留一个）

**风险**：低。需确认 Cursor 的文件系统访问支持符号链接。

### Phase 3：能力增强（需验证）

7. 引入 frontmatter 扩展字段
8. bootstrap 路由表改为基于 frontmatter 的服务发现
9. 平台检测 + 脚本选择逻辑

**风险**：中。需验证 AI 是否能正确理解和利用新的 frontmatter 字段。建议先在单个 skill 上试点。
