# OpenSpec + Superpowers 整合改造分析报告

> 基于原版 openspec v1.2.0 + superpowers v4.3.1 与 `cursor/` 目录中定制版本的逐文件比对

---

## 第一部分：改造内容总结

### 一、总体改动概览

| 维度 | openspec (10 skills) | superpowers (14→13+1 skills) |
|------|---------------------|------------------------------|
| **删除** | 0 | brainstorming（1个） |
| **新增** | 0 | branching-strategy（1个） |
| **内容修改** | 6个 | 6个 |
| **未改动** | 4个 | 8个 |
| **命令文件** | 10个（全部改为薄包装） | 无命令文件（用 rules 引导） |
| **规则文件** | — | superpowers-bootstrap.mdc（新建） |

### 二、OpenSpec 技能改造详情

#### 2.1 通用改动（所有 10 个 skill）

每个 SKILL.md 增加了 YAML frontmatter，metadata 中新增 `generatedBy: "1.2.0"` 字段：

```yaml
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.2.0"
```

#### 2.2 分支隔离注入（4 个 skill：new-change / continue-change / ff-change / apply-change）

**改造规则**：在变更创建/继续/实施之前，插入一个"确保隔离工作区"步骤。

**注入内容模板**：
- 新增步骤：调用 `branching-strategy` 创建 `change/<name>` 分支
- 新增 guardrail："Never create/work on change artifacts directly on main/master"
- 新增 Integration 段：声明 `branching-strategy`（REQUIRED）和 `finishing-a-development-branch`（end of lifecycle）

**具体注入位置**：
| Skill | 注入步骤号 | 注入内容 |
|-------|-----------|---------|
| new-change | Step 3 | Ensure isolated workspace → `branching-strategy` |
| continue-change | Step 2 | Verify isolated workspace → `branching-strategy` |
| ff-change | Step 2 | Ensure isolated workspace → `branching-strategy` |
| apply-change | Step 2 | Ensure isolated workspace → `branching-strategy` |

#### 2.3 质量技能集成（1 个 skill：apply-change，改动最大）

apply-change 是整合的核心枢纽，注入了完整的 Superpowers 质量体系：

**新增内容**：
1. **Optional: Expand tasks**（Step 7）— 调用 `writing-plans` 将 tasks.md 展开为原子级 TDD 步骤，存放到 `docs/plans/YYYY-MM-DD-<change-name>/<task-name>.md`
2. **Quality Integration (Superpowers) 段**：
   - `test-driven-development`：代码任务必须遵循 RED-GREEN-REFACTOR
   - `verification-before-completion`：标记 `[x]` 前必须有运行时验证证据
   - `systematic-debugging`：遇到错误时使用系统化调试，3 次修复失败则暂停
   - code review：每 3 个任务后运行全套测试+规格对齐检查
3. **Completion Sequence 段**：完成后按序执行 `openspec-verify-change` → `finishing-a-development-branch` → `openspec-archive-change`，每步需开发者显式决策
4. 实现循环中：Make code changes → Follow TDD；Error → use systematic-debugging；Mark complete → 必须先 verify

**修改内容**：
- "Make the code changes required" → "**Follow TDD when the task involves code logic**"
- "report and wait for guidance" → "use `systematic-debugging` skill"
- "suggest archive" → "proceed to **Completion Sequence**"
- Guardrail 增加 "Never claim a task is complete without running verification first"

#### 2.4 归档后分支提醒（1 个 skill：archive-change）

在 archive 成功输出后，新增分支检查逻辑：
- 运行 `git branch --show-current` 检查是否在 feature branch
- 如是，提示开发者可使用 `finishing-a-development-branch` 处理分支
- 不自动执行清理，仅告知

#### 2.5 探索模式增强（1 个 skill：explore）

- 从 command template 合并了 "Input" 段（原 skill instructions 中没有，command content 中有）
- 新增 stance bullet："Track only key pending confirmations" — 当对话留下高影响未确认决策时，以"仍待确认（关键）"列表结尾
- 合并了 command template 中的 "If the user mentioned a specific change name" 提示行

#### 2.6 未改动的 4 个 skill

sync-specs、bulk-archive-change、verify-change、onboard — 仅添加 frontmatter，body 完全一致。

### 三、Superpowers 技能改造详情

