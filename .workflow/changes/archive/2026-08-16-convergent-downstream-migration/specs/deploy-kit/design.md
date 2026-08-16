# Module responsibility

`deploy-kit` owns safe full installation, artifact-only publication, convergent legacy migration, rollback snapshots, exact ownership, strict JSON configuration, deterministic migration reporting, and consistent integrity orchestration.

# Structure and interfaces

- Preflight functions are read-only and validate source, configuration, schema, ownership, cleanup shapes, migration collisions, and root-design conflicts before target mutation.
- A read-only inventory classifies supported legacy project data and Cursor candidates into sorted migrated, removed, preserved, and blocked repository-relative paths.
- Target snapshots cover workflow-owned paths touched by each mode. Artifact publication snapshots only bounded Cursor candidates, while full Cursor installation snapshots the complete Cursor tree.
- A caught mutation failure restores every snapshotted path. The post-cleanup failpoint verifies restoration after project-data and legacy Cursor mutation.
- Full installation supplies Cursor contracts and Codex adapters; artifact publication supplies only the built Codex runtime plus project data and the selected schema.
- Publication returns the migration report object; `deploy.ps1 -Json` adds artifact version and Artifact Doctor validity.
- Root design is preserved as `.workflow/design.md`; it is project data outside the artifact graph.
- Legacy metadata removal is recursive only below the exact `.workflow/changes` or legacy `openspec/changes` roots.
- Source and Artifact Doctors delegate local health to the validated repository runtime, then add source-equivalence and deployment-layout checks.

# Ownership boundaries

- Exact legacy namespace: `.cursor/workflow`.
- Fixed commands: `opsx-apply`, `opsx-archive`, `opsx-continue`, `opsx-doctor`, `opsx-explore`, `opsx-ff`, `opsx-grill`, `opsx-new`, `opsx-sync`, and `opsx-verify` Markdown files.
- Conditional router: exact `.cursor/rules/workflow-router.mdc` path plus former OpenSpec or opsx content markers.
- Exact old Codex skill: `.agents/skills/openspec-workflow` when it is a normal directory.
- Everything else in `.cursor` and unrelated skills remain outside standard Codex publication ownership.

# Relationships

`workflow-cli` owns selected-schema, accepted-spec, transaction, and local artifact validity. `deploy-kit` owns source/generated equivalence, migration inventory, publication reporting, and target mutation safety. The published local CLI carries an equivalent legacy-residue definition because it cannot import the deployment source module.
