## Context

The standard downstream path is Codex artifact publication. It must accept repositories that still contain the former `openspec` project-data root and former Cursor workflow adapters, while preserving business artifacts and all unrelated project-owned content.

Current migration moves only `openspec/changes` and `openspec/specs`. A root design therefore keeps `openspec/` alive and causes post-publication Doctor failure. Metadata named `.openspec.yaml` moves into `.workflow`, where neither Doctor notices nor the runtime needs it. Codex-only publication also snapshots no Cursor paths because its older contract treats the whole Cursor tree as private, even when exact files are known products of a superseded workflow runtime.

The publication already uses preflight plus a target snapshot. The change extends that boundary rather than introducing another migration engine or compatibility state.

## Goals / Non-Goals

**Goals:**

- One successful standard Codex publication converges every supported legacy workflow path to the current downstream layout.
- A repeated publication produces no filesystem changes and the same logical report.
- Root design, active changes, archived changes, accepted specs, private rules, private skills, MCP configuration, AGENTS content outside the managed block, and unrelated Cursor content remain intact.
- Cleanup ownership is proven by an exact legacy namespace, an exact legacy command name, a managed index, or legacy content markers.
- Every Cursor path that publication may mutate participates in snapshot rollback.
- Source, Artifact, and published local Doctor agree on legacy residue that makes an installation unhealthy.

**Non-Goals:**

- Publishing current Cursor adapters from `deploy.ps1`.
- Supporting arbitrary former OpenSpec YAML configuration.
- Preserving obsolete lifecycle metadata as a compatibility layer.
- Scanning or rewriting arbitrary project prose that mentions OpenSpec historically.
- Refactoring the deployment and runtime modules into smaller modules.

## Decisions

### 1. Extend the existing migration boundary

`Move-WorkflowLegacyProjectData` remains the only legacy project-data migration entry point. In addition to `changes` and `specs`, it treats `openspec/design.md` as project data and publishes it to `.workflow/design.md`.

If both root designs exist, equivalent normalized text permits removal of the obsolete copy; different content is a preflight blocker. Existing change/spec destination collisions remain blockers rather than implicit merges.

All `.openspec.yaml` files below migrated active or archived change trees are obsolete lifecycle metadata and are removed. Other dotfiles and project-owned files remain untouched.

### 2. Selective legacy Cursor cleanup

Standard Codex publication does not create current Cursor adapters. It removes only:

- the exact former `.cursor/workflow` namespace;
- the fixed supported set of `.cursor/commands/opsx-<operation>.md` files;
- `.cursor/rules/workflow-router.mdc` only when its content contains former OpenSpec/opsx routing markers.

Current `/workflow:*` commands, a current workflow router, arbitrary Cursor commands/rules/skills, and `.cursor/mcp.json` are preserved. Empty parent directories are not material and need not be removed.

### 3. Preflight inventory and deterministic report

A read-only legacy inventory is calculated before mutation. It returns repository-relative sorted arrays for `Migrated`, `Removed`, `Preserved`, and `Blocked`. Paths use forward slashes so output is stable across supported PowerShell runtimes.

Publication returns the inventory as its migration report. `deploy.ps1 -Json` emits a stable JSON object containing target, artifact version, those four arrays, and Doctor validity. Human output remains concise and reports action counts. The report is evidence only and is never read as lifecycle state.

### 4. Rollback includes bounded Cursor targets

The publication snapshot adds the exact legacy Cursor namespace, command files, and router candidate. A caught failure restores those targets along with `.workflow`, `openspec`, AGENTS, Codex integration, and the managed skill. Publication never snapshots or replaces the rest of `.cursor`.

### 5. Doctor uses the same residue definition

Artifact Doctor and published local Doctor reject:

- `openspec/` and `.agents/skills/openspec-workflow`;
- `.openspec.yaml` below `.workflow/changes`;
- `.cursor/workflow`;
- exact `opsx-<operation>.md` commands;
- a router containing former OpenSpec/opsx markers.

They do not reject unrelated Cursor content or historical prose inside archived Markdown artifacts.

### 6. Realistic synthetic upgrade fixtures

Tests construct synthetic repositories shaped like the observed downstream installations: root design, accepted specs, active and archived changes, metadata, old Codex skill, old Cursor pack/commands/router, private AGENTS/rules/skills/MCP, and an unrelated Cursor command.

The fixture must prove first-run convergence, business-file preservation, report classification, second-run idempotence, local and Artifact Doctor success, and byte-for-byte rollback after a publication failpoint.

## Risks / Trade-offs

- Selective Cursor cleanup changes the earlier byte-for-byte preservation promise. Exact candidate names plus content markers constrain the destructive boundary and preserve current/private Cursor adapters.
- Root `.workflow/design.md` is project data but not a schema artifact. Doctor preserves it without assigning lifecycle readiness semantics.
- Removing `.openspec.yaml` discards obsolete tool metadata. Change content and archive history remain, and this repository intentionally provides no external-CLI compatibility.
- Adding JSON output increases the deploy script interface. Human output remains backward-compatible, while JSON is opt-in.
