## Why

Standard Codex publication does not yet converge realistic legacy installations in one run. Both `bill` and `invoice-platform-edge` retained a root `openspec/design.md`, `.openspec.yaml` metadata, and workflow-owned Cursor/opsx runtime files after publication. Publication then failed Doctor and required manual cleanup even though the business artifacts themselves were preserved.

The current migration fixture covers legacy `changes` and `specs` only, while the Codex-only contract preserves the entire Cursor tree byte-for-byte. The resulting behavior contradicts the intended downstream state: install only the Codex runtime, preserve project-private assets, and remove runtime files proven to belong to superseded workflow versions.

## What Changes

- Make standard Codex publication migrate the legacy root design into `.workflow/design.md` and remove legacy `.openspec.yaml` metadata from active and archived changes.
- Remove only positively identified superseded workflow-owned Cursor runtime assets during Codex publication; preserve unrelated Cursor commands, rules, skills, MCP configuration, and current project-private content.
- Include every newly mutated Cursor path in publication snapshot/rollback coverage.
- Make source and published Doctor reject remaining legacy metadata and superseded workflow-owned Cursor runtime paths.
- Produce a deterministic migration report that separates migrated, removed, preserved, and blocked outcomes without becoming another state authority.
- Add realistic legacy-install fixtures covering root design, active and archived metadata, old Codex and Cursor runtime, private project assets, rollback, and repeat publication.
- Remove the final legacy `.openspec.yaml` from this source repository after its historical change content remains preserved.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `deploy-kit`: Codex publication becomes a convergent, transactional migration with auditable results and selective legacy Cursor cleanup.
- `workflow-cli`: Doctor diagnoses legacy metadata and superseded workflow-owned Cursor runtime residue in a published downstream repository.

## Impact

- `scripts/lib/WorkflowDeploy.psm1`, `scripts/deploy.ps1`, deployment documentation, and publication tests.
- `.workflow/cli/WorkflowRuntime.psm1` and its generated Codex runtime copy.
- The standard Codex publication contract changes from preserving the entire Cursor tree byte-for-byte to preserving all Cursor-private content while removing only proven legacy workflow-owned assets.
- No external package, network dependency, or compatibility layer is introduced.

## Non-goals

- Installing or updating current Cursor `/workflow:*` adapters during standard Codex publication.
- Deleting arbitrary files merely because their names contain `workflow`, `openspec`, or `opsx`.
- Rewriting historical change prose or project business documentation.
- Changing lifecycle commands, artifact roles, sync semantics, or archive semantics.
- Splitting the large PowerShell modules in this change.
