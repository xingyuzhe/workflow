# Contract-first workflow proposal

## Why

The shared workflow repeats artifact rules and prescribes generic reasoning methods that coding agents already possess. This increases context cost, creates drift, and constrains task-specific judgment without strengthening the delivery contract.

## What Changes

- **BREAKING** Replace method-oriented prompts and mandatory TDD/debug gates with operation contracts that define preconditions, inputs, outputs, acceptance criteria, stop conditions, and authorization boundaries.
- Narrow Codex skill and generated `AGENTS.md` routing to explicit OpenSpec lifecycle work and failures inside an active lifecycle operation.
- Make the workflow schema the single source of truth for artifact structure, ownership, dependencies, and parser-sensitive formatting.
- Move deterministic invariants to Doctor and deployment tests instead of repeating them across prompts and configuration.
- Remove superseded gate files and tutorial-style schema guidance.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `workflow-runtime`: Route lifecycle intent through compact operation contracts.
- `schema-pack`: Define a concise, internally consistent artifact contract.
- `quality-gates`: Replace mandated methods with evidence-based acceptance.

## Impact

The neutral prompt pack, Codex adapter, generated Cursor/Codex guidance, workflow schema, config template, Doctor checks, tests, and documentation change together. Existing deployments receive the new contract model on the next explicit initialization or repair.

## Non-goals

- Teaching a preferred coding, testing, debugging, or reasoning technique.
- Preserving compatibility with the superseded method-oriented gate layout.
- Replacing project-specific rules or test commands.
