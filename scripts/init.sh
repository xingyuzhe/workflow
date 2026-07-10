#!/bin/bash
set -e

# ── Colors ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${GREEN}✅ $1${NC}"; }
warn()  { echo -e "${YELLOW}⚠️  $1${NC}"; }
fail()  { echo -e "${RED}❌ $1${NC}"; }
title() { echo -e "\n${BOLD}── $1 ──${NC}"; }

# ── Resolve paths ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Version configuration ──
SP_VERSION="superpowers-v6.1.1"
OS_VERSION="openspec-v1.5.0"

SP_SOURCE="$REPO_ROOT/.cursor/skills/$SP_VERSION"
OS_SOURCE="$REPO_ROOT/.cursor/skills/$OS_VERSION"
COMMANDS_SOURCE_DIR="$REPO_ROOT/.cursor/commands/$OS_VERSION"
RULES_SOURCE="$REPO_ROOT/.cursor/rules/$SP_VERSION/superpowers-bootstrap.mdc"

# ── Determine PROJECT_ROOT ──
# Priority: explicit argument > cwd
if [ -n "$1" ]; then
    PROJECT_ROOT="$(cd "$1" && pwd)"
else
    PROJECT_ROOT="$(pwd)"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  Superpowers + OpenSpec 项目部署"
echo "  $SP_VERSION + $OS_VERSION"
echo "═══════════════════════════════════════════════"
echo ""
echo "  项目目录: $PROJECT_ROOT"
echo "  技能源:   $REPO_ROOT"
echo ""

# ── Validate source directories ──
title "检查技能源"

SOURCE_OK=true

if [ ! -d "$SP_SOURCE" ]; then
    fail "Superpowers 源目录不存在: $SP_SOURCE"
    SOURCE_OK=false
fi

if [ ! -d "$OS_SOURCE" ]; then
    fail "OpenSpec 源目录不存在: $OS_SOURCE"
    SOURCE_OK=false
fi

if [ ! -d "$COMMANDS_SOURCE_DIR" ]; then
    fail "命令源目录不存在: $COMMANDS_SOURCE_DIR"
    SOURCE_OK=false
fi

if [ ! -f "$RULES_SOURCE" ]; then
    fail "Bootstrap 规则源文件不存在: $RULES_SOURCE"
    SOURCE_OK=false
fi

if [ "$SOURCE_OK" = false ]; then
    echo ""
    fail "技能源验证失败，请检查 workflow 项目结构。"
    exit 1
fi

info "技能源验证通过"

# Count source skills
SP_SKILL_COUNT=$(find "$SP_SOURCE" -name "SKILL.md" | wc -l)
OS_SKILL_COUNT=$(find "$OS_SOURCE" -name "SKILL.md" | wc -l)
CMD_COUNT=$(find "$COMMANDS_SOURCE_DIR" -name "opsx-*.md" | wc -l)

echo "  Superpowers skills: $SP_SKILL_COUNT"
echo "  OpenSpec skills:    $OS_SKILL_COUNT"
echo "  Commands:           $CMD_COUNT"

CURSOR_DIR="$PROJECT_ROOT/.cursor"
SKILLS_DIR="$CURSOR_DIR/skills"
COMMANDS_TARGET_DIR="$CURSOR_DIR/commands"
RULES_DIR="$CURSOR_DIR/rules"
BOOTSTRAP_TARGET="$RULES_DIR/superpowers-bootstrap.mdc"

mkdir -p "$SKILLS_DIR" "$COMMANDS_TARGET_DIR" "$RULES_DIR"

# ── Step 1: openspec CLI ──
title "检查 openspec CLI"

if command -v openspec &> /dev/null; then
    OPENSPEC_VER=$(openspec --version 2>&1)
    info "openspec CLI 已安装: v${OPENSPEC_VER}"
    CLI_INSTALLED=true
