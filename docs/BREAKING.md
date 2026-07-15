# Workflow v2 — BREAKING

Installing or upgrading to Workflow v2 is **destructive**. There is no coexistence with v1.

## What init does

- Deletes `.cursor/skills` namespaces: `superpowers*`, `openspec*`, `grilling*`, `workflow*`
- Deletes and reinstalls workflow-owned Cursor entries (`opsx-*`, legacy superpowers/openspec rules/command dirs)
- Overwrites `openspec/config.yaml` with the workflow template (`schema: workflow-spec`)
- Installs `.cursor/workflow/pack/`, `openspec/schemas/workflow-spec/`, router, version/manifest

## What init does not delete

- Business specs under `openspec/specs/**`
- Unrelated user skills/rules/commands outside workflow namespaces

## Upgrade

```powershell
pwsh -File path\to\workflow\scripts\init.ps1 -Target . -Yes
```

Doctor fails if legacy workflow skills remain. Git tag `v1-final` is archaeology only — not a supported runtime.
