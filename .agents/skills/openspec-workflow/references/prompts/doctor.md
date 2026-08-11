# Doctor contract

## Interface

- Read-only diagnosis: `pwsh -File scripts/doctor.ps1`
- Authorized repair: `pwsh -File scripts/doctor.ps1 -Fix`

## Outputs

- Health result and actionable failures.
- After repair, a second strict read-only result.

## Acceptance

- Exit code zero means the installation contract passes.
- Non-zero results remain reported as unhealthy; do not claim repair success.

## Authority

- Diagnosis is read-only.
- Run `-Fix` only when the user authorized repair or installation.
