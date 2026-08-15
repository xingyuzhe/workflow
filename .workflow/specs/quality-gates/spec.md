# quality-gates Specification

## Purpose

Require evidence for completion claims without prescribing generic implementation methods.

## Requirements

### Requirement: Evidence before completion
Before marking a task complete or reporting a lifecycle operation successful, the agent SHALL obtain evidence appropriate to the changed behavior and risk. The workflow SHALL require the evidence and result, but SHALL NOT mandate TDD, a fixed debugging sequence, test cadence, or retry count.

#### Scenario: Automated verification is available
- **WHEN** relevant automated checks exist
- **THEN** the agent MUST run the relevant checks and report their result before claiming completion

#### Scenario: Automated verification is unavailable
- **WHEN** no relevant automated check exists
- **THEN** the agent MUST record another concrete check or state the unverified residual explicitly

#### Scenario: Verification fails
- **WHEN** a relevant verification check fails
- **THEN** the affected task or operation MUST remain incomplete unless the user explicitly accepts the residual risk

### Requirement: Method policy belongs to the project
Shared workflow quality contracts SHALL NOT prescribe generic implementation or debugging methods. A project MAY require a specific method through project rules, active change artifacts, or tool protocols.

#### Scenario: Project requires TDD
- **WHEN** a project rule explicitly requires test-first development for the affected files
- **THEN** the agent MUST follow that project rule without the shared workflow duplicating it

### Requirement: Acceptance contract is not a skill framework
The evidence contract SHALL be delivered as a short neutral gate referenced only by operations that complete or verify work. Deployments SHALL contain `gates/acceptance.md` and SHALL NOT contain workflow-owned `tdd.md`, `debug.md`, or `verify.md` gates.

#### Scenario: Deployed gate layout
- **WHEN** a project is initialized or repaired
- **THEN** its generated workflow references MUST contain `acceptance.md` and no superseded method gates
