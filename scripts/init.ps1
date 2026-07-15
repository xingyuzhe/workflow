<#
.SYNOPSIS
  Install Workflow v2 into a target project (destructive).
.PARAMETER Target
  Target project root. Defaults to current directory.
.PARAMETER Source
  Workflow source root (contains .cursor/workflow/pack). Defaults to repo containing this script.
.PARAMETER Yes
  Required non-interactive confirmation flag.
#>
param(
  [string]$Target = (Get-Location).Path,
  [string]$Source = '',
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
if (-not $Yes) {
  Write-Error "Refusing to run without -Yes (destructive: purges workflow skills, overwrites config.yaml and opsx commands)."
  exit 2
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Source) {
  $Source = Split-Path -Parent $scriptDir
}
Import-Module (Join-Path $scriptDir 'lib/WorkflowDeploy.psm1') -Force

Write-Host "Workflow v2 init"
Write-Host "  Source: $Source"
Write-Host "  Target: $Target"

Install-WorkflowV2 -SourceRoot $Source -TargetRoot $Target

$doctor = Invoke-WorkflowDoctor -ProjectRoot $Target
if ($doctor.ExitCode -ne 0) {
  Write-Host "Doctor FAILED:" -ForegroundColor Red
  $doctor.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit $doctor.ExitCode
}

Write-Host "Doctor OK. Workflow v2 installed." -ForegroundColor Green
exit 0
