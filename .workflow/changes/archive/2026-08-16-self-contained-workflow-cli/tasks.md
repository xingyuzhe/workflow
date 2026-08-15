## 1. Local CLI

- [x] 1.1 Implement local new, status, instructions, validate, sync, archive, and doctor commands without external packages.
- [x] 1.2 Add command-level tests for filesystem authority, capability pairs, synchronization, and archive.

## 2. Namespace migration

- [x] 2.1 Migrate live skill, commands, configuration, schema, changes, specs, prompts, and documentation to `workflow`.
- [x] 2.2 Remove external CLI discovery and all superseded live OpenSpec/opsx paths without compatibility aliases.

## 3. Publication

- [x] 3.1 Publish the CLI inside `.agents/skills/workflow` and update deterministic metadata to version 5.0.0.
- [x] 3.2 Preserve project-owned workflow data while ensuring downstream receives only one runtime copy.

## 4. Verification

- [x] 4.1 Run full deployment and lifecycle tests with external lifecycle commands unavailable.
- [x] 4.2 Assert the published runtime contains no superseded identity or package command and explicitly rejects external lifecycle dependencies.
- [x] 4.3 Run source Doctor and verify the active change is apply-ready under the local CLI.

## 5. Review fixes

- [x] 5.1 Make new, status, instructions, and validate schema-driven with dependency-aware readiness and strict artifact completion.
- [x] 5.2 Make sync/archive prepare all results before writes and reject archive collisions without side effects.
- [x] 5.3 Make local Doctor validate artifact metadata, manifest file sets, and hashes.
- [x] 5.4 Canonicalize generated JSON across Windows PowerShell and PowerShell 7.
- [x] 5.5 Remove obsolete V2/state APIs and reconcile source-only versus downstream project-data documentation.
- [x] 5.6 Add regression tests for every review finding and require a clean worktree after supported-runtime generation.
