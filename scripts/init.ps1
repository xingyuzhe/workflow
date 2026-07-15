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
  Write-Error "Refusing to run without -Yes (destructive: purges workflow skills, overwrites config.workflow.yaml / opsx commands; never overwrites config.project.yaml)."
  exit 2
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir 'lib/WorkflowDeploy.psm1') -Force

$Target = Resolve-WorkflowPath -Path $Target
if (-not $Source) {
  $Source = Split-Path -Parent $scriptDir
}
$Source = Resolve-WorkflowPath -Path $Source

if (-not (Test-Path -LiteralPath $Target)) {
  Write-Host "Target does not exist yet; will create: $Target" -ForegroundColor Yellow
}

Write-Host "Workflow init"
Write-Host "  Source: $Source"
Write-Host "  Target: $Target"
Install-WorkflowV2 -SourceRoot $Source -TargetRoot $Target

$doctor = Invoke-WorkflowDoctor -ProjectRoot $Target
if ($doctor.ExitCode -ne 0) {
  Write-Host "Doctor FAILED:" -ForegroundColor Red
  $doctor.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit $doctor.ExitCode
}

Write-Host "Doctor OK. Workflow installed at: $Target" -ForegroundColor Green
exit 0
