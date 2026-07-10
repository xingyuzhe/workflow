---
name: workflow-doctor
description: Diagnose workflow deployment health — openspec CLI, manifest, skills layout, router, platform. Use when deploy looks broken, skills are missing, or the user runs /opsx:doctor.
---

# Workflow Doctor

Announce: "Using workflow-doctor to check workflow health."

## Preferred path

Prefer the deployed script if present:

```bash
bash .cursor/workflow/doctor.sh [PROJECT_ROOT]
```

Otherwise, if working inside the workflow source repo:

```bash
bash scripts/workflow-doctor.sh [PROJECT_ROOT]
```

Pass the target project root (default: cwd). Summarize the script output for the user.

If neither script is available, perform the checks below manually with Shell / Read.

## Checks

| Check | Pass criteria | On failure |
|-------|---------------|------------|
| openspec CLI | `openspec --version` works | `npm i -g @fission-ai/openspec@latest` |
| version.json | `.cursor/workflow/version.json` exists and parses | Re-run `init.sh` |
| manifest.json | `.cursor/workflow/manifest.json` exists and parses | Re-run `init.sh` |
| router rule | `.cursor/rules/superpowers-router.mdc` exists | Re-run `init.sh` |
| flat skills | `.cursor/skills/{superpowers,openspec,grilling,workflow}/` exist | Re-run `init.sh` |
| no legacy versioned skill dirs | no `superpowers-v*` / `openspec-v*` under `.cursor/skills/` | Clear and re-deploy |
| using-superpowers absent | not under `.cursor/skills/superpowers/` | Remove; re-deploy |
| git repo | `.git` exists (warn only) | `git init` if needed |
| Git Bash (Windows) | bash available for SDD scripts | Prefer `executing-plans` over SDD |

Skip `state.json` checks in Phase 2a (not yet part of the runtime protocol).

## Output

Print a short pass/fail table, then the single most important next action. Do not modify files unless the user asks to fix something.
