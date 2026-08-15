# Why

Artifact Doctor hashes raw bytes, so Git checkout line-ending conversion makes identical text appear corrupt on Windows. The source-owned checker must remain reliable across repositories using LF or CRLF worktrees.

# What Changes

- Normalize text line endings before computing or comparing workflow artifact hashes.
- Keep all non-line-ending content differences detectable.
- Add regression coverage for a published artifact checked out with CRLF.

# Capabilities

## Modified Capabilities

- `deploy-kit`

# Impact and Non-goals

The change affects workflow artifact hashing, manifest values, and Doctor comparisons. It publishes workflow artifact version 4.0.2 without changing the downstream namespace, file set, or deployment behavior.
