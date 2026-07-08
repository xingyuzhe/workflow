#!/bin/bash
set -e

# ============================================================
#  bootstrap.sh — 一键将 Superpowers + OpenSpec 工作流注入目标项目
#
#  用法:
#    ./bootstrap.sh [目标项目路径]              # 部署到指定项目
#    ./bootstrap.sh                            # 部署到当前目录
#
#  做了什么:
#    1. 从 GitHub 拉取 obra/superpowers (MIT, public)
#    2. 通过 npm 安装 @fission-ai/openspec CLI
#    3. 部署 Superpowers 技能到 .claude/ 和 .cursor/
#    4. 运行 openspec init 生成 OpenSpec 技能和命令
#    5. 生成 CLAUDE.md (Claude Code) 和 superpowers-bootstrap.mdc (Cursor)
# ============================================================

# ── 可配置项 ──
SP_REPO="${SP_REPO:-https://github.com/obra/superpowers.git}"
SP_BRANCH="${SP_BRANCH:-main}"
SKIP_CONFIRM="${SKIP_CONFIRM:-false}"

# ── 颜色 ──
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}✅ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail()  { echo -e "${RED}❌ $1${NC}"; }
title() { echo -e "\n${BOLD}── $1 ──${NC}"; }

# ── 目标项目路径 ──
if [ -n "$1" ]; then
    PROJECT_ROOT="$(cd "$1" 2>/dev/null && pwd || true)"
    if [ -z "$PROJECT_ROOT" ]; then
        mkdir -p "$1"
        PROJECT_ROOT="$(cd "$1" && pwd)"
    fi
else
    PROJECT_ROOT="$(pwd)"
fi

# ── 临时目录 ──
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Superpowers + OpenSpec 工作流 — 一键部署"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  目标项目: $PROJECT_ROOT"
echo "  Superpowers: $SP_REPO ($SP_BRANCH)"
echo "  OpenSpec:    npm @fission-ai/openspec"
echo ""

# ── 确认 ──
if [ "$SKIP_CONFIRM" != "true" ]; then
    read -p "  确认开始部署？(y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "已取消。"
        exit 0
    fi
fi

# ════════════════════════════════════════════════════════
# Step 1: 克隆 Superpowers
# ════════════════════════════════════════════════════════
title "拉取 Superpowers 技能仓库"
echo "  正在克隆 $SP_REPO ..."
if git clone --depth 1 --branch "$SP_BRANCH" "$SP_REPO" "$TEMP_DIR/superpowers" 2>&1; then
    info "Superpowers 仓库已拉取"
else
    fail "git clone 失败，请检查网络连接"
    exit 1
fi

SP_SRC="$TEMP_DIR/superpowers"
SP_VERSION=$(node -e "console.log(require('$SP_SRC/package.json').version)" 2>/dev/null || echo "0.0.0")
SP_DIR="superpowers-v${SP_VERSION}"
info "Superpowers 版本: v${SP_VERSION} → 目录名: $SP_DIR"

