# Context

The repository already owns lifecycle contracts and deployment logic, but it delegates authoritative artifact state and archive operations to an unrelated external CLI. Product naming and executable semantics are therefore inconsistent with the intended custom system.

# Goals / Non-Goals

## Goals

- One name: `workflow`.
- No package installation, download, Node, npm, npx, or external lifecycle CLI dependency.
- Deterministic local status, instructions, validation, sync, and archive behavior.
- One generated Codex runtime artifact with source ownership retained in this repository.

## Non-Goals

- General OpenSpec compatibility.
- A general YAML implementation.
- Downstream rollout in this change.
- Backward-compatible aliases or dual-read paths.

# Decisions

- The source runtime lives under `.workflow/cli`; build publishes it to `.agents/skills/workflow/bin`.
- Project configuration, schema, changes, and specs live under `.workflow`; source-only pack and CLI directories are not published as a second runtime.
- The CLI uses PowerShell and built-in .NET only, matching the existing engine without adding a package runtime.
- Machine-readable schema metadata uses JSON; human-authored project configuration retains the existing constrained YAML format.
- Lifecycle contracts invoke the exact repository-local CLI path. Missing CLI is deployment corruption and MUST NOT trigger installation.
- Repository files are authoritative. Optional cache/state never overrides them.
- The local implementation uses the upstream CLI only as a behavior reference for dependency states, schema resolution, validation boundaries, and failure atomicity. It remains an independent PowerShell implementation and does not import upstream code or packages.
- Generated JSON uses one compact canonical representation so Windows PowerShell and PowerShell 7 produce byte-identical artifacts.

# Risks / Trade-offs

PowerShell remains a runtime prerequisite. The CLI intentionally supports only this workflow's contract rather than upstream formats. The breaking namespace migration requires a deliberate downstream rollout later.
