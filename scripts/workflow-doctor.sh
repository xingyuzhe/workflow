#!/bin/bash
set -e

# Workflow doctor — verify deployed OpenSpec + Superpowers layout
# Usage: workflow-doctor.sh [PROJECT_ROOT]

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "${GREEN}PASS${NC}  $1"; }
warn() { echo -e "${YELLOW}WARN${NC}  $1"; }
fail() { echo -e "${RED}FAIL${NC}  $1"; FAILS=$((FAILS + 1)); }

FAILS=0

if [ -n "${1:-}" ]; then
    PROJECT_ROOT="$(cd "$1" && pwd)"
else
    PROJECT_ROOT="$(pwd)"
fi

CURSOR="$PROJECT_ROOT/.cursor"
SKILLS="$CURSOR/skills"
RULES="$CURSOR/rules"
WF="$CURSOR/workflow"

echo ""
echo -e "${BOLD}Workflow doctor${NC}"
echo "  project: $PROJECT_ROOT"
echo ""

# openspec CLI
if command -v openspec &> /dev/null; then
    pass "openspec CLI: v$(openspec --version 2>&1)"
else
    fail "openspec CLI missing — npm i -g @fission-ai/openspec@latest"
fi

# version.json
if [ -f "$WF/version.json" ]; then
    pass "version.json present"
else
    fail "missing .cursor/workflow/version.json — re-run init.sh"
fi

# manifest.json
if [ -f "$WF/manifest.json" ]; then
    if command -v node &> /dev/null; then
        MANIFEST_PATH="$WF/manifest.json"
        if command -v cygpath &> /dev/null; then
            MANIFEST_PATH="$(cygpath -w "$WF/manifest.json")"
        fi
        if node -e "JSON.parse(require('fs').readFileSync(process.argv[1],'utf8'))" "$MANIFEST_PATH" 2>/dev/null; then
            pass "manifest.json valid JSON"
        else
            fail "manifest.json is not valid JSON"
        fi
    else
        pass "manifest.json present (JSON not validated — no node)"
    fi
else
    fail "missing .cursor/workflow/manifest.json — re-run init.sh"
fi

# router
if [ -f "$RULES/superpowers-router.mdc" ]; then
    pass "superpowers-router.mdc present"
else
    fail "missing .cursor/rules/superpowers-router.mdc — re-run init.sh"
fi

if [ -f "$RULES/superpowers-bootstrap.mdc" ]; then
    warn "legacy superpowers-bootstrap.mdc still present — prefer router only"
fi

# flat skills
for name in superpowers openspec grilling workflow; do
    if [ -d "$SKILLS/$name" ]; then
        count=$(find "$SKILLS/$name" -name "SKILL.md" 2>/dev/null | wc -l | tr -d ' ')
        pass "skills/$name ($count SKILL.md)"
    else
        fail "missing .cursor/skills/$name — re-run init.sh"
    fi
done

# expected workflow skills
for skill in constitution implementation-mode workflow-doctor; do
    if [ -f "$SKILLS/workflow/$skill/SKILL.md" ]; then
        pass "workflow/$skill"
    else
        fail "missing workflow/$skill — re-run init.sh"
    fi
done

# legacy versioned dirs should be gone in deploy targets
shopt -s nullglob
legacy=( "$SKILLS"/superpowers-v* "$SKILLS"/openspec-* )
shopt -u nullglob
# openspec-* would also match nothing useful if only "openspec" exists; openspec-v* is clearer
shopt -s nullglob
legacy=( "$SKILLS"/superpowers-v* "$SKILLS"/openspec-v* )
shopt -u nullglob
if [ ${#legacy[@]} -eq 0 ]; then
    pass "no legacy versioned skill directories"
else
    fail "legacy versioned dirs still present: ${legacy[*]} — clear and re-deploy"
fi

if [ -d "$SKILLS/superpowers/using-superpowers" ]; then
    fail "using-superpowers should not be deployed"
else
    pass "using-superpowers absent"
fi

# git
if [ -d "$PROJECT_ROOT/.git" ]; then
    pass "git repository initialized"
else
    warn "not a git repo — git init recommended for branching-strategy"
fi

# Git Bash / bash availability (SDD)
if command -v bash &> /dev/null; then
    pass "bash available (SDD scripts may work)"
else
    warn "bash not found — prefer executing-plans over subagent-driven-development"
fi

echo ""
if [ "$FAILS" -eq 0 ]; then
    echo -e "${GREEN}All critical checks passed.${NC}"
    exit 0
else
    echo -e "${RED}$FAILS critical check(s) failed.${NC} Re-run init.sh or fix items above."
    exit 1
fi
