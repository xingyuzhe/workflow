## 1. Contracts and configuration

- [x] 1.1 Add artifact kinds and publication targets to the schema and make CLI behavior role-driven.
- [x] 1.2 Replace YAML-like configuration with strict JSON parsing, merging, generation, and documentation.

## 2. Lifecycle correctness

- [x] 2.1 Reject duplicate and conflicting ADDED, MODIFIED, REMOVED, and RENAMED operations before sync writes.
- [x] 2.2 Preserve repeatable sync only when the already-published result is equivalent.

## 3. Deployment safety

- [x] 3.1 Replace prefix ownership with exact/managed ownership and preserve unrelated workflow-prefixed project assets.
- [x] 3.2 Preflight installation/publication inputs and restore owned target paths after a caught mutation failure.
- [x] 3.3 Strengthen legacy deployment-script provenance before deletion.

## 4. Doctor consistency

- [x] 4.1 Validate complete artifact file sets, metadata, manifest hashes, selected schema, main spec syntax, and source/generated CLI equivalence.
- [x] 4.2 Make source Doctor, Artifact Doctor, and local CLI Doctor agree on isolated drift probes.

## 5. Documentation and accepted specs

- [x] 5.1 Separate full installation from Codex artifact-only publication in README and architecture documentation.
- [x] 5.2 Remove accepted-spec placeholders and stale repair instructions.

## 6. Verification

- [x] 6.1 Add regression tests for rollback, ownership collisions, delta conflicts, custom schema roles, and Doctor false positives.
- [x] 6.2 Pass the complete suite under Windows PowerShell 5.1 and PowerShell 7 with deterministic generated artifacts and a clean worktree.
