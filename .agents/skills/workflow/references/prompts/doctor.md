# Doctor contract

## Interface

- Published repositories do not contain source-only `.workflow/pack`, `.workflow/cli`, or deployment scripts.
- Local artifact integrity and project workflow data MUST be checked with `.agents/skills/workflow/bin/workflow.ps1 doctor`.
- Artifact metadata MAY be inspected under `.agents/skills/workflow`.
- When the workflow source repository is available, run its read-only checker: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <workflow-source>/scripts/check-deployment.ps1 -Target <project>`.
- Installation or repair uses the publisher-owned `deploy.ps1` and requires explicit authorization.

## Outputs

- Artifact metadata and manifest integrity result.
- Source-to-published artifact comparison when the source repository is available.
- Actionable failures, including any validation dimension unavailable without the source repository.

## Acceptance

- Exit code zero from the source-owned checker means the publication contract passes.
- Local-only inspection MUST distinguish verified integrity from source equivalence that was not checked.
- Non-zero results remain reported as unhealthy; do not claim repair success.

## Authority

- Diagnosis is read-only.
- Do not recreate source-only `.workflow/pack`, `.workflow/cli`, `scripts/init.ps1`, `scripts/doctor.ps1`, or the deployment module in a downstream repository.
- Never install or invoke an external lifecycle CLI or package.
- Run the publisher-owned deployment only when the user authorized repair or installation.
