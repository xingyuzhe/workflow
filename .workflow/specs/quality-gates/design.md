# quality-gates Design

## Responsibility

Define evidence required to claim work complete without dictating how the work is performed.

## Structure

```text
.workflow/pack/gates/acceptance.md
```

## Interface

Apply and verify load the acceptance contract. Other operations carry their own output-specific acceptance criteria.

## Relationships

- Project rules and active artifacts can add narrower methods when the domain requires them.
- Doctor rejects superseded method gates in the neutral source.
