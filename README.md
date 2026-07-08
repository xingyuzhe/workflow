# workflow

一键将 [Superpowers](https://github.com/obra/superpowers) + [OpenSpec](https://github.com/Fission-AI/OpenSpec) 工作流注入到任何项目中。

## 快速开始

```bash
# 在你的目标项目根目录运行:
bash <(curl -fsSL https://raw.githubusercontent.com/your-org/workflow/main/bootstrap.sh)

# 或 clone 后本地执行:
git clone git@github.com:your-org/workflow.git
cd workflow
./bootstrap.sh /path/to/your-project
```

## 做了什么

| 步骤 | 内容 |
|------|------|
| 拉取 Superpowers | `git clone https://github.com/obra/superpowers` |
| 安装 OpenSpec CLI | `npm install -g @fission-ai/openspec` |
| 部署 Claude Code | `.claude/skills/` + `.claude/commands/` + `CLAUDE.md` |
| 部署 Cursor | `.cursor/skills/` + `.cursor/commands/` + `.cursor/rules/` |
| 初始化 OpenSpec | `openspec init --tools claude,cursor` |

## 上游来源

| 组件 | 来源 | License |
|------|------|---------|
| Superpowers | [github.com/obra/superpowers](https://github.com/obra/superpowers) | MIT |
| OpenSpec | npm `@fission-ai/openspec` [GitHub](https://github.com/Fission-AI/OpenSpec) | MIT |

## 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `SP_REPO` | `https://github.com/obra/superpowers.git` | Superpowers 仓库地址 |
| `SP_BRANCH` | `main` | Superpowers 分支 |
| `SKIP_CONFIRM` | `false` | 设为 `true` 跳过确认提示 |

## 部署后的目录结构

```
your-project/
├── CLAUDE.md                              # Claude Code bootstrap
├── .claude/
│   ├── commands/opsx-*.md                 # OpenSpec 斜杠命令
│   └── skills/
│       ├── superpowers-v6.1.1/            # TDD, debugging, plans, etc.
│       └── openspec-*/                    # explore, new, apply, archive...
├── .cursor/
│   ├── commands/opsx-*.md
│   ├── rules/superpowers-bootstrap.mdc    # Cursor bootstrap
│   └── skills/
│       ├── superpowers-v6.1.1/
│       └── openspec-*/
└── openspec/                              # 变更管理目录
```
