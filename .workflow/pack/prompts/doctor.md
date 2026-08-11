# Doctor

Run the workflow doctor script and report results:

```powershell
pwsh -File scripts/doctor.ps1
```

Doctor is read-only by default. Non-zero exit = unhealthy. Report drift without editing it; when the user authorizes repair, run `pwsh -File scripts/doctor.ps1 -Fix` and report the subsequent strict result.
