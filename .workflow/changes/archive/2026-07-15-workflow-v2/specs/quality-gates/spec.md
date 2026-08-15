## ADDED Requirements

### Requirement: TDD gate for logic changes
When implementing a task that changes code logic (not pure docs/config/rename/version bump), the agent SHALL follow RED-GREEN-REFACTOR: write a failing test first, implement the minimum to pass, then refactor while green. When unsure whether TDD applies, the agent MUST ask the user before proceeding.

#### Scenario: Logic task
- **WHEN** a task adds or changes behavioral code
- **THEN** the agent MUST produce a failing test before implementation code that makes it pass

#### Scenario: Docs-only task
- **WHEN** a task only updates documentation
- **THEN** the TDD gate MUST NOT be required

### Requirement: Verification before completion
Before marking any task checkbox complete (`[ ]` → `[x]`), the agent MUST capture runtime evidence that the task succeeded (test output or recorded manual verification). Phrases such as "should be fine" or "looks correct" without evidence SHALL NOT be accepted as completion.

#### Scenario: Mark task done
- **WHEN** the agent is about to check off a task
- **THEN** it MUST have already run relevant verification and retained evidence in the session output

### Requirement: Systematic debugging on failure
On errors, test failures, or unexpected behavior during apply, the agent SHALL NOT apply random fixes. It MUST reproduce, form a hypothesis, validate with a minimal check, then fix. After three failed fix attempts on the same issue, the agent MUST pause and report, suggesting artifact updates if the issue appears design-level.

#### Scenario: Test failure during apply
- **WHEN** a test fails while implementing a task
- **THEN** the agent MUST enter the debug gate sequence before further speculative code changes

### Requirement: Gates are not a skill framework
Quality gates SHALL be delivered as short markdown gate files referenced by the apply prompt. The v2 runtime SHALL NOT require installing a Superpowers skill directory for TDD, verification, or debugging.

#### Scenario: Deployed project contents
- **WHEN** a project is initialized with v2 deploy-kit defaults
- **THEN** quality behavior MUST be available via pack gates without `.cursor/skills/superpowers/test-driven-development`
