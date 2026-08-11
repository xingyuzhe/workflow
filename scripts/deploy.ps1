param(
  [Parameter(Mandatory)][string]$Target,
  [string]$Source=(Split-Path -Parent $PSScriptRoot),
  [switch]$Yes
)

$ErrorActionPreference='Stop'
if(-not $Yes){Write-Error 'Refusing to publish without -Yes.';exit 2}
Import-Module (Join-Path $PSScriptRoot 'lib/WorkflowDeploy.psm1') -Force
$Source=Resolve-WorkflowPath $Source;$Target=Resolve-WorkflowPath $Target
Publish-WorkflowCodexArtifact -SourceRoot $Source -TargetRoot $Target
$result=Invoke-WorkflowArtifactDoctor -ProjectRoot $Target -SourceRoot $Source
if($result.ExitCode -ne 0){$result.Errors|%{Write-Host "  - $_" -ForegroundColor Red};exit $result.ExitCode}
Write-Host "Codex artifact published: $Target" -ForegroundColor Green
