# OpenSpec + Superpowers 工作流整合：背景与方案

## 1. 为什么需要整合

Superpowers 和 OpenSpec 是两个独立演进的开源项目，各有侧重：

**Superpowers**（obra/superpowers, MIT）提供了一组高质量的**质量/实施**技能：TDD、systematic-debugging、code-review、writing-plans、executing-plans、verification-before-completion 等。它的核心价值在"怎么写对"。

**OpenSpec**（@fission-ai/openspec, MIT）提供了一组**设计/流程**技能：explore（发散思考）、new-change（结构化变更规划）、apply-change（按任务拆解执行）、archive-change（归档）等。它的核心价值在"想清楚再动手"。

两者有天然的互补性，但也存在重叠区域——最典型的是 brainstorming/superpowers 和 openspec-explore 都涉及"设计方案前的思考讨论"。如果不做取舍，AI 会在两个技能间反复横跳，既不高效也不一致。

## 2. 冲突分析与决策

经过对两个技能集的逐一比对，核心冲突点及决策如下：

| 冲突域 | Superpowers | OpenSpec | 决策 |
|--------|-------------|----------|------|
| 探索/讨论 | brainstorming（存在于早期版本） | openspec-explore | **放弃 brainstorming，统一用 openspec-explore**（收敛到 OpenSpec 的设计流程） |
| 变更规划 | writing-plans | openspec-new-change / openspec-ff-change | **保留两者**：writing-plans 用于纯代码实现规划，openspec-new-change 用于需要结构化变更管理的场景 |
| 代码审查 | requesting-code-review / receiving-code-review | 无 | **保留 Superpowers**（OpenSpec 无此能力） |
| 调试 | systematic-debugging | 无 | **保留 Superpowers**（OpenSpec 无此能力） |

**最终保留的 Superpowers 技能**（13个）：test-driven-development, systematic-debugging, writing-plans, executing-plans, subagent-driven-development, branching-strategy, using-git-worktrees, finishing-a-development-branch, dispatching-parallel-agents, requesting-code-review, receiving-code-review, verification-before-completion, writing-skills

**最终保留的 OpenSpec 技能**（10个）：openspec-explore, openspec-new-change, openspec-ff-change, openspec-apply-change, openspec-continue-change, openspec-verify-change, openspec-archive-change, openspec-bulk-archive-change, openspec-sync-specs, openspec-onboard

## 3. 分工模型

```
┌─────────────────────────────────────────────────────┐
│                    工作流管道                         │
├──────────┬──────────┬──────────┬──────────┬─────────┤
│  思考    │  设计    │  审查    │  实施    │  质量    │
├──────────┼──────────┼──────────┼──────────┼─────────┤
│ OpenSpec │ OpenSpec │ grilling │ OpenSpec │ Super-  │
│ explore  │ new-     │(可选但   │ apply-   │ powers  │
│          │ change   │ 推荐)    │ change   │ TDD,    │
│          │          │          │          │ debug,  │
│          │          │          │          │ review  │
└──────────┴──────────┴──────────┴──────────┴─────────┘
```

- **OpenSpec 负责流程**：从探索到设计到任务拆解到归档
- **Superpowers 负责执行质量**：TDD、调试、代码审查、验证
- **grilling 衔接设计与实施**：在 openspec-new-change 产出 artifacts 后、openspec-apply-change 开始编码前，进行对抗性设计审查（来自 Matt Pocock 的 skill）
- **Skill Priority 规则**在 CLAUDE.md 中硬编码，AI 根据用户意图自动路由到正确的 skill

## 4. 部署模型：为什么需要项目自持

Superpowers 和 OpenSpec 技能已经过定制化改造：
- 移除了 brainstorming，调整了 skill priority 规则
- 命令格式做了 Claude Code 适配（`/opsx-xxx` 无冒号语法）
- CLAUDE.md 的路径解析规则和 using-superpowers 内容做了裁剪

因此 workflow 不能直接 `git clone https://github.com/obra/superpowers` + `openspec init --tools claude,cursor`——这会拉取未定制的上游版本，覆盖定制内容。

**解决方案**：workflow 项目自己持有定制后的完整制品（skills + commands），bootstrap.sh 从本地源直接复制到目标项目，配合 `openspec init --tools none`（仅创建 `openspec/` 目录结构，不写入官方 skills/commands）。

## 5. 目录结构（workflow 自持）

源仓库只保留**最新**版本化目录；部署到目标项目时展平为无版本号路径。

```
workflow/
├── versions.conf                   # SUPERPOWERS_VERSION / OPENSPEC_VERSION
├── manifest.template.json
├── scripts/
│   ├── init.sh                     # 一键部署（支持 --yes）
│   └── workflow-doctor.sh          # 部署健康检查
├── .cursor/
│   ├── commands/openspec-v1.5.0/   # 命令源（部署时展平）
│   ├── rules/superpowers-v6.1.1/   # router 源
│   └── skills/
│       ├── superpowers-v6.1.1/     # 最新 Superpowers
│       ├── openspec-v1.5.0/        # 最新 OpenSpec
│       ├── grilling/
│       └── workflow/               # constitution / implementation-mode / workflow-doctor
├── compat/using-superpowers/       # 不参与部署
└── docs/
```

部署到目标项目后的结构：

```
target-project/
├── .cursor/
│   ├── commands/opsx-*.md
│   ├── rules/superpowers-router.mdc
│   ├── skills/
│   │   ├── superpowers/            # 无版本号
│   │   ├── openspec/
│   │   ├── grilling/
│   │   └── workflow/
│   └── workflow/
│       ├── version.json
│       ├── manifest.json
│       └── doctor.sh
└── openspec/
```
