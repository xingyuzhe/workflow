# deploy-kit Design

## Responsibilities

- Copy workflow-owned neutral assets while preserving project-owned neutral configuration.
- Generate Cursor and Codex adapters.
- Maintain exact ownership indexes and managed blocks.
- Separate read-only validation from explicit repair.

## Interfaces

- `scripts/init.ps1 -Target <path> -Yes`
- `scripts/doctor.ps1 -ProjectRoot <path>`
- `scripts/doctor.ps1 -ProjectRoot <path> -Fix`
- `Install-WorkflowV2`, `Invoke-WorkflowDoctor`, `Repair-WorkflowInstall`

## Safety

Generated rule cleanup is restricted to relative paths recorded in `.workflow-managed.json`. Legacy deletion is limited to explicitly workflow-owned pack, metadata, and state paths. Mixed-ownership files use bounded markers.