# ── 列出所有 Superpowers 技能 ──
SP_SKILLS=()
for d in "$SP_SRC/skills"/*/; do
    name=$(basename "$d")
    if [ "$name" != "scripts" ] && [ -f "$d/SKILL.md" ]; then
        SP_SKILLS+=("$name")
    fi
done
echo "  检测到 ${#SP_SKILLS[@]} 个 Superpowers 技能"

# ════════════════════════════════════════════════════════
# Step 2: 安装 OpenSpec CLI
# ════════════════════════════════════════════════════════
title "检查 OpenSpec CLI"

install_openspec_cli() {
    if command -v npm &> /dev/null; then
        echo "  正在安装 @fission-ai/openspec@latest ..."
        npm install -g @fission-ai/openspec@latest 2>&1 || return 1
        return 0
    fi
    return 1
}

if command -v openspec &> /dev/null; then
    info "openspec CLI 已安装: v$(openspec --version 2>&1)"
    CLI_READY=true
elif install_openspec_cli; then
    info "openspec CLI 安装完成"
    CLI_READY=true
else
    warn "无法安装 openspec CLI（需要 Node.js >= 20.19.0），将跳过 openspec 技能生成"
    warn "请稍后手动执行: npm install -g @fission-ai/openspec@latest"
    CLI_READY=false
fi

# ════════════════════════════════════════════════════════
# Step 3: 部署 Superpowers 技能到 .claude/ 和 .cursor/
# ════════════════════════════════════════════════════════

deploy_superpowers() {
    local target_base="$1"
    local label="$2"

    local skills_dir="$target_base/skills/$SP_DIR"
    mkdir -p "$skills_dir"

    # 清空旧版本
    shopt -s nullglob
    for old in "$target_base/skills/superpowers-v"*; do
        if [ "$old" != "$skills_dir" ] && [ -d "$old" ]; then
            rm -rf "$old"
        fi
    done
    shopt -u nullglob

    for skill in "${SP_SKILLS[@]}"; do
        local src="$SP_SRC/skills/$skill"
        if [ -d "$src" ]; then
            rm -rf "$skills_dir/$skill" 2>/dev/null || true
            cp -R "$src" "$skills_dir/$skill"
        fi
    done
    info "Superpowers 技能已部署 → $skills_dir"
}

deploy_superpowers "$PROJECT_ROOT/.claude"   "Claude Code"
deploy_superpowers "$PROJECT_ROOT/.cursor"   "Cursor"

# ════════════════════════════════════════════════════════
# Step 4: openspec init (生成 OpenSpec 技能 + 命令)
# ════════════════════════════════════════════════════════
title "初始化 OpenSpec"

if [ "$CLI_READY" = true ]; then
    echo "  正在执行 openspec init ..."
    if [ -d "$PROJECT_ROOT/.claude" ] || [ -d "$PROJECT_ROOT/.cursor" ]; then
        (cd "$PROJECT_ROOT" && openspec init --tools claude,cursor 2>&1) || {
            warn "openspec init 失败，请稍后手动执行"
        }
    else
        (cd "$PROJECT_ROOT" && openspec init 2>&1) || {
            warn "openspec init 失败，请稍后手动执行"
        }
    fi
    info "OpenSpec 技能和命令已生成"
else
    warn "openspec CLI 不可用，跳过 OpenSpec 技能生成"
    warn "请稍后手动执行: cd $PROJECT_ROOT && openspec init"
fi

# ════════════════════════════════════════════════════════
# Step 5: 生成 CLAUDE.md
# ════════════════════════════════════════════════════════
title "生成 CLAUDE.md"

USING_SP_MD="$SP_SRC/skills/using-superpowers/SKILL.md"
if [ ! -f "$USING_SP_MD" ]; then
    fail "未找到 using-superpowers 技能文件"
    exit 1
fi

# 生成技能列表
generate_skill_list() {
    for skill in "${SP_SKILLS[@]}"; do
        local desc=""
        local skill_md="$SP_SRC/skills/$skill/SKILL.md"
        if [ -f "$skill_md" ]; then
            desc=$(grep -m1 "^description:" "$skill_md" 2>/dev/null | sed 's/^description:[[:space:]]*//' || echo "")
        fi
        if [ -n "$desc" ]; then
            echo "- \`$skill\` - $desc"
        else
            echo "- \`$skill\`"
        fi
    done
}

SKILL_LIST=$(generate_skill_list)

CLAUDE_MD_PATH="$PROJECT_ROOT/CLAUDE.md"
if [ -f "$CLAUDE_MD_PATH" ]; then
    bak="$CLAUDE_MD_PATH.bak.$(date +%Y%m%d%H%M%S)"
    cp "$CLAUDE_MD_PATH" "$bak"
    warn "已有 CLAUDE.md，备份至 $bak"
fi

# 写入 CLAUDE.md 头部
cat > "$CLAUDE_MD_PATH" << 'CLAUDEHEADER'
# Superpowers + OpenSpec Bootstrap (Claude Code)

You have superpowers.

This file auto-loads into every Claude Code session in this project. The
`using-superpowers` guidance below is ALREADY LOADED — do not read it again.

## How to Access Skills in Claude Code

Use the `Read` tool on skill files (or the `Skill` tool if available). Path
resolution order — try each in turn, use the first match:

1. `.claude/skills/superpowers-v{version}/{skill-name}/SKILL.md`
2. `.claude/skills/openspec-{skill-name}/SKILL.md`

Resolve `{version}` by listing the versioned directory under
`.claude/skills/` (e.g. `superpowers-v6.1.1`).

**Superpowers skills** (via `superpowers-{version}`):
CLAUDEHEADER

# 追加技能列表
echo "$SKILL_LIST" >> "$CLAUDE_MD_PATH"

# 追加 OpenSpec 技能说明
cat >> "$CLAUDE_MD_PATH" << 'CLAUDEOS'

**OpenSpec skills** (via `openspec-{skill-name}`, generated by `openspec init`):
- `openspec-explore` - Think through problems before/during work
- `openspec-new-change` - Start a new change, step by step
- `openspec-ff-change` - Fast-forward: all artifacts at once
- `openspec-apply-change` - Implement tasks from a change
- `openspec-continue-change` - Continue an existing change
- `openspec-verify-change` - Verify implementation matches artifacts
- `openspec-archive-change` - Archive a completed change
- `openspec-bulk-archive-change` - Archive multiple changes
- `openspec-sync-specs` - Sync specs across changes
- `openspec-onboard` - Guided first-time walkthrough
- `openspec-propose` - Propose a new change

**To load a skill:** try the paths above in order until found.

## Tool Notes for Claude Code

Superpowers skills reference these Claude Code native tools — no translation needed:
- `Read`, `Write`, `Edit` → same names
- `Bash` → same name (run shell commands)
- `Task` with `subagent_type` → same (dispatch subagents)
- `TodoWrite` → same (or the task list)
- `AskUserQuestion` → same (multi-choice question tool)

When a skill calls for linting (e.g. `ReadLints`), run the project's lint
command via `Bash` instead (e.g. `npm run lint` / `npx eslint`).

---

