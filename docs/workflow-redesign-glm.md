# Workflow 重新设计方案 (GLM)

> 基于对当前 openspec-v1.5.0 + superpowers-v6.1.1 + grilling 整合工作流的逐文件审查，以及与 deepseek 方案的交叉对比，提出补充问题和差异化设计方案。

---

## 一、deepseek 方案已覆盖的问题（确认但不重复）

| # | 问题 | deepseek 方案 | 我的判断 |
|---|------|-------------|---------|
| 1 | bootstrap 150 行过重 | 瘦身到 40 行 | 同意，但 40 行可能太激进——路由表本身就要 15 行 |
| 2 | 命令薄包装冗余 | 空占位 + 路由表 | 同意 |
| 3 | using-superpowers 双重权威 | 移到 compat/ | 同意 |
| 4 | 版本号硬编码 | 符号链接方案 | 同意方向，但 Windows 符号链接需要管理员权限 |
| 5 | 旧版本目录常驻 | 只留一个回退版 | 同意 |
| 6 | using-git-worktrees 可被直接调用 | internal 标记 | 同意 |
| 7 | Windows 适配符号化 | 部署时选择脚本 | 同意 |

---

## 二、deepseek 方案未覆盖的问题

### 2.1 grilling 集成不完整——只挂了 apply-change 一个入口

当前 grilling 只在 `openspec-apply-change` 的 Step 3 被引用。但实际工作流中，用户可能在以下场景也需要设计审查：

- **new-change 结束后**：proposal/design/specs 刚产出，用户可能想在继续创建 tasks 之前就审查设计
- **ff-change 结束后**：所有 artifacts 一次性生成完毕，正是审查的好时机
- **continue-change 创建完 design.md 后**：设计文档刚写完，趁热审查
- **用户直接说 "grill me"**：bootstrap 路由表已覆盖这个入口，但用户可能不知道这个触发词

**问题**：grilling 只挂在 apply-change 一个点上，而设计审查的需求可能出现在设计阶段的任何时刻。用户被迫等到 apply-change 才被提议审查，或者需要自己知道去说 "grill me"。

**改进**：在 new-change、ff-change、continue-change 的末尾（STOP and wait for user direction 之后）添加一个"建议审查"的提示。不需要强制——只在用户即将离开设计阶段时轻量提醒。

### 2.2 apply-change Step 3 时序缺陷——引用了尚未加载的 contextFiles

实际代码验证：

```
Step 3 (grilling): "Load all change artifacts (proposal, design, specs) from `contextFiles`"
Step 5 (get apply instructions): 运行 openspec instructions apply --change --json
Step 6 (read context files): "Read every file path listed under `contextFiles`"
```

`contextFiles` 是 Step 5 的 `openspec instructions apply --json` 返回的字段。Step 3 引用它时，这个字段还不存在。AI 实际执行时会困惑：去哪里拿 contextFiles？

**改进**：Step 3 改为直接从 `openspec/changes/<name>/` 目录读取 artifacts（通过 `openspec status --change --json` 的 `changeRoot` 和 `artifactPaths` 字段定位文件），而非引用尚未加载的 `contextFiles`。或者把 Step 3 移到 Step 6 之后——但那样就太晚了（已经读完了上下文才开始审查）。

### 2.3 工具名称不统一——AskUserQuestion vs AskQuestion

实际代码验证：

| 工具名 | 使用方 | 出现次数 |
|--------|--------|---------|
| `AskUserQuestion` | 8 个 openspec skills | 24 处 |
| `AskQuestion` | branching-strategy | 2 处 |

这两个名字指的是同一个工具，但 openspec skills 用 `AskUserQuestion`，我们自定义的 branching-strategy 用 `AskQuestion`。Cursor 的实际工具名是哪个？如果 AI 按字面理解，可能一个能工作另一个不能。

**改进**：统一为一个名称。实际上 Cursor 没有名为 `AskUserQuestion` 或 `AskQuestion` 的内置工具——这些是 skill 指令中的描述性文字，AI 会理解为"用提问的方式让用户选择"。所以应该统一为一个描述性短语，而非假装是一个工具名。

### 2.4 技能清单中未列出 using-superpowers——但磁盘上存在

bootstrap 第 15 行说"using-superpowers 的内容已经包含在下面，不需要再读"。但 bootstrap 的技能清单（13 个 superpowers + 10 个 openspec + 1 个 grilling = 24 个）中并没有列出 using-superpowers。同时 `using-superpowers/SKILL.md` 磁盘上存在（59 行）。

