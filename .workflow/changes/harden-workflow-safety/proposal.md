## Why

The self-contained workflow has a sound contract-first architecture, but isolated review probes found destructive partial installs, ambiguous delta merges, and Doctor false positives. These defects undermine the safety claims that downstream projects rely on and should be corrected before wider deployment.

## What Changes

- Make full installation and Codex publication validate before mutation, roll back failed mutations, and remove only content with explicit workflow ownership.
- Reject ambiguous requirement deltas, including duplicate requirements and rename/add/modify collisions, before main specs are written.
- Reuse one complete local integrity model across source Doctor, Artifact Doctor, and published CLI Doctor.
- Replace the partial YAML-like configuration dialect with strict repository-local JSON configuration.
- Make schema semantics explicit through artifact kinds and schema-declared publication targets rather than fixed artifact IDs or paths.
- Separate the documented full Cursor+Codex installation from Codex artifact-only publication and add regression coverage for every review probe.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `deploy-kit`: transactional mutation, precise ownership, complete Doctor equivalence, strict JSON configuration, and explicit deployment modes.
- `workflow-cli`: unambiguous delta semantics and schema-role-driven lifecycle operations.
- `schema-pack`: explicit artifact kinds and publication targets in the local schema contract.

## Impact

This changes repository configuration filenames from `.yaml` to `.json`, the local schema format, CLI validation, deployment scripts, Doctor behavior, documentation, tests, and generated Cursor/Codex artifacts. It adds no external runtime dependency.

## Non-goals

- No compatibility layer for the former YAML-like configuration files.
- No external YAML parser, lifecycle CLI, Node package, or network dependency.
- No archive, merge, push, or downstream deployment as part of this change.