else
    warn "openspec CLI 未安装"
    echo ""
    echo "  安装命令:"
    echo "    npm install -g @fission-ai/openspec@latest"
    echo ""
    read -p "  是否现在自动安装？(Y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        echo "  正在安装 @fission-ai/openspec@latest ..."
        npm install -g @fission-ai/openspec@latest
        info "openspec CLI 安装完成"
        CLI_INSTALLED=true
    else
        warn "跳过安装，请稍后手动执行: npm install -g @fission-ai/openspec@latest"
        CLI_INSTALLED=false
    fi
fi

# ── Step 2: conflict detection ──
title "冲突检测"

CONFLICT_FOUND=false
CONFLICT_DETAILS=()

# Check for any existing superpowers/openspec skill versions
if compgen -G "$SKILLS_DIR/openspec-*" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$SKILLS_DIR/openspec-*")
fi

if compgen -G "$SKILLS_DIR/superpowers-v*" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$SKILLS_DIR/superpowers-v*")
fi

# Check for any existing opsx command files (flat or versioned)
if compgen -G "$COMMANDS_TARGET_DIR/opsx-*.md" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$COMMANDS_TARGET_DIR/opsx-*.md (flat)")
fi

if compgen -G "$COMMANDS_TARGET_DIR/openspec-*/opsx-*.md" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$COMMANDS_TARGET_DIR/openspec-*/ (versioned)")
fi

# Check for existing bootstrap rule (flat or versioned)
if [ -e "$BOOTSTRAP_TARGET" ]; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$BOOTSTRAP_TARGET (flat)")
fi

if compgen -G "$RULES_DIR/superpowers-v*/superpowers-bootstrap.mdc" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$RULES_DIR/superpowers-v*/ (versioned)")
fi

clear_managed_artifacts() {
    local pattern="$1"
    local matched=false
    shopt -s nullglob
    local paths=($pattern)
    shopt -u nullglob

    for target in "${paths[@]}"; do
        matched=true
        rm -rf "$target"
        info "已清空: $target"
    done

    if [ "$matched" = false ]; then
        echo "  无需清空: $pattern"
    fi
}

if [ "$CONFLICT_FOUND" = true ]; then
    warn "检测到目标项目内已存在 OpenSpec / Superpowers 制品"
    echo "  可能冲突路径:"
    for detail in "${CONFLICT_DETAILS[@]}"; do
        echo "  - $detail"
    done
    echo ""
    echo "  继续将会先清空对应目录/文件，再全量部署最新版本。"
    read -p "  是否接受覆盖并继续？(y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "用户取消部署，未执行任何覆盖操作。"
        exit 0
    fi

    title "清空冲突制品"
    # Clear all existing openspec/superpowers skill versions
    clear_managed_artifacts "$SKILLS_DIR/openspec-*"
    clear_managed_artifacts "$SKILLS_DIR/superpowers-v*"
    # Clear flat commands and versioned command directories
    clear_managed_artifacts "$COMMANDS_TARGET_DIR/opsx-*.md"
    clear_managed_artifacts "$COMMANDS_TARGET_DIR/openspec-*"
    # Clear flat and versioned rules
    clear_managed_artifacts "$BOOTSTRAP_TARGET"
    clear_managed_artifacts "$RULES_DIR/superpowers-v*"
else
    echo "  将部署 $SP_VERSION + $OS_VERSION 到目标项目。"
    read -p "  是否继续？(y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        warn "用户取消部署。"
        exit 0
    fi
fi

# ── Step 3: openspec init (non-invasive) ──
title "初始化 OpenSpec"

if [ -d "$PROJECT_ROOT/openspec" ]; then
    info "openspec/ 目录已存在"
elif [ "$CLI_INSTALLED" = true ]; then
    echo "  正在执行 openspec init --tools none ..."
    (cd "$PROJECT_ROOT" && openspec init --tools none)
    info "openspec 已初始化（仅结构，不写入官方 skills/commands）"
else
    warn "openspec CLI 未安装，跳过 openspec init"
    echo "  请稍后手动执行: cd \"$PROJECT_ROOT\" && openspec init --tools none"
fi

# ── Step 4: copy skill directories ──
title "部署技能目录"

echo "  复制 $SP_VERSION ..."
cp -R "$SP_SOURCE" "$SKILLS_DIR/$SP_VERSION"
info "$SP_VERSION: $(find "$SKILLS_DIR/$SP_VERSION" -name "SKILL.md" | wc -l) skills 已部署"