如果 AI 因任何原因独立发现了这个文件并尝试加载它，会得到与 bootstrap 不一致的指令（缺少 OpenSpec Priority 表、缺少 TDD 灰区规则、有 Platform Adaptation 而 bootstrap 没有）。

**改进**：deepseek 方案提出移到 compat/ 目录——同意。但更彻底的做法是直接删除它，因为 bootstrap 已经完全覆盖了它的功能。保留它只会在未来制造"哪个是权威"的歧义。

### 2.5 部署后的目标项目没有版本可追溯性

init.sh 部署后，目标项目的 `.cursor/` 目录里没有任何文件记录"这是从哪个版本的 workflow 部署的"。如果用户报告问题，无法快速知道他们用的是什么版本。

**改进**：init.sh 在部署时写一个 `.cursor/.workflow-version` 文件：

```
workflow_version=<git-sha-or-tag>
superpowers_version=v6.1.1
openspec_version=v1.5.0
grilling_version=1.0
deployed_at=<timestamp>
```

### 2.6 冲突检测不覆盖 .cursor/rules 下的非版本化目录

init.sh 的冲突检测覆盖了：
- `$SKILLS_DIR/openspec-*`（版本化 skills）
- `$SKILLS_DIR/superpowers-v*`（版本化 skills）
- `$SKILLS_DIR/grilling`
- `$COMMANDS_TARGET_DIR/opsx-*.md`（扁平命令）
- `$COMMANDS_TARGET_DIR/openspec-*`（版本化命令）
- `$BOOTSTRAP_TARGET`（扁平规则）
- `$RULES_DIR/superpowers-v*`（版本化规则）

但如果目标项目的 `.cursor/rules/` 下有其他 `.mdc` 文件（比如用户自己写的规则），不会被检测到——这是对的。但如果是旧版部署遗留的 `.cursor/rules/opsx-rules.mdc` 之类的文件，也不在检测范围内。

**改进**：这个问题影响很小。当前检测已经足够覆盖已知的部署格式。可以作为低优先级改进。

### 2.7 writing-skills 689 行——对工作流用户无价值

`writing-skills/SKILL.md` 是教 AI 如何创建新技能的元技能。对于一个使用工作流的目标项目来说，这个技能永远不会被触发——用户不需要在目标项目里创建新技能，那是在 workflow 仓库里做的事。

但它占据了 689 行（是最大的技能文件），且每次 AI 在思考"是否有技能适用"时都会看到它的描述。

**改进**：部署时不复制 writing-skills。或者更精细地分：workflow 仓库保留它（开发时需要），部署到目标项目时不带它。

### 2.8 SDD 辅助脚本在 Windows 上不可执行

`review-package`、`sdd-workspace`、`task-brief` 三个脚本是 `#!/usr/bin/env bash`，在 Windows 上需要 Git Bash 执行。但 Cursor 的 Shell 工具不一定走 Git Bash。

deepseek 方案提出"部署时选择平台脚本"——方向对，但实际操作中，为这三个脚本写 PowerShell 版本的工作量不小（它们用了 `git`、`sed`、`awk` 等），而且上游每次更新脚本都需要同步翻译。

**替代方案**：在 bootstrap 中声明前提条件"本工作流的 SDD 子流程需要 Git Bash 环境。如果不可用，使用 executing-plans 替代 subagent-driven-development"。这样不需要翻译脚本，而是让用户知道 SDD 在 Windows 上的降级方案。

---

## 三、与 deepseek 方案的设计分歧

### 3.1 bootstrap 瘦身——40 行 vs 60 行

deepseek 方案主张 40 行。我认为 40 行太激进——砍掉了 Red Flags 表，但 Red Flags 表是防止 AI 跳过技能的关键心理锚点。如果把它移到 using-superpowers 再按需加载，AI 可能在加载它之前就已经跳过了技能检查。

**我的方案**：60 行。保留路由表（15 行）+ 路径解析（3 行）+ 技能清单（24 行，但每行更短）+ 1% 规则（3 行）+ 精简版 Red Flags（5 行，只留最高频的 5 条）+ internal 标记（2 行）+ 前提条件声明（2 行）+ 杂项（6 行）。

### 3.2 符号链接 vs 版本配置文件

deepseek 方案用符号链接。Windows 上符号链接需要管理员权限或开发者模式，且 Cursor 对符号链接的行为未验证。

**我的方案**：用一个 `versions.conf` 文件 + init.sh 读取配置部署：

```bash
# versions.conf
SUPERPOWERS_VERSION=v6.1.1
OPENSPEC_VERSION=v1.5.0
```

