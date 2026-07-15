## ADDED Requirements

### Requirement: Command-driven entry points
The workflow runtime SHALL expose Cursor commands under `/opsx:*` that map 1:1 to pack prompts. Loading a command SHALL instruct the agent to read the mapped prompt file before acting. The runtime SHALL NOT require a Superpowers or OpenSpec skill tree for primary lifecycle actions.

#### Scenario: User runs apply
- **WHEN** the user invokes `/opsx:apply`
- **THEN** the agent MUST load the apply pack prompt and referenced quality gates before implementing tasks

#### Scenario: Intent without command
- **WHEN** the user says "start coding" without a command
- **THEN** the router MAY map the intent to apply, and MUST still load the apply pack prompt (not a skill path)

### Requirement: Single alwaysApply router
The runtime SHALL provide exactly one always-applied workflow router rule. Legacy bootstrap rules SHALL NOT be always-applied and SHALL NOT remain after a successful v2 init.

#### Scenario: After init
- **WHEN** v2 init completes
- **THEN** routing MUST work via the v2 router alone, without `superpowers-bootstrap.mdc`

### Requirement: Phase state file (phased)
Through milestone M2, the agent SHOULD read `.cursor/workflow/state.json` when present and MUST treat `openspec status` as authoritative. From milestone M3 onward, the runtime SHALL maintain `state.json` with at least `active_change`, `phase`, `branch`, and `updated_at` (gitignored). Missing `state.json` before M3 MUST NOT block apply. When state conflicts with `openspec status --json`, the CLI result SHALL win and state SHOULD be refreshed.

#### Scenario: Resume with optional state (pre-M3)
- **WHEN** the user continues a change and `state.json` is absent
- **THEN** the agent MUST proceed using `openspec status` without failing solely due to missing state

#### Scenario: Resume with state
- **WHEN** `state.json` is present
- **THEN** the agent MUST reconcile it with `openspec status` before choosing the next action

### Requirement: Isomorphic pack layout
Source and deployed layouts SHALL use the same paths under `.cursor/workflow/pack/` for prompts and gates. Versioned skill directories (`superpowers-v*`, `openspec-v*`) SHALL NOT be part of the v2 runtime layout.

#### Scenario: Resolve apply prompt
- **WHEN** the agent resolves the apply prompt in the workflow source repo or a deployed project
- **THEN** it MUST succeed via `.cursor/workflow/pack/` without versioned skill directories

### Requirement: Branch and finish short prompts
The runtime SHALL provide short pack prompts for branching and finishing a change branch. These prompts SHALL NOT be quality gates at the same severity as TDD/verify/debug.

#### Scenario: Start of change work
- **WHEN** the user starts a new change via `/opsx:new` or equivalent
- **THEN** the agent MUST follow the branch short prompt (default `change/<name>` unless the prompt specifies otherwise)

#### Scenario: After archive
- **WHEN** archive completes
- **THEN** the agent MUST load or inline the finish short prompt options (merge / PR / discard)
