## Context

The workflow is both a source repository and the producer of a single Codex runtime artifact. Review probes showed that its positive tests did not cover mutation rollback, namespace collisions, delta rename collisions, or equivalence gaps between three Doctor entry points.

## Goals / Non-Goals

**Goals:**

- Make expected installation and publication failures leave target repositories unchanged.
- Make every accepted delta semantically unambiguous and repeatable.
- Make every Doctor entry point agree on local artifact, schema, and spec health.
- Keep configuration and schema parsing self-contained and explicit.
- Make the two deployment modes obvious to first-time users.

**Non-Goals:**

- Preserve compatibility with the former YAML-like configuration filenames.
- Provide filesystem transactions across machine failure or concurrent external writes.
- Add generic implementation methods to lifecycle prompts.

## Decisions

1. Configuration becomes strict JSON: `config.workflow.json`, `config.project.json`, and generated `config.json`. Unknown fields and invalid rule shapes fail explicitly.
2. Schema artifacts declare `kind`. Capability delta artifacts also declare `publishPath`. Runtime behavior selects artifacts by kind, never by the IDs `specs` or `tasks`.
3. Delta merge performs a semantic preflight against the current main spec. Idempotent replay is allowed only when the resulting accepted content is already equivalent.
4. Full install and artifact-only publish validate all known inputs before mutation and snapshot every owned target subtree they may change. A caught failure restores the snapshot.
5. Workflow ownership is exact or manifest-based. A generic `workflow-*` project skill is never deleted merely because of its prefix.
6. Artifact file-set, hash, selected-schema, and main-spec checks are shared by invoking the validated repository-local runtime from source and artifact Doctors.
7. `init.ps1` is documented as the full Cursor+Codex/source-layout installer; `deploy.ps1` is the default Codex artifact-only downstream publisher.

## Risks / Trade-offs

- Snapshot rollback costs temporary disk space proportional to the workflow-owned target subtrees.
- JSON is less comment-friendly than YAML but is deterministic and available in both supported PowerShell runtimes without dependencies.
- Strict delta semantics may reject formerly tolerated ambiguous changes; this is intentional because the project does not require backward compatibility.
