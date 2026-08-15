# workflow-cli Specification

## Purpose

Define the accepted workflow-cli behavior.

### Requirement: Repository-owned local CLI
The workflow SHALL publish a repository-owned CLI that runs from an exact local path using PowerShell and built-in .NET only. It MUST NOT discover, install, download, or invoke an external lifecycle CLI or package manager.

#### Scenario: External tools are absent
- **WHEN** external lifecycle tools and package runtimes are unavailable
- **THEN** every supported workflow CLI command MUST remain operational

#### Scenario: Local CLI is missing
- **WHEN** the published local CLI path does not exist
- **THEN** the workflow MUST report an invalid installation and MUST NOT attempt network installation

### Requirement: Local lifecycle commands
The CLI SHALL provide `new`, `status`, `instructions`, `validate`, `sync`, `archive`, and `doctor` commands with deterministic JSON output where requested.

#### Scenario: Determine apply readiness
- **WHEN** status evaluates a change containing all required artifacts and complete capability pairs
- **THEN** it MUST report the change as apply-ready without consulting external state

#### Scenario: Archive completed work
- **WHEN** archive receives a validated change with completed tasks
- **THEN** it MUST synchronize accepted deltas and move the change into the local archive
