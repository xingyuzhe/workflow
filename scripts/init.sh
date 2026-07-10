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

# ── Parse args: --yes / -y and optional PROJECT_ROOT ──
YES_MODE=false
PROJECT_ROOT_ARG=""

for arg in "$@"; do
    case "$arg" in
        --yes|-y)
            YES_MODE=true
            ;;
        --help|-h)
            echo "Usage: init.sh [--yes|-y] [PROJECT_ROOT]"
            echo "  --yes, -y   Non-interactive: skip prompts, overwrite conflicts"
            echo "  PROJECT_ROOT  Target project (default: cwd)"
            exit 0
            ;;
        -*)
            fail "Unknown option: $arg"
            exit 1
            ;;
        *)
            if [ -n "$PROJECT_ROOT_ARG" ]; then
                fail "Unexpected extra argument: $arg"
                exit 1
            fi
            PROJECT_ROOT_ARG="$arg"
            ;;
    esac
done

confirm() {
    # usage: confirm "prompt" default_yes_or_no
    # In YES_MODE always returns success (0).
    local prompt="$1"
    local default="${2:-n}"
    if [ "$YES_MODE" = true ]; then
        return 0
    fi
    local hint="y/N"
    if [ "$default" = "y" ]; then
        hint="Y/n"
    fi
    read -p "  ${prompt} (${hint}) " -n 1 -r
    echo ""
    if [ "$default" = "y" ]; then
        [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]
    else
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

# ── Version configuration (versions.conf) ──
VERSIONS_CONF="$REPO_ROOT/versions.conf"
if [ ! -f "$VERSIONS_CONF" ]; then
    fail "versions.conf 不存在: $VERSIONS_CONF"
    exit 1
fi

# shellcheck disable=SC1090
source "$VERSIONS_CONF"

if [ -z "${SUPERPOWERS_VERSION:-}" ] || [ -z "${OPENSPEC_VERSION:-}" ]; then
    fail "versions.conf 必须定义 SUPERPOWERS_VERSION 和 OPENSPEC_VERSION"
    exit 1
fi

SP_VERSION_DIR="superpowers-${SUPERPOWERS_VERSION}"
OS_VERSION_DIR="openspec-${OPENSPEC_VERSION}"

SP_SOURCE="$REPO_ROOT/.cursor/skills/$SP_VERSION_DIR"
OS_SOURCE="$REPO_ROOT/.cursor/skills/$OS_VERSION_DIR"
GRILLING_SOURCE="$REPO_ROOT/.cursor/skills/grilling"
WORKFLOW_SOURCE="$REPO_ROOT/.cursor/skills/workflow"
COMMANDS_SOURCE_DIR="$REPO_ROOT/.cursor/commands/$OS_VERSION_DIR"
RULES_SOURCE="$REPO_ROOT/.cursor/rules/$SP_VERSION_DIR/superpowers-router.mdc"
MANIFEST_TEMPLATE="$REPO_ROOT/manifest.template.json"

# Deployed (flat) names — no version in path
SP_DEPLOY_NAME="superpowers"
OS_DEPLOY_NAME="openspec"
ROUTER_TARGET_NAME="superpowers-router.mdc"

# ── Determine PROJECT_ROOT ──
if [ -n "$PROJECT_ROOT_ARG" ]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT_ARG" && pwd)"
else
    PROJECT_ROOT="$(pwd)"
fi

echo ""
echo "═══════════════════════════════════════════════"
echo "  Superpowers + OpenSpec 项目部署"
echo "  superpowers-${SUPERPOWERS_VERSION} + openspec-${OPENSPEC_VERSION}"
if [ "$YES_MODE" = true ]; then
    echo "  模式: --yes (非交互)"
fi
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
    fail "Router 规则源文件不存在: $RULES_SOURCE"
    SOURCE_OK=false
fi

if [ ! -d "$GRILLING_SOURCE" ]; then
    fail "Grilling 源目录不存在: $GRILLING_SOURCE"
    SOURCE_OK=false
fi

if [ ! -d "$WORKFLOW_SOURCE" ]; then
    fail "Workflow skills 源目录不存在: $WORKFLOW_SOURCE"
    SOURCE_OK=false
fi

if [ ! -f "$MANIFEST_TEMPLATE" ]; then
    fail "manifest.template.json 不存在: $MANIFEST_TEMPLATE"
    SOURCE_OK=false
fi

if [ "$SOURCE_OK" = false ]; then
    echo ""
    fail "技能源验证失败，请检查 workflow 项目结构。"
    exit 1
fi

info "技能源验证通过"

# Count source skills (exclude using-superpowers if somehow present)
SP_SKILL_COUNT=$(find "$SP_SOURCE" -name "SKILL.md" | wc -l | tr -d ' ')
OS_SKILL_COUNT=$(find "$OS_SOURCE" -name "SKILL.md" | wc -l | tr -d ' ')
GRILLING_COUNT=$(find "$GRILLING_SOURCE" -name "SKILL.md" | wc -l | tr -d ' ')
WORKFLOW_COUNT=$(find "$WORKFLOW_SOURCE" -name "SKILL.md" | wc -l | tr -d ' ')
CMD_COUNT=$(find "$COMMANDS_SOURCE_DIR" -name "opsx-*.md" | wc -l | tr -d ' ')

echo "  Superpowers skills: $SP_SKILL_COUNT"
echo "  OpenSpec skills:    $OS_SKILL_COUNT"
echo "  Grilling:           $GRILLING_COUNT"
echo "  Workflow:           $WORKFLOW_COUNT"
echo "  Commands:           $CMD_COUNT"

CURSOR_DIR="$PROJECT_ROOT/.cursor"
SKILLS_DIR="$CURSOR_DIR/skills"
COMMANDS_TARGET_DIR="$CURSOR_DIR/commands"
RULES_DIR="$CURSOR_DIR/rules"
WORKFLOW_META_DIR="$CURSOR_DIR/workflow"
ROUTER_TARGET="$RULES_DIR/$ROUTER_TARGET_NAME"
# Legacy bootstrap path (clear on redeploy)
BOOTSTRAP_LEGACY="$RULES_DIR/superpowers-bootstrap.mdc"

mkdir -p "$SKILLS_DIR" "$COMMANDS_TARGET_DIR" "$RULES_DIR" "$WORKFLOW_META_DIR"

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
    if [ "$YES_MODE" = true ]; then
        warn "非交互模式：跳过自动安装 openspec CLI"
        CLI_INSTALLED=false
    elif confirm "是否现在自动安装？" "y"; then
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

# Legacy versioned skill dirs
if compgen -G "$SKILLS_DIR/openspec-*" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$SKILLS_DIR/openspec-*")
fi

if compgen -G "$SKILLS_DIR/superpowers-v*" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$SKILLS_DIR/superpowers-v*")
fi

# Flat skill dirs (new layout)
if [ -d "$SKILLS_DIR/$SP_DEPLOY_NAME" ]; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$SKILLS_DIR/$SP_DEPLOY_NAME")
fi

if [ -d "$SKILLS_DIR/$OS_DEPLOY_NAME" ]; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$SKILLS_DIR/$OS_DEPLOY_NAME")
fi

if [ -d "$SKILLS_DIR/grilling" ]; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$SKILLS_DIR/grilling")
fi

if [ -d "$SKILLS_DIR/workflow" ]; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$SKILLS_DIR/workflow")
fi

# Commands
if compgen -G "$COMMANDS_TARGET_DIR/opsx-*.md" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$COMMANDS_TARGET_DIR/opsx-*.md (flat)")
fi

if compgen -G "$COMMANDS_TARGET_DIR/openspec-*/opsx-*.md" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$COMMANDS_TARGET_DIR/openspec-*/ (versioned)")
fi

# Rules
if [ -e "$ROUTER_TARGET" ]; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$ROUTER_TARGET")
fi

if [ -e "$BOOTSTRAP_LEGACY" ]; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$BOOTSTRAP_LEGACY (legacy)")
fi

if compgen -G "$RULES_DIR/superpowers-v*/superpowers-*.mdc" > /dev/null 2>&1; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$RULES_DIR/superpowers-v*/ (versioned)")
fi

if [ -d "$WORKFLOW_META_DIR" ] && [ "$(ls -A "$WORKFLOW_META_DIR" 2>/dev/null)" ]; then
    CONFLICT_FOUND=true
    CONFLICT_DETAILS+=("$WORKFLOW_META_DIR")
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

clear_all_managed() {
    title "清空冲突制品"
    clear_managed_artifacts "$SKILLS_DIR/openspec-*"
    clear_managed_artifacts "$SKILLS_DIR/superpowers-v*"
    clear_managed_artifacts "$SKILLS_DIR/$SP_DEPLOY_NAME"
    clear_managed_artifacts "$SKILLS_DIR/$OS_DEPLOY_NAME"
    clear_managed_artifacts "$SKILLS_DIR/grilling"
    clear_managed_artifacts "$SKILLS_DIR/workflow"
    clear_managed_artifacts "$COMMANDS_TARGET_DIR/opsx-*.md"
    clear_managed_artifacts "$COMMANDS_TARGET_DIR/openspec-*"
    clear_managed_artifacts "$ROUTER_TARGET"
    clear_managed_artifacts "$BOOTSTRAP_LEGACY"
    clear_managed_artifacts "$RULES_DIR/superpowers-v*"
    # Keep workflow meta dir but clear contents for clean redeploy
    if [ -d "$WORKFLOW_META_DIR" ]; then
        rm -rf "$WORKFLOW_META_DIR"
        mkdir -p "$WORKFLOW_META_DIR"
        info "已清空: $WORKFLOW_META_DIR"
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
    if ! confirm "是否接受覆盖并继续？" "n"; then
        warn "用户取消部署，未执行任何覆盖操作。"
        exit 0
    fi
    clear_all_managed
else
    echo "  将部署 superpowers + openspec (flat) 到目标项目。"
    if ! confirm "是否继续？" "n"; then
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

# ── Step 4: copy skill directories (flat names) ──
title "部署技能目录"

echo "  复制 superpowers (from $SP_VERSION_DIR) ..."
cp -R "$SP_SOURCE" "$SKILLS_DIR/$SP_DEPLOY_NAME"
# Ensure using-superpowers is never deployed (compat-only)
if [ -d "$SKILLS_DIR/$SP_DEPLOY_NAME/using-superpowers" ]; then
    rm -rf "$SKILLS_DIR/$SP_DEPLOY_NAME/using-superpowers"
    info "已排除 using-superpowers（compat only）"
fi
SP_DEPLOYED=$(find "$SKILLS_DIR/$SP_DEPLOY_NAME" -name "SKILL.md" | wc -l | tr -d ' ')
info "superpowers: $SP_DEPLOYED skills 已部署"

echo "  复制 openspec (from $OS_VERSION_DIR) ..."
cp -R "$OS_SOURCE" "$SKILLS_DIR/$OS_DEPLOY_NAME"
OS_DEPLOYED=$(find "$SKILLS_DIR/$OS_DEPLOY_NAME" -name "SKILL.md" | wc -l | tr -d ' ')
info "openspec: $OS_DEPLOYED skills 已部署"

echo "  复制 grilling ..."
cp -R "$GRILLING_SOURCE" "$SKILLS_DIR/grilling"
info "grilling: $(find "$SKILLS_DIR/grilling" -name "SKILL.md" | wc -l | tr -d ' ') skill 已部署"

echo "  复制 workflow (constitution) ..."
cp -R "$WORKFLOW_SOURCE" "$SKILLS_DIR/workflow"
info "workflow: $(find "$SKILLS_DIR/workflow" -name "SKILL.md" | wc -l | tr -d ' ') skill 已部署"

# ── Step 5: copy command files ──
title "部署命令目录"

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

# ── Step 6: router rule ──
title "部署 Cursor Rules"

cp "$RULES_SOURCE" "$ROUTER_TARGET"
info "$ROUTER_TARGET_NAME 已部署"

# ── Step 7: workflow metadata (version.json + manifest.json) ──
title "写入部署元数据"

WORKFLOW_GIT_SHA="unknown"
if command -v git &> /dev/null && [ -d "$REPO_ROOT/.git" ]; then
    WORKFLOW_GIT_SHA="$(cd "$REPO_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo unknown)"
fi
DEPLOYED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%SZ")"

cat > "$WORKFLOW_META_DIR/version.json" <<EOF
{
  "workflow_version": "${WORKFLOW_GIT_SHA}",
  "superpowers_version": "${SUPERPOWERS_VERSION}",
  "openspec_version": "${OPENSPEC_VERSION}",
  "grilling_version": "1.0",
  "deployed_at": "${DEPLOYED_AT}"
}
EOF
info "version.json 已写入"

# Enrich manifest template with version fields
write_manifest() {
    local src="$1"
    local dest="$2"
    local sha="$3"
    local sp="$4"
    local os_ver="$5"

    # Convert Git Bash paths to Windows paths when needed (python/node on Windows)
    local src_native="$src"
    local dest_native="$dest"
    if command -v cygpath &> /dev/null; then
        src_native="$(cygpath -w "$src")"
        dest_native="$(cygpath -w "$dest")"
    fi

    if command -v node &> /dev/null; then
        if node -e "
const fs = require('fs');
const m = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
m.workflow_version = process.argv[3];
m.superpowers_version = process.argv[4];
m.openspec_version = process.argv[5];
fs.writeFileSync(process.argv[2], JSON.stringify(m, null, 2) + '\n');
" "$src_native" "$dest_native" "$sha" "$sp" "$os_ver"; then
            return 0
        fi
    fi

    if command -v python &> /dev/null && python -c "import json" 2>/dev/null; then
        if python -c "
import json
src = r'''$src_native'''
dest = r'''$dest_native'''
with open(src, encoding='utf-8') as f:
    m = json.load(f)
m['workflow_version'] = '''$sha'''
m['superpowers_version'] = '''$sp'''
m['openspec_version'] = '''$os_ver'''
with open(dest, 'w', encoding='utf-8') as f:
    json.dump(m, f, indent=2, ensure_ascii=False)
    f.write('\n')
"; then
            return 0
        fi
    fi

    return 1
}

if write_manifest "$MANIFEST_TEMPLATE" "$WORKFLOW_META_DIR/manifest.json" "$WORKFLOW_GIT_SHA" "$SUPERPOWERS_VERSION" "$OPENSPEC_VERSION"; then
    info "manifest.json 已写入"
else
    cp "$MANIFEST_TEMPLATE" "$WORKFLOW_META_DIR/manifest.json"
    warn "未能注入版本字段，已复制 manifest.template.json 原文"
fi

# Copy doctor script into deployed metadata dir
if [ -f "$REPO_ROOT/scripts/workflow-doctor.sh" ]; then
    cp "$REPO_ROOT/scripts/workflow-doctor.sh" "$WORKFLOW_META_DIR/doctor.sh"
    chmod +x "$WORKFLOW_META_DIR/doctor.sh" 2>/dev/null || true
    info "doctor.sh 已写入"
fi

# ── Step 8: post-deploy doctor ──
title "部署后自检 (workflow-doctor)"

DOCTOR_SCRIPT="$WORKFLOW_META_DIR/doctor.sh"
if [ -f "$DOCTOR_SCRIPT" ]; then
    if bash "$DOCTOR_SCRIPT" "$PROJECT_ROOT"; then
        info "workflow-doctor 通过"
    else
        warn "workflow-doctor 发现问题（部署已完成，请根据上方 FAIL 项修复）"
    fi
else
    warn "未找到 doctor.sh，跳过自检"
fi

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

[ "$SP_DEPLOYED" -gt 0 ] \
    && ITEMS+=("  ✅ superpowers: $SP_DEPLOYED skills") \
    || ITEMS+=("  ❌ superpowers: 未部署")

[ "$OS_DEPLOYED" -gt 0 ] \
    && ITEMS+=("  ✅ openspec: $OS_DEPLOYED skills") \
    || ITEMS+=("  ❌ openspec: 未部署")

GRILLING_DEPLOYED=$(find "$SKILLS_DIR/grilling" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$GRILLING_DEPLOYED" -gt 0 ] \
    && ITEMS+=("  ✅ grilling: 已部署") \
    || ITEMS+=("  ❌ grilling: 未部署")

WORKFLOW_DEPLOYED=$(find "$SKILLS_DIR/workflow" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$WORKFLOW_DEPLOYED" -gt 0 ] \
    && ITEMS+=("  ✅ workflow/constitution: 已部署") \
    || ITEMS+=("  ❌ workflow: 未部署")

CMD_DEPLOYED_COUNT=$(compgen -G "$COMMANDS_TARGET_DIR/opsx-*.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$CMD_DEPLOYED_COUNT" -gt 0 ] \
    && ITEMS+=("  ✅ opsx commands: $CMD_DEPLOYED_COUNT files") \
    || ITEMS+=("  ❌ opsx commands: 未部署")

[ -e "$ROUTER_TARGET" ] \
    && ITEMS+=("  ✅ router rule: 已部署") \
    || ITEMS+=("  ❌ router rule: 未部署")

[ -f "$WORKFLOW_META_DIR/version.json" ] \
    && ITEMS+=("  ✅ version.json: 已写入") \
    || ITEMS+=("  ❌ version.json: 未写入")

[ -f "$WORKFLOW_META_DIR/manifest.json" ] \
    && ITEMS+=("  ✅ manifest.json: 已写入") \
    || ITEMS+=("  ❌ manifest.json: 未写入")

[ -f "$WORKFLOW_META_DIR/doctor.sh" ] \
    && ITEMS+=("  ✅ doctor.sh: 已写入") \
    || ITEMS+=("  ⚠️  doctor.sh: 未写入")

if [ -d "$SKILLS_DIR/$SP_DEPLOY_NAME/using-superpowers" ]; then
    ITEMS+=("  ❌ using-superpowers 不应被部署")
else
    ITEMS+=("  ✅ using-superpowers: 未部署（符合预期）")
fi

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
echo "    │   ├── commands/opsx-*.md          ($CMD_DEPLOYED_COUNT files)"
echo "    │   ├── rules/"
echo "    │   │   └── $ROUTER_TARGET_NAME"
echo "    │   ├── skills/"
echo "    │   │   ├── superpowers/           ($SP_DEPLOYED skills)"
echo "    │   │   ├── openspec/              ($OS_DEPLOYED skills)"
echo "    │   │   ├── grilling/"
echo "    │   │   └── workflow/              (constitution)"
echo "    │   └── workflow/"
echo "    │       ├── version.json"
echo "    │       ├── manifest.json"
echo "    │       └── doctor.sh"
echo "    └── openspec/                     (变更管理目录)"
echo ""
echo "  下一步: 在 Cursor 中试试 /opsx:explore、/opsx:new 或 /opsx:doctor"
echo ""
