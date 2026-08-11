# Doctor contract

## Interface

- Published repositories do not contain the workflow source or deployment scripts.
- Local artifact integrity MAY be checked from `artifact.json` and `artifact-manifest.json` under `.agents/skills/openspec-workflow`.
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
- Do not expect or recreate `.workflow`, `scripts/init.ps1`, `scripts/doctor.ps1`, or the deployment module in a downstream repository.
- Run the publisher-owned deployment only when the user authorized repair or installation.
