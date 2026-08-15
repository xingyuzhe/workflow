# Why

The current custom lifecycle still names the upstream OpenSpec product and declares its CLI authoritative. Agents therefore attempt to install an external package when the command is absent. The workflow must be self-contained, locally executable, and unambiguously owned by this repository.

# What Changes

- **BREAKING**: Rename the live runtime, skill, commands, configuration, schemas, changes, and specs to the single `workflow` namespace.
- **BREAKING**: Replace external OpenSpec status/instructions/sync/archive behavior with a repository-owned local `workflow.ps1` CLI.
- Publish the CLI inside the sole Codex workflow artifact and require exact local-path invocation.
- Remove external CLI discovery, NVM scanning, install/download guidance, compatibility aliases, and superseded live paths.
- Preserve configuration, schema, artifact dependency, validation, synchronization, and archive capabilities under repository ownership.

# Capabilities

## New Capabilities

- `workflow-cli`

## Modified Capabilities

- `workflow-runtime`
- `schema-pack`
- `deploy-kit`

# Impact and Non-goals

This is workflow version 5.0.0. It changes all live lifecycle entry points and paths. Historical Git commits remain history, but no runtime compatibility layer is retained. Deploying 5.0.0 to downstream repositories is explicitly outside this change.
