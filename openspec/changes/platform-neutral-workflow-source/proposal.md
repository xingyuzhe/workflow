## Why

Workflow currently treats Cursor-owned files as canonical and derives Codex assets from them. This creates duplicate metadata and state, makes Codex support dependent on Cursor formats, and lets lossy adapter drift pass doctor checks.

## What Changes

- Introduce `.workflow/` as the only human-edited, platform-neutral source for workflow packs, project rules, MCP definitions, metadata, and state.
- Generate Cursor and Codex runtime files as owned adapter outputs.
- Replace marker-only doctor checks with read-only content validation and an explicit `-Fix` repair mode.
- Remove Cursor-to-Codex compatibility parsing and duplicate client metadata/state.

## Capabilities

### New Capabilities

- `platform-neutral-source`: Defines the canonical `.workflow` layout and strict client adapter contract.

### Modified Capabilities

- `deploy-kit`: Init generates both client layouts from `.workflow`; doctor becomes read-only by default with explicit repair.
- `workflow-runtime`: Prompts, gates, rules, MCP definitions, metadata, and state resolve from the neutral source.

## Impact

This is a breaking source-layout change affecting `scripts/lib/WorkflowDeploy.psm1`, init/doctor entrypoints, tests, runtime prompts, rules, MCP configuration, documentation, and downstream installations.