echo "  复制 $OS_VERSION ..."
cp -R "$OS_SOURCE" "$SKILLS_DIR/$OS_VERSION"
info "$OS_VERSION: $(find "$SKILLS_DIR/$OS_VERSION" -name "SKILL.md" | wc -l) skills 已部署"

# ── Step 5: copy command files ──
title "部署命令目录"

# Deploy as flat files in .cursor/commands/ (Cursor expects flat command files)
CMD_DEPLOYED=0
for source in "$COMMANDS_SOURCE_DIR"/opsx-*.md; do
    if [ ! -f "$source" ]; then
        continue
    fi
    cmd_filename="$(basename "$source")"
    cp "$source" "$COMMANDS_TARGET_DIR/$cmd_filename"
    CMD_DEPLOYED=$((CMD_DEPLOYED + 1))
done

if [ "$CMD_DEPLOYED" -gt 0 ]; then
    info "$CMD_DEPLOYED 个命令文件已部署到 $COMMANDS_TARGET_DIR/"
else
    fail "未找到命令文件"
    exit 1
fi

# ── Step 6: bootstrap rule ──
title "部署 Cursor Rules"

cp "$RULES_SOURCE" "$BOOTSTRAP_TARGET"
info "superpowers-bootstrap.mdc 已部署"

# ── Summary ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  部署完成"
echo "═══════════════════════════════════════════════"
echo ""

ITEMS=()

if command -v openspec &> /dev/null; then
    ITEMS+=("  ✅ openspec CLI: v$(openspec --version 2>&1)")
else
    ITEMS+=("  ⚠️  openspec CLI: 未安装")
fi

SP_DEPLOYED=$(find "$SKILLS_DIR/$SP_VERSION" -name "SKILL.md" 2>/dev/null | wc -l)
[ "$SP_DEPLOYED" -gt 0 ] \
    && ITEMS+=("  ✅ $SP_VERSION: $SP_DEPLOYED skills") \
    || ITEMS+=("  ❌ $SP_VERSION: 未部署")

OS_DEPLOYED=$(find "$SKILLS_DIR/$OS_VERSION" -name "SKILL.md" 2>/dev/null | wc -l)
[ "$OS_DEPLOYED" -gt 0 ] \
    && ITEMS+=("  ✅ $OS_VERSION: $OS_DEPLOYED skills") \
    || ITEMS+=("  ❌ $OS_VERSION: 未部署")

CMD_DEPLOYED=$(compgen -G "$COMMANDS_TARGET_DIR/opsx-*.md" 2>/dev/null | wc -l)
[ "$CMD_DEPLOYED" -gt 0 ] \
    && ITEMS+=("  ✅ opsx commands: $CMD_DEPLOYED files") \
    || ITEMS+=("  ❌ opsx commands: 未部署")

[ -e "$BOOTSTRAP_TARGET" ] \
    && ITEMS+=("  ✅ bootstrap rule: 已部署") \
    || ITEMS+=("  ❌ bootstrap rule: 未部署")

[ -d "$PROJECT_ROOT/openspec" ] \
    && ITEMS+=("  ✅ openspec/: 已初始化") \
    || ITEMS+=("  ⚠️  openspec/: 未初始化")

for item in "${ITEMS[@]}"; do
    echo -e "$item"
done

echo ""
echo "  部署结构:"
echo "    $PROJECT_ROOT/"
echo "    ├── .cursor/"
echo "    │   ├── commands/opsx-*.md          ($CMD_DEPLOYED files)"
echo "    │   ├── rules/"
echo "    │   │   └── superpowers-bootstrap.mdc"
echo "    │   └── skills/"
echo "    │       ├── $SP_VERSION/  ($SP_DEPLOYED skills)"
echo "    │       └── $OS_VERSION/      ($OS_DEPLOYED skills)"
echo "    └── openspec/                     (变更管理目录)"
echo ""
echo "  下一步: 在 Cursor 中试试 /opsx:explore 或 /opsx:new"
echo ""