#### 3.1 删除 brainstorming

**原版**：brainstorming 是一个将想法转化为设计的协作对话技能，有 HARD-GATE 阻止在设计批准前实施，结束后调用 writing-plans。

**改造**：完全删除，所有跨技能引用一并清除。设计/思考职责由 `openspec-explore` 接管。

#### 3.2 新增 branching-strategy

**原版不存在此 skill**。这是整合改造的核心新建技能。

**功能**：替代 `using-git-worktrees` 作为默认工作区隔离入口。

**核心逻辑**：
1. 用 AskQuestion 呈现两个选项：Feature Branch（推荐）/ Git Worktree
2. Feature Branch 路径：检查 git status → `git checkout -b change/<name>` → 运行基线测试 → 报告就绪
3. Git Worktree 路径：委托 `using-git-worktrees`，提醒 dev server 隔离问题
4. 分支命名约定：`change/<name>`（OpenSpec）/ `feature/<name>` / `fix/<name>`

**为什么需要它**：原版 superpowers 默认使用 worktree，但 worktree 打断了 hot-reload 工作流。Feature Branch 更适合大多数场景。

#### 3.3 路由技能 using-superpowers 改造

**flowchart 改造**：删除了 brainstorming 预检查门控（`About to EnterPlanMode?` → `Already brainstormed?` → `Invoke brainstorming skill`），流程简化为 `User message received` → `Might any skill apply?` → `Invoke Skill tool`。

**Skill Priority 改造**：
- 删除 brainstorming 从 process skills 列表（只保留 debugging）
- 删除 "Let's build X → brainstorming first" 示例
- 删除 "(frontend-design, mcp-builder)" 实现技能示例

#### 3.4 工作区隔离技能链改造

**executing-plans**：
- Step 5 "Complete Development" 改为条件路由：如果 `openspec/` 存在 → 走 `openspec-apply-change` 的 Completion Sequence；否则 → `finishing-a-development-branch`
- Integration 中 `using-git-worktrees` → `branching-strategy`
- 新增 `openspec-apply-change` 引用

**subagent-driven-development**：
- Flowchart 终态从直接调用 `finishing-a-development-branch` 改为 "Complete development (see Step 5 note)"
- Integration 同 executing-plans 的改造模式

**finishing-a-development-branch**：
- 全面泛化：所有 "worktree" → "branch/worktree"
- Step 5 从 "Cleanup Worktree" 改为 "Cleanup"，新增 feature branch（非 worktree）的清理逻辑
- Option 3/4 的确认信息中移除 worktree path 行
- Pairs with 新增 `branching-strategy` 为主，`using-git-worktrees` 降为条件性

**using-git-worktrees**：
- 新增 "Debugging in Worktrees" 段：提醒 dev server 不反映 worktree 变更，建议在 worktree 内启动 dev server 或用 `cursor <worktree-path>` 打开
- Red Flags 新增 "Expect changes to appear in main workspace's dev server"
- Always 新增 "Remind user to debug inside the worktree directory"
- Called by 列表：删除 brainstorming，新增 4 个 openspec skills（new/ff/continue/apply-change）

**writing-plans**：
- Context 行："worktree (created by brainstorming skill)" → "feature branch (or worktree if preferred)"
- Save Plans 路径新增 OpenSpec 模式：`docs/plans/YYYY-MM-DD-<change-name>/<task-name>.md`
- 新增 "OpenSpec Integration" 段：命名规则、双向查找、输入源（specs/design/tasks）
- Plan header 模板新增 `**OpenSpec Change:** <change-name>` 字段
- Parallel Session 引导从 "in worktree" 改为 "on the feature branch"

#### 3.5 未改动的 8 个 skill

dispatching-parallel-agents、receiving-code-review、requesting-code-review、systematic-debugging、test-driven-development、verification-before-completion、writing-skills — 内容完全一致（仅 CRLF/LF 差异）。

### 四、命令文件改造

#### 4.1 架构转变：从自包含到薄包装委托

**原版**：每个命令文件包含完整的指令集（100-500+ 行），是自包含的。

**定制版**：每个命令文件变成 2 行薄包装，委托给 SKILL.md：