bootstrap 中的路径不带版本号（`.cursor/skills/superpowers/{skill}/SKILL.md`），init.sh 在部署时把版本化目录复制为不带版本号的目录名：

```bash
cp -R "$SP_SOURCE" "$SKILLS_DIR/superpowers"    # 不带版本号
cp -R "$OS_SOURCE" "$SKILLS_DIR/openspec"        # 不带版本号
```

这样不需要符号链接，不需要管理员权限，且部署后的目录结构更干净。代价是丢失了"同目录下多版本共存"的能力——但 deepseek 方案也说了只保留一个回退版，那就打 git tag 回滚即可。

### 3.3 frontmatter 扩展字段——先验证再推广

deepseek 方案提出 6 个 frontmatter 字段（phase/triggers/requires/recommends/platform）。方向正确，但有两个风险：

1. **AI 不一定理解自定义字段**：frontmatter 是 YAML，AI 会读它，但 `phase: design` 是否真的影响 AI 的技能选择行为？没有验证过。
2. **维护成本**：每次从上游更新 skill 时，都需要手动补充这些字段（上游不会有这些字段）。

**我的方案**：先在 3 个关键技能上试点（openspec-new-change、openspec-apply-change、branching-strategy），验证 AI 是否能正确利用 `requires` 字段自动加载前置技能。如果验证通过，再推广到全部技能。

### 3.4 命令文件——不是空占位，而是路由声明

deepseek 方案让命令文件 body 为注释。但我认为命令文件可以承载一个有用的功能：**命令到技能的显式映射**，作为 bootstrap 路由表的备份。

```markdown
---
name: /opsx-apply
id: opsx-apply
category: Workflow
description: Implement tasks from an OpenSpec change
---

Skill: openspec-apply-change
Path: .cursor/skills/openspec/openspec-apply-change/SKILL.md
```

这样即使 bootstrap 规则因为某种原因没生效（比如用户删除了 rules 目录），命令文件自身仍然能引导 AI 到正确的 skill。

---

## 四、重新设计方案

### 4.1 目录结构

```
workflow/                           # 源仓库
├── versions.conf                   # 版本配置（单一权威源）
├── scripts/
│   ├── init.sh                     # 部署脚本（读取 versions.conf）
│   └── apply-customizations.sh     # 定制 patches 自动应用
├── .cursor/
│   ├── commands/
│   │   └── openspec-v1.5.0/        # 版本化源（部署时展平）
│   ├── rules/
│   │   └── superpowers-v6.1.1/     # 版本化源（部署时展平）
│   └── skills/
│       ├── openspec-v1.5.0/        # 版本化源
│       ├── superpowers-v6.1.1/     # 版本化源
│       └── grilling/               # 无版本
└── docs/
```

部署到目标项目后：

```
target-project/
├── .cursor/
│   ├── commands/                   # 扁平，无版本号
│   │   ├── opsx-apply.md
│   │   └── ...
│   ├── rules/
│   │   └── superpowers-bootstrap.mdc
│   ├── skills/
│   │   ├── superpowers/            # 无版本号目录名
│   │   ├── openspec/               # 无版本号目录名
│   │   └── grilling/
│   └── .workflow-version           # 部署元数据
└── openspec/
```

### 4.2 bootstrap 规则（~60 行）

```markdown
---
description: Superpowers + OpenSpec workflow
globs:
alwaysApply: true
---

# Workflow Bootstrap

<SUBAGENT-STOP>
If dispatched as subagent for a specific task, ignore this. Follow your instructions.
</SUBAGENT-STOP>

**Skill roots** (try in order):
1. `.cursor/skills/superpowers/{skill}/SKILL.md`
2. `.cursor/skills/openspec/{skill}/SKILL.md`
3. `.cursor/skills/grilling/{skill}/SKILL.md`

**The 1% rule:** If any chance a skill applies, read it BEFORE responding. Not optional.

**Intent routing:**
| User says | Load |
|-----------|------|
| Build / New feature / Add | openspec-new-change or openspec-ff-change |
| Explore / How to / Compare | openspec-explore |
| Continue / Resume | openspec-continue-change |
| Implement / Start coding | openspec-apply-change |
| Review design / Grill | grilling |
| Fix bug / Debug | systematic-debugging |
| Write plan | writing-plans |
| Execute plan | executing-plans or subagent-driven-development* |
| Review code | requesting-code-review |
| Complete / Merge / PR | finishing-a-development-branch |

*SDD requires Git Bash. On Windows without Git Bash, use executing-plans.

**Internal skills** (do NOT call directly):
- using-git-worktrees → via branching-strategy only

**Top 5 rationalization traps** (STOP if you think these):
| "Just a simple question" | Questions are tasks. Check skills. |
| "Need context first" | Skill check comes BEFORE questions. |
| "Remember this skill" | Skills evolve. Read current version. |
| "Skill is overkill" | Simple things become complex. Use it. |
| "Know what it means" | Knowing ≠ using. Read it. |

**Quality skills always active during implementation**: TDD, verification-before-completion, systematic-debugging. When uncertain about TDD, ask the user.
```

