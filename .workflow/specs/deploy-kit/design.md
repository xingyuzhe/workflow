# Module responsibility

`deploy-kit` owns safe full installation, artifact-only publication, rollback snapshots, exact ownership, strict JSON configuration, and consistent integrity orchestration.

# Structure and interfaces

- Preflight functions are read-only and run before target mutation.
- Target snapshots cover workflow-owned paths touched by each mode and restore them on caught failures.
- Full installation supplies Cursor contracts and Codex adapters; artifact publication supplies only the built Codex runtime plus project data/schema.
- Source and Artifact Doctors delegate local health to the validated repository runtime, then add source-equivalence checks.

# Relationships

`workflow-cli` owns selected-schema and main-spec validity. `deploy-kit` owns source/generated equivalence and target mutation safety.