```markdown
---
name: /opsx-apply
id: opsx-apply
category: Workflow
description: Implement tasks from an OpenSpec change
---

Read and follow the skill at `.cursor/skills/openspec-{version}/openspec-apply-change/SKILL.md`.

**Input**: Optionally specify a change name (e.g., `/opsx:apply add-auth`). If omitted, infer from context or prompt for selection.
```

**为什么这样做**：避免命令和技能两份内容需要同步维护。命令只做触发入口，逻辑全在 SKILL.md。

#### 4.2 命名约定

文件名和 frontmatter 使用 **hyphen**（`opsx-apply`），与原版 cursor adapter 一致。body 中的调用语法仍使用 **colon**（`/opsx:apply`），这也是原版行为。

#### 4.3 缺少的命令

原版有 11 个命令模板（含 `propose`），定制版只有 10 个（缺少 `opsx-propose.md`）。

### 五、规则文件 superpowers-bootstrap.mdc

**原版无此文件**。这是为 Cursor 环境新建的 always-apply 规则，功能包括：

1. **路径解析**：4 级 fallback 路径查找 skill 文件
2. **工具映射**：将 skill 中的抽象工具引用映射到 Cursor 工具（Skill→Read, Edit→StrReplace, Bash→Shell 等）
3. **Skill 清单**：列出全部 13 个 superpowers + 10 个 openspec skills 及一句话描述
4. **行为规则**：移植自 using-superpowers 的核心规则（1% 规则、Red Flags 表）
5. **OpenSpec Priority**：当 `openspec/` 目录存在时的用户意图→skill 路由表
6. **TDD 灰区处理**：不确定 TDD 是否适用时，必须用 AskQuestion 让用户决定

---

## 第二部分：改造规则提炼

通过上述分析，可以总结出以下改造规则体系：

### 规则 1：思考域统一 — 删除 brainstorming，收敛到 openspec-explore

- 删除 brainstorming skill
- 清除所有跨技能引用（using-superpowers flowchart、using-git-worktrees Called by、writing-plans Context）
- openspec-explore 作为唯一的"思考/探索"入口

### 规则 2：工作区隔离抽象 — 新建 branching-strategy 作为统一入口

- 新建 branching-strategy，默认 Feature Branch，可选 Worktree
- 所有需要隔离的 skill（openspec new/continue/ff/apply + superpowers executing/subagent）改为引用 branching-strategy 而非 using-git-worktrees
- using-git-worktrees 降为 branching-strategy 的子委托
- finishing-a-development-branch 泛化为 branch/worktree 通用

### 规则 3：质量技能注入到 OpenSpec 实施阶段

- apply-change 作为集成枢纽
- 注入 TDD（代码逻辑任务）、verification-before-completion（标记前验证）、systematic-debugging（错误处理）、code review（定期检查点）
- 注入 writing-plans 作为可选的任务展开工具
- 质量技能在所有 OpenSpec 阶段都生效，不仅仅是 apply

### 规则 4：完成序列统一

- apply-change 和 executing-plans、subagent-driven-development 的完成步骤统一为：openspec-verify-change → finishing-a-development-branch → openspec-archive-change
- 每步需开发者显式决策，不自动执行
- 非 OpenSpec 项目仍走原来的 finishing-a-development-branch

### 规则 5：命令文件薄包装化

- 命令文件仅作为触发入口，2 行委托到 SKILL.md
- 避免命令和技能内容重复维护
- frontmatter 格式不变（name/id/category/description）

### 规则 6：Cursor 环境适配

- 新建 superpowers-bootstrap.mdc 作为 always-apply 规则
- 提供路径解析、工具映射、skill 清单、行为规则、路由表
- 替代原版 superpowers 的 plugin 系统和 using-superpowers 的 Skill tool 依赖

### 规则 7：双向引用维护

- OpenSpec skills 引用 superpowers skills（branching-strategy, finishing-a-development-branch, writing-plans, TDD 等）
- Superpowers skills 引用 OpenSpec skills（openspec-apply-change 在 executing-plans/subagent-driven-development 的完成步骤中）
- using-git-worktrees 和 branching-strategy 的 Called by 列表包含 OpenSpec skills
- archive-change 引用 finishing-a-development-branch 做分支清理提醒

---

## 第三部分：面向未来版本的整合操作手册

当拿到最新版本的 openspec 和 superpowers 时，按以下步骤进行整合：

### Step 0：准备工作