### 4.3 命令文件（路由声明式）

```markdown
---
name: /opsx-apply
id: opsx-apply
category: Workflow
description: Implement tasks from an OpenSpec change
---

Skill: openspec-apply-change
Path: .cursor/skills/openspec/openspec-apply-change/SKILL.md

**Input**: Optionally specify a change name (e.g., `/opsx:apply add-auth`).
```

### 4.4 grilling 多入口挂载

不只挂在 apply-change，而是在设计阶段的所有出口都加轻量提醒：

**new-change 末尾**（STOP and wait 之后）：
```
**Next steps:**
- Create artifacts with `/opsx:continue`
- **Review the design before implementing?** Say "grill me" to stress-test the plan
```

**ff-change 末尾**：
```
**Next steps:**
- Implement with `/opsx:apply`
- **Review the design first?** Say "grill me" to walk through each decision
```

**apply-change Step 3**（已有）：保持不变，但修复 contextFiles 时序问题——改为通过 `openspec status --change --json` 的 `artifactPaths` 定位文件。

### 4.5 init.sh 改进

1. 读取 `versions.conf` 而非硬编码
2. 部署时目录名不带版本号
3. 写 `.cursor/.workflow-version` 元数据文件
4. 部署时不复制 writing-skills（可选）
5. 平台检测 + SDD 降级提示

### 4.6 定制 patches 自动化

```bash
# scripts/apply-customizations.sh
#!/bin/bash
VERSION=$1  # e.g. openspec-v1.6.0

# 应用所有定制 patches：
# 1. 注入分支隔离步骤
# 2. 注入质量技能集成
# 3. 注入 grilling 入口
# 4. 删除 brainstorming
# 5. 创建 branching-strategy
# ...
```

每次上游发布新版本时，运行此脚本自动应用定制，人工审查 diff 后合并。

---

## 五、与 deepseek 方案对比

| 维度 | deepseek 方案 | GLM 方案 |
|------|--------------|---------|
| bootstrap 行数 | 40 行 | 60 行（保留精简 Red Flags） |
| 命令文件 | 空占位 | 路由声明（带 skill 名 + path） |
| 版本管理 | 符号链接 | versions.conf + 无版本号目录名 |
| frontmatter 扩展 | 全量推广 | 3 个技能试点验证后推广 |
| grilling 挂载 | 仅 apply-change | new/ff/apply 三入口 + contextFiles 时序修复 |
| using-superpowers | 移到 compat/ | 删除（bootstrap 完全覆盖） |
| writing-skills | 保留 | 部署时不带（目标项目不需要） |
| Windows SDD | 部署时翻译脚本 | 降级提示（用 executing-plans 替代） |
| 部署可追溯性 | 未提及 | .workflow-version 元数据文件 |
| 工具名统一 | 未提及 | 统一 AskUserQuestion/AskQuestion |

---

## 六、迁移路径

### Phase 1：修复性改动（不改变结构）

1. 修复 apply-change Step 3 的 contextFiles 时序问题
2. 统一 AskUserQuestion / AskQuestion 工具名
3. 在 new-change、ff-change 末尾添加 grilling 建议
4. init.sh 添加 .workflow-version 元数据写入
5. init.sh 添加 writing-skills 可选跳过

**风险**：极低。纯内容修复。

### Phase 2：结构优化（改变部署形态）

6. 引入 versions.conf
7. 部署时目录名不带版本号
8. bootstrap 瘦身到 60 行
9. 命令文件改为路由声明式
10. 删除 using-superpowers（或移到 compat/）

**风险**：低。需要重新部署验证。

### Phase 3：能力增强（需验证）

11. 3 个技能试点 frontmatter 扩展字段
12. 验证 AI 是否能利用 requires 字段自动加载前置技能
13. 定制 patches 自动化脚本
14. 平台检测 + SDD 降级逻辑

**风险**：中。需要实际 AI 对话验证。
