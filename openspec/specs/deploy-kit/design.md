# deploy-kit Design

## Responsibilities

- Copy workflow-owned neutral assets while preserving project-owned neutral configuration.
- Generate only the selected Cursor and/or Codex adapters.
- Maintain exact ownership indexes and managed blocks.
- Separate read-only validation from explicit repair.

## Interfaces

- `scripts/init.ps1 -Target <path> [-Clients cursor,codex] -Yes`
- `scripts/doctor.ps1 -ProjectRoot <path>`
- `scripts/doctor.ps1 -ProjectRoot <path> -Fix`
- `Install-WorkflowV2`, `Invoke-WorkflowDoctor`, `Repair-WorkflowInstall`

## Safety

Generated rule cleanup is restricted to relative paths recorded in `.workflow-managed.json`. Legacy deletion is limited to explicitly workflow-owned pack, metadata, and state paths. Mixed-ownership files use bounded markers.

Client names are normalized once and passed through generation, cleanup, metadata, and validation. Shared core installation is independent of client selection. Installed metadata supplies the default scope for subsequent Doctor and repair operations. An unselected client tree is outside the operation's ownership boundary.
