param(
  [Parameter(Position=0)][string]$Command = 'help',
  [Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments,
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'WorkflowRuntime.psm1') -Force
try {
  $result = Invoke-RepositoryWorkflow -Command $Command -Arguments @($Arguments) -ProjectRoot $ProjectRoot
  if ($null -ne $result) { $result }
  exit 0
} catch {
  [Console]::Error.WriteLine($_.Exception.Message)
  exit 1
}
