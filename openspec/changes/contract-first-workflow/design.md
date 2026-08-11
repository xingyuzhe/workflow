# Contract-first workflow design

## Context

The platform-neutral v3 source is working, but its content still reflects a method-oriented agent framework. The same invariants are repeated in schema instructions, config rules, skill routing, and operation prompts. Generic TDD and debugging recipes are mandatory even when another verification strategy is more appropriate.

## Goals / Non-Goals

**Goals**

- Make lifecycle state, artifact outputs, acceptance, stop conditions, and authority the workflow contract.
- Keep exact instructions only where a parser, tool interface, or safety boundary requires them.
- Keep `.workflow/pack` as the neutral source and generated adapters thin.
- Make deterministic invariants executable through Doctor/tests.

**Non-Goals**

- Standardizing how an agent reasons or writes code.
- Adding compatibility paths for the old gate names.
- Encoding project-specific implementation practices in the shared workflow.

## Decisions

### D1: Operation contracts replace procedural recipes

Each operation prompt uses the same conceptual fields: Preconditions, Inputs, Outputs, Acceptance, Stop conditions, and Authority where relevant. The agent chooses the method unless another contract explicitly constrains it.

### D2: One evidence contract replaces TDD/debug gates

`gates/acceptance.md` requires evidence proportional to risk before completion and forbids claiming success after failed checks. TDD, debugging sequence, test cadence, and retry counts are not workflow policy; projects may add them as project rules.

### D3: Schema owns artifact semantics

`schema.yaml` owns artifact dependencies, required sections, exact parser-sensitive syntax, and artifact ownership. `config.workflow.yaml` only carries short cross-artifact invariants that OpenSpec exposes at generation time. Operation prompts reference those contracts instead of restating them.

### D4: Design is always present

Because `tasks` depends on `design`, change-level `design.md` is required. A small change may explicitly record that no cross-cutting decision exists; the schema no longer describes design as optional.

### D5: Routing is lifecycle-scoped

The shared skill triggers for explicit lifecycle intent, OpenSpec artifacts, active-change implementation, Doctor, and failures inside those operations. Ordinary bugs and test failures do not automatically enter the OpenSpec workflow.

### D6: Doctor enforces the deployed contract

Doctor checks canonical-to-generated drift, the required acceptance gate layout, absence of superseded method gates, artifact pairs, schema presence, config generation, metadata, and client adapters.

## Risks / Trade-offs

- Less prescriptive prompts can expose weak project-level verification practices. Mitigation: acceptance still requires concrete evidence, and projects can add targeted rules.
- Existing installations retain old files until explicit init/repair. Mitigation: deployment removes managed reference trees before copying and Doctor reports superseded source gates.
- Concise schema instructions offer fewer examples. Mitigation: keep every parser-sensitive heading and syntax rule explicit.