CLAUDEOS

# 追加 using-superpowers 技能内容
echo "" >> "$CLAUDE_MD_PATH"
cat "$USING_SP_MD" >> "$CLAUDE_MD_PATH"

info "CLAUDE.md 已生成"

# ════════════════════════════════════════════════════════
# Step 6: 生成 superpowers-bootstrap.mdc (Cursor)
# ════════════════════════════════════════════════════════
title "生成 Cursor 引导规则"

CURSOR_RULES_DIR="$PROJECT_ROOT/.cursor/rules"
mkdir -p "$CURSOR_RULES_DIR"

BOOTSTRAP_MDC="$CURSOR_RULES_DIR/superpowers-bootstrap.mdc"
if [ -f "$BOOTSTRAP_MDC" ]; then
    bak="$BOOTSTRAP_MDC.bak.$(date +%Y%m%d%H%M%S)"
    cp "$BOOTSTRAP_MDC" "$bak"
    warn "已有 superpowers-bootstrap.mdc，备份至 $bak"
fi

# 写入 Cursor bootstrap 头部
cat > "$BOOTSTRAP_MDC" << 'CURSORHEADER'
---
description: Superpowers - structured AI development workflow with composable skills
globs:
alwaysApply: true
---

# Superpowers Bootstrap

You have superpowers.

**IMPORTANT: The using-superpowers skill content is included below. It is ALREADY LOADED - you are currently following it. Do NOT read "using-superpowers" again — that would be redundant.**

## How to Access Skills in Cursor

Use the `Read` tool on skill files. Path resolution order (try first match):

1. `.cursor/skills/superpowers-v{version}/{skill-name}/SKILL.md`
2. `.cursor/skills/openspec-{skill-name}/SKILL.md`

**Superpowers skills** (via `superpowers-{version}`):
CURSORHEADER

# 追加技能列表
echo "$SKILL_LIST" >> "$BOOTSTRAP_MDC"

# 追加 OpenSpec 技能说明和工具映射
cat >> "$BOOTSTRAP_MDC" << 'CURSOROS'

**OpenSpec skills** (via `openspec-{skill-name}`, generated by `openspec init`):
- `openspec-explore` - Think through problems before/during work
- `openspec-new-change` - Start a new change, step by step
- `openspec-ff-change` - Fast-forward: all artifacts at once
- `openspec-apply-change` - Implement tasks from a change
- `openspec-continue-change` - Continue an existing change
- `openspec-verify-change` - Verify implementation matches artifacts
- `openspec-archive-change` - Archive a completed change
- `openspec-bulk-archive-change` - Archive multiple changes
- `openspec-sync-specs` - Sync specs across changes
- `openspec-onboard` - Guided first-time walkthrough
- `openspec-propose` - Propose a new change

**To load a skill:** Try paths in order above until found

## Tool Mapping for Cursor

When skills reference tools, use these Cursor equivalents:
- `Skill` tool → Use `Read` tool on skill path (see path resolution order above)
- `TodoWrite` → `TodoWrite` (identical)
- `Task` with subagents → `Task` tool with `subagent_type` parameter
- `Read`, `Write`, `Edit` → `Read`, `Write`, `StrReplace`
- `Bash` → `Shell`

---

CURSOROS

# 追加 using-superpowers 技能内容
echo "" >> "$BOOTSTRAP_MDC"
cat "$USING_SP_MD" >> "$BOOTSTRAP_MDC"

info "superpowers-bootstrap.mdc 已生成"

# ════════════════════════════════════════════════════════
# 收尾
# ════════════════════════════════════════════════════════
rm -rf "$TEMP_DIR"

# ── 汇总 ──
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  部署完成"
echo "═══════════════════════════════════════════════════════"
echo ""

check() {
    if [ -e "$1" ]; then
        info "$2"
    else
        warn "$2 (未就绪)"
    fi
}

check "$PROJECT_ROOT/.claude/skills/$SP_DIR"     "Claude: Superpowers 技能 ($SP_DIR)"
check "$PROJECT_ROOT/.claude/commands"            "Claude: OpenSpec 命令"
check "$PROJECT_ROOT/.claude/skills"              "Claude: OpenSpec 技能"
check "$PROJECT_ROOT/CLAUDE.md"                   "Claude: CLAUDE.md"
check "$PROJECT_ROOT/.cursor/skills/$SP_DIR"      "Cursor: Superpowers 技能 ($SP_DIR)"
check "$PROJECT_ROOT/.cursor/commands"            "Cursor: OpenSpec 命令"
check "$PROJECT_ROOT/.cursor/skills"              "Cursor: OpenSpec 技能"
check "$PROJECT_ROOT/.cursor/rules/superpowers-bootstrap.mdc" "Cursor: bootstrap 规则"
check "$PROJECT_ROOT/openspec"                    "OpenSpec 目录"

echo ""
echo "  下一步:"
echo "    Claude Code  → 重启会话，试试 /opsx:explore 或 /opsx:new"
echo "    Cursor       → 重启 Cursor，试试 /opsx:explore 或 /opsx:new"
echo ""