```
1. 下载最新版 openspec 和 superpowers 源码
2. 确认版本号，更新目录名（如 openspec-vX.Y.Z / superpowers-vA.B.C）
3. 准备一个干净的工作目录进行比对
```

### Step 1：分析上游变更

```
1. 对比新版 openspec 的 skill templates（src/core/templates/workflows/*.ts）与 v1.2.0 的差异
   - 关注新增/删除/重命名的 skill
   - 关注 instructions 内容变更
   - 关注新增的 workflow schema
   
2. 对比新版 superpowers 的 skills/ 目录与 v4.3.1 的差异
   - 关注新增/删除/重命名的 skill
   - 关注 SKILL.md 内容变更
   - 关注新增的辅助文件
   
3. 特别检查：
   - brainstorming 是否在上游被删除或重命名（如果已删除，我们的改造工作量减少）
   - using-superpowers 的 flowchart 和 priority 是否有变更
   - 新版是否引入了类似 branching-strategy 的概念
```

### Step 2：执行 OpenSpec 技能定制

对每个 openspec skill，从新版源码提取 instructions 内容，然后应用以下改造：

#### 2.1 通用改造（所有 skill）

```
1. 将 instructions 内容写入 .cursor/skills/openspec-{version}/{skill-name}/SKILL.md
2. 添加 YAML frontmatter：
   ---
   name: {skill-name}
   description: {从 template description 字段复制}
   license: MIT
   compatibility: Requires openspec CLI.
   metadata:
     author: openspec
     version: "1.0"
     generatedBy: "{新版本号}"
   ---
3. 如果 skill 有对应的 command template，将 command template 中的 Input 段合并到 skill body 中（原版 skill instructions 没有 Input 段，command template 有）
```

#### 2.2 分支隔离注入（new-change / continue-change / ff-change / apply-change）

```
在创建/继续变更的步骤序列中，在"创建变更目录"步骤之前插入：

**Ensure isolated workspace (REQUIRED)**

Before creating the change, ensure we're on an isolated branch:
- Follow `branching-strategy` to create a branch named `change/<name>`
- If already on this branch (branch matches `change/<name>`), skip creation
- All subsequent change artifacts will be created on this isolated branch

**IMPORTANT**: Do NOT create the change directory on main/master. Always isolate first.

同时在 Guardrails 中添加：
- **Never create a change directory on main/master** — always ensure branch isolation first

在文件末尾添加 Integration 段：
**Integration**

**Required workflow skills:**
- **branching-strategy** — REQUIRED: Create isolated workspace before creating the change
- **finishing-a-development-branch** — Used at end of change lifecycle for merge/PR/cleanup
```

**注意**：如果新版 openspec 的步骤序列有变化（如新增步骤、重排步骤），需要根据新结构调整注入位置。核心原则是在"创建变更目录"之前注入。

#### 2.3 apply-change 质量集成

这是最复杂的改造。需要：

```
1. 在任务实现循环之前，新增 Optional: Expand tasks 步骤
   - 调用 writing-plans 生成 docs/plans/YYYY-MM-DD-<change-name>/<task-name>.md
   
2. 在实现循环中修改：
   - "Make the code changes" → "Follow TDD when the task involves code logic (see Quality Integration below)"
   - 标记完成前 → "Verify before marking complete (see Quality Integration below)"
   - 错误处理 → "use systematic-debugging skill (see Quality Integration below)"
   - 新增 review checkpoint（每3个任务后）

3. 在完成步骤中，将"suggest archive"改为引导 Completion Sequence

4. 新增 Completion Sequence 段（verify → integrate → archive，每步需开发者决策）

5. 新增 Quality Integration (Superpowers) 段（TDD / verification / debugging / code review 的详细规则）

6. 修改 Guardrails 和 Fluid Workflow Integration

7. 新增 Integration 段
```

**注意**：如果新版 apply-change 的步骤结构有变，需要适配。核心原则是：
- TDD 注入到代码实现环节
- verification 注入到标记完成环节
- systematic-debugging 注入到错误处理环节
- Completion Sequence 替代原来的"suggest archive"

#### 2.4 archive-change 分支提醒

