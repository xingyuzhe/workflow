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
