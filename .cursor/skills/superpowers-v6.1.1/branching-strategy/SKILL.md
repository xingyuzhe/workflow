---
name: branching-strategy
description: Use when starting feature work that needs a dedicated branch - presents feature branch (default) or worktree strategy for user to choose
---

# Branching Strategy

## Overview

Set up an isolated development branch before starting feature work. Presents two strategies for user to choose.

**Core principle:** Default to feature branch for simplicity and hot-reload. Offer worktree when parallel isolation is needed.

**Announce at start:** "I'm using the branching-strategy skill to set up a development branch."

## Step 1: Present Options

Always present these two options — 向用户提问确认:

```
How would you like to isolate this work?

1. Feature Branch (recommended)
   Create a new branch and stay in the current workspace.
   Pros: hot-reload works, shared node_modules, zero setup overhead.

2. Git Worktree
   Create a separate working directory with its own branch.
   Pros: full filesystem isolation, can work on multiple features simultaneously.
   Note: requires separate dev server and dependency install.
```

**If user has expressed a preference in previous conversation, skip asking and use that preference.**

## Step 2A: Feature Branch (Default)

If user chose Feature Branch (or did not express a preference):

### 1. Ensure Clean State

```bash
git status
```

**If uncommitted changes exist:**
- Warn the user: "You have uncommitted changes. Stash or commit before switching?"
- Wait for decision

### 2. Create and Switch to Branch

```bash
git checkout -b <branch-name>
```

Branch naming:
- OpenSpec changes: `change/<name>`
- Features: `feature/<name>`
- Fixes: `fix/<name>`

### 3. Verify Baseline

Run project tests to confirm clean starting point:

```bash
# Use project-appropriate command
npm test / pnpm test / cargo test / pytest / go test ./...
```

**If tests fail:** Report failures, ask whether to proceed or investigate.

### 4. Report Ready

```
Branch ready: <branch-name>
Tests passing (<N> tests, 0 failures)
Ready to implement <feature-name>
```

**Hot-reload:** If a dev server is already running, changes on this branch will be picked up automatically.

## Step 2B: Git Worktree

If user chose Git Worktree:

1. Follow the `using-git-worktrees` skill for setup
2. After setup, remind the user:

```
⚠ Debugging Tip: Your dev server is running in the main workspace.
To observe changes in the worktree, start a dev server inside the worktree directory:

  cd <worktree-path>
  pnpm dev --port <different-port>

Or open the worktree as a separate workspace:
  cursor <worktree-path>
```

## Returning to Main Branch

When work on a feature branch is complete:

```bash
git checkout main
```

For worktrees, follow `finishing-a-development-branch` which handles worktree cleanup.

## Quick Reference

| Scenario | Recommended Strategy |
|----------|---------------------|
| Normal feature development | Feature Branch |
| Need hot-reload / live debugging | Feature Branch |
| Parallel work on 2+ independent features | Worktree |
| Large refactor that might break main | Worktree |
| Quick bugfix | Feature Branch |

## Common Mistakes

### Forgetting to check for uncommitted changes
- **Problem:** `git checkout -b` carries over dirty state
- **Fix:** Always check `git status` first

### Working directly on main/master
- **Problem:** Pollutes the base branch with WIP commits
- **Fix:** Always create a branch before making changes

## Red Flags

**Never:**
- Start implementation on main/master without explicit user consent
- Auto-select worktree when user hasn't expressed preference
- Skip baseline test verification

**Always:**
- Present both options on first use
- Default to feature branch if user doesn't express preference
- Verify clean state before branching

## Integration

**Called by:**
- **subagent-driven-development** - REQUIRED before executing any tasks
- **executing-plans** - REQUIRED before executing any tasks
- **openspec-new-change** - REQUIRED before creating a new change
- **openspec-ff-change** - REQUIRED before creating a new change (fast-forward)
- **openspec-continue-change** - REQUIRED: verify/create before continuing work
- **openspec-apply-change** - REQUIRED before starting implementation
- Any skill needing isolated workspace

**Delegates to:**
- **using-git-worktrees** - When user chooses worktree strategy

**Pairs with:**
- **finishing-a-development-branch** - REQUIRED for cleanup after work complete