```
在 Output On Success 之后、Guardrails 之前插入：

After displaying the summary, check if we're on a feature branch (not main/master):

git branch --show-current

If on a feature/change branch, inform the developer:
"You are on branch <branch-name>. To handle the branch (merge/PR/keep/discard),
you can use `finishing-a-development-branch`."

Do NOT auto-run cleanup — just inform.
```

#### 2.5 explore 增强

```
1. 合并 command template 中的 Input 段到 skill body
2. 在 The Stance 段新增：
   - **Track only key pending confirmations** - When (and only when) the conversation leaves **high-impact decisions** that require confirmation unresolved, end the reply with a short "仍待确认（关键）" list so they don't get lost in tangents.
3. 合并 command template 中的 "If the user mentioned a specific change name" 提示行
```

#### 2.6 未改动的 skill

sync-specs、bulk-archive-change、verify-change、onboard — 仅添加 frontmatter，body 用新版原文。

### Step 3：执行 Superpowers 技能定制

#### 3.1 删除 brainstorming

```
不复制 brainstorming/ 目录。
```

**注意**：如果新版 superpowers 已经删除了 brainstorming，跳过此步。如果新版重命名了 brainstorming，需要确认是否仍需删除。

#### 3.2 创建/更新 branching-strategy

```
如果新版 superpowers 已有类似 skill，对比内容并合并。
如果新版没有，从定制版复制 branching-strategy/SKILL.md，更新 Integration 段中的版本号引用。
```

**注意**：检查新版的分支命名约定是否与 `change/<name>` 冲突。如果新版 openspec 或 superpowers 引入了自己的分支命名规则，需要协调。

#### 3.3 using-superpowers 改造

```
1. 从新版复制 using-superpowers/SKILL.md
2. 在 flowchart 中删除 brainstorming 相关节点和边（如果新版仍存在）
3. 在 Skill Priority 中删除 brainstorming 引用
4. 如果新版引入了新的 process skill 或 priority 规则，需要协调
```

**注意**：这个 skill 的内容会被 superpowers-bootstrap.mdc 覆盖（见 Step 5），所以这里的改动主要是保持一致性。

#### 3.4 工作区隔离链改造

对 executing-plans、subagent-driven-development、finishing-a-development-branch、using-git-worktrees、writing-plans：

```
1. 从新版复制 SKILL.md
2. 检查新版是否有内容变更，如有需要合并我们的定制改动
3. 应用以下改造规则：

executing-plans & subagent-driven-development:
  - Step 5/完成步骤改为条件路由（openspec/ 存在 → Completion Sequence）
  - Integration 中 using-git-worktrees → branching-strategy
  - 新增 openspec-apply-change 引用

finishing-a-development-branch:
  - 所有 "worktree" → "branch/worktree"（在 cleanup 上下文中）
  - Step 5 标题改为 "Cleanup"，新增 feature branch 清理逻辑
  - 移除 worktree path 假设
  - Pairs with 新增 branching-strategy

using-git-worktrees:
  - 新增 "Debugging in Worktrees" 段
  - 新增 Red Flag 和 Always 项
  - Called by 列表：删除 brainstorming，新增 openspec skills

writing-plans:
  - Context 行改为 "feature branch (or worktree if preferred)"
  - 新增 OpenSpec Integration 段
  - Plan header 新增 OpenSpec Change 字段
  - Parallel Session 引导改为 "on the feature branch"
```

**关键注意**：如果新版 superpowers 对这些 skill 有重大改动（如重构了步骤结构、新增了功能），需要将我们的定制改动合并到新版基础上，而不是直接覆盖。

#### 3.5 未改动的 skill

直接从新版复制，不做修改：
- dispatching-parallel-agents
- receiving-code-review
- requesting-code-review
- systematic-debugging
- test-driven-development
- verification-before-completion
- writing-skills

### Step 4：生成命令文件

```
对每个 openspec skill，生成薄包装命令文件 .cursor/commands/opsx-{name}.md：

---
name: /opsx-{name}
id: opsx-{name}
category: Workflow
description: {从 skill description 简化，去掉 (Experimental) 等标记}
---

Read and follow the skill at `.cursor/skills/openspec-{version}/{skill-name}/SKILL.md`.

**Input**: {简化版输入说明}

注意：
- 文件名用 hyphen
- body 中的调用语法用 colon（/opsx:apply）
- {version} 保留为占位符或替换为实际版本目录名
- 不生成 opsx-propose.md（除非有特殊需求）
```

