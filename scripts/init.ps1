<#
.SYNOPSIS
  Install the platform-neutral Workflow into a target project.
.PARAMETER Target
  Target project root. Defaults to current directory.
.PARAMETER Source
  Workflow source root (contains .workflow/pack). Defaults to repo containing this script.
.PARAMETER Yes
  Required non-interactive confirmation flag.
.PARAMETER Clients
  Client adapters to install. Defaults to cursor and codex.
#>
param(
  [string]$Target = (Get-Location).Path,
  [string]$Source = '',
  [ValidateSet('cursor','codex')][string[]]$Clients = @('cursor','codex'),
  [switch]$Yes
)

$ErrorActionPreference = 'Stop'
if (-not $Yes) {
  Write-Error "Refusing to run without -Yes (destructive: replaces exact workflow-owned skills, config.workflow.json, and workflow commands; never overwrites config.project.json)."
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
Write-Host "  Clients: $($Clients -join ', ')"
Install-Workflow -SourceRoot $Source -TargetRoot $Target -Clients $Clients

$doctor = Invoke-WorkflowDoctor -ProjectRoot $Target -Clients $Clients
if ($doctor.ExitCode -ne 0) {
  Write-Host "Doctor FAILED:" -ForegroundColor Red
  $doctor.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  exit $doctor.ExitCode
}

Write-Host "Doctor OK. Workflow installed at: $Target" -ForegroundColor Green
exit 0
