# Module responsibility

`workflow-cli` owns the lifecycle mutation coordinator used by sync and archive. It is responsible for exclusive writer access, strict transaction journals, staging, snapshots, commit order, rollback, interruption recovery, and read-only diagnostics.

# Data model

- `.workflow/.mutation.lock`: exclusive writer token held open for the mutation lifetime.
- `.workflow/.transactions/<guid>/journal.json`: strict phase and target manifest.
- `.workflow/.transactions/<guid>/original/<index>`: byte-for-byte original files or directories.
- `.workflow/.transactions/<guid>/prepared/<index>`: prepared replacement files or directories.

Journal targets are repository-relative and declare operation, prior existence, original location, and prepared location. Runtime validation rejects rooted paths, traversal, duplicates, unknown fields, invalid phases, and transaction paths outside the transaction root.

# Commit and recovery

The coordinator writes snapshots and prepared values, persists `prepared`, changes the phase to `committing`, applies targets, persists `committed`, then removes the transaction. A caught exception during `committing` restores all targets. Recovery applies the same phase rules before any later writer begins.