### Step 5：更新 superpowers-bootstrap.mdc

```
1. 更新 skill 清单中的版本号引用
2. 如果新版有新增 skill，添加到清单
3. 如果新版删除了 skill，从清单移除
4. 更新 OpenSpec Priority 路由表（如果 openspec skill 有变化）
5. 确认工具映射仍然有效
6. 确认路径解析规则仍然有效
```

### Step 6：验证

```
1. 检查所有跨技能引用是否有效（grep 搜索 skill name）
2. 检查 branching-strategy 的 Called by 列表是否与实际调用方一致
3. 检查 apply-change 的 Quality Integration 引用的 skill 是否都存在
4. 检查 Completion Sequence 引用的 skill 是否都存在
5. 检查命令文件的委托路径是否正确
6. 检查 superpowers-bootstrap.mdc 的 skill 清单是否完整
```

### Step 7：版本对齐注意事项

```
1. openspec CLI 版本与 skill 版本要对齐
   - skill 中的 CLI 命令（openspec new/status/instructions 等）必须与 CLI 版本兼容
   - 如果新版 CLI 有命令变更，需要更新 skill 中的命令引用

2. superpowers 的 SKILL.md 格式是否变化
   - 如果新版引入了新的 frontmatter 字段或格式，需要适配

3. 检查新版是否引入了冲突概念
   - 如新版 openspec 自己引入了分支隔离步骤 → 需要协调
   - 如新版 superpowers 自己引入了 brainstorming 替代品 → 需要决策
   - 如新版引入了类似 branching-strategy 的 skill → 需要合并
```

---

## 附录：改造前后技能清单对照

### OpenSpec Skills

| # | Skill Name | 改动类型 | 关键改动 |
|---|-----------|---------|---------|
| 1 | openspec-explore | 修改 | 合并 Input 段，新增确认追踪 bullet |
| 2 | openspec-new-change | 修改 | 注入分支隔离步骤，新增 Integration 段 |
| 3 | openspec-continue-change | 修改 | 注入分支隔离验证，新增 Integration 段 |
| 4 | openspec-apply-change | 重大修改 | 注入 TDD/验证/调试/代码审查/完成序列/任务展开 |
| 5 | openspec-ff-change | 修改 | 注入分支隔离步骤，新增 Integration 段 |
| 6 | openspec-sync-specs | 未改动 | 仅添加 frontmatter |
| 7 | openspec-archive-change | 修改 | 新增归档后分支清理提醒 |
| 8 | openspec-bulk-archive-change | 未改动 | 仅添加 frontmatter |
| 9 | openspec-verify-change | 未改动 | 仅添加 frontmatter |
| 10 | openspec-onboard | 未改动 | 仅添加 frontmatter |

### Superpowers Skills

| # | Skill Name | 改动类型 | 关键改动 |
|---|-----------|---------|---------|
| 1 | brainstorming | 删除 | — |
| 2 | branching-strategy | 新增 | Feature Branch / Worktree 选择入口 |
| 3 | dispatching-parallel-agents | 未改动 | — |
| 4 | executing-plans | 修改 | 完成步骤条件路由，Integration 更新 |
| 5 | finishing-a-development-branch | 修改 | 泛化为 branch/worktree 通用 |
| 6 | receiving-code-review | 未改动 | — |
| 7 | requesting-code-review | 未改动 | — |
| 8 | subagent-driven-development | 修改 | Flowchart 终态改条件路由，Integration 更新 |
| 9 | systematic-debugging | 未改动 | — |
| 10 | test-driven-development | 未改动 | — |
| 11 | using-git-worktrees | 修改 | 新增 Debugging 段，Called by 更新 |
| 12 | using-superpowers | 修改 | 删除 brainstorming 门控和优先级 |
| 13 | verification-before-completion | 未改动 | — |
| 14 | writing-plans | 修改 | 新增 OpenSpec Integration 段 |
| 15 | writing-skills | 未改动 | — |

### 命令和规则文件

| # | 文件 | 改动类型 | 关键改动 |
|---|------|---------|---------|
| 1 | opsx-*.md (10个) | 重建 | 全部改为薄包装委托 |
| 2 | superpowers-bootstrap.mdc | 新建 | always-apply 规则，路径/工具/路由 |
