## Context

The current doctor mutates merged OpenSpec configuration and validates only marker/file presence for several generated assets.

## Decisions

- Separate generation from validation.
- Build expected adapter text in memory and compare normalized UTF-8 content.
- `Invoke-WorkflowDoctor` never writes; `Repair-WorkflowInstall` performs explicit generation.
- `scripts/doctor.ps1 -Fix` calls repair first and strict doctor second.
- Init calls generation, then strict doctor.
