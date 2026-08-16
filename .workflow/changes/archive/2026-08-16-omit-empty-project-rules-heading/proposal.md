## Why

Codex-only publication into a repository without project rules produces an empty `### Project rules` heading in the managed AGENTS block. The heading implies configured guidance that does not exist and makes a clean first install noisier than its source contract.

## What Changes

- Normalize null and empty rule input before rendering AGENTS guidance.
- Omit the project-rules section unless at least one concrete rule entry exists.
- Add a first-install regression assertion for an empty project.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `deploy-kit`: Managed AGENTS guidance omits an empty project-rules section.

## Impact

AGENTS managed-block generation and deployment regression tests. No runtime dependency or migration change.

## Non-goals

- Changing rule discovery, rule ordering, or rule content.
- Changing any content outside the managed AGENTS block.
