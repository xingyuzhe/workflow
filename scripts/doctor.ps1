<#
.SYNOPSIS
  Validate Workflow v2 install in a project.
#>
param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir 'lib/WorkflowDeploy.psm1') -Force

$result = Invoke-WorkflowDoctor -ProjectRoot $ProjectRoot
if ($result.ExitCode -eq 0) {
  Write-Host "Doctor OK: $ProjectRoot" -ForegroundColor Green
  exit 0
}

Write-Host "Doctor FAILED: $ProjectRoot" -ForegroundColor Red
$result.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
exit $result.ExitCode
