# Doctor

Run the workflow doctor script and report results:

```powershell
pwsh -File scripts/doctor.ps1
```

Doctor **auto-syncs** `openspec/config.yaml` from `config.workflow.yaml` + `config.project.yaml` before checks (no token-heavy merge in the model). Non-zero exit = unhealthy. Fix failures before claiming deploy success.
