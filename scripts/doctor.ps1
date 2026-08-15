<#
.SYNOPSIS
  Read-only validation of a full platform-neutral Workflow install.
#>
param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet('cursor','codex')][string[]]$Clients = @()
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir 'lib/WorkflowDeploy.psm1') -Force

$ProjectRoot = Resolve-WorkflowPath -Path $ProjectRoot
$result = Invoke-WorkflowDoctor -ProjectRoot $ProjectRoot -Clients $Clients
if ($result.ExitCode -eq 0) {
  Write-Host "Doctor OK: $ProjectRoot" -ForegroundColor Green
  exit 0
}

Write-Host "Doctor FAILED: $ProjectRoot" -ForegroundColor Red
$result.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
exit $result.ExitCode
