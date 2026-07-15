# Workflow v2

OpenSpec-centered Cursor workflow: **schema + commands + pack prompts + three quality gates**.

Not a Superpowers skill OS. Installing is **destructive** — see [docs/BREAKING.md](docs/BREAKING.md).

## Quick start

```powershell
pwsh -File scripts/init.ps1 -Target path\to\project -Yes
pwsh -File scripts/doctor.ps1 -ProjectRoot path\to\project
```

## Layout

- `.cursor/workflow/pack/` — prompts + gates (source = deploy)
- `openspec/schemas/workflow-spec/` — shallow fork of spec-driven
- `.cursor/rules/workflow-router.mdc` — sole alwaysApply router
- `.cursor/commands/opsx-*.md` — command entrypoints
- `scripts/init.ps1` / `doctor.ps1` — PowerShell-first deploy kit

## Commands

`/opsx:explore` `/opsx:new` `/opsx:ff` `/opsx:continue` `/opsx:grill` `/opsx:apply` `/opsx:verify` `/opsx:sync` `/opsx:archive` `/opsx:doctor`

## Tests

```powershell
powershell -NoProfile -File scripts/tests/WorkflowDeploy.Tests.ps1
```

## Docs

- [docs/workflow-v2-redesign.md](docs/workflow-v2-redesign.md)
- [docs/ssot.md](docs/ssot.md)
- [docs/BREAKING.md](docs/BREAKING.md)
