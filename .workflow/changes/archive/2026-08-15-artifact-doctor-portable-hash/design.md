# Context

Git may materialize the same tracked text with platform-specific line endings. Raw byte hashes therefore contradict the workflow's cross-platform publishing contract.

# Goals / Non-Goals

## Goals

- Make artifact integrity checks independent of LF/CRLF checkout policy.
- Preserve detection of substantive content drift.

## Non-Goals

- Supporting binary files in the workflow skill artifact.
- Changing artifact layout, version, or downstream ownership.

# Decisions

- Hash canonical UTF-8 text after replacing CRLF and lone CR with LF.
- Use one helper at every artifact hash boundary to avoid build/check disagreement.
- Publish artifact metadata version 4.0.2 because canonical manifest hashes replace the previous raw-byte values.

# Risks / Trade-offs

Line-ending-only mutations are intentionally ignored. This matches Git's text semantics and does not hide other character changes.
