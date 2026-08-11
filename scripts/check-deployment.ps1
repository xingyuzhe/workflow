param(
  [Parameter(Mandatory)][string]$Target,
  [string]$Source=(Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/WorkflowDeploy.psm1') -Force
$Source=Resolve-WorkflowPath $Source
$Target=Resolve-WorkflowPath $Target
$result=Invoke-WorkflowArtifactDoctor -ProjectRoot $Target -SourceRoot $Source
if($result.ExitCode -eq 0){
  Write-Host "Artifact Doctor OK: $Target" -ForegroundColor Green
  exit 0
}
$result.Errors|ForEach-Object{Write-Host "  - $_" -ForegroundColor Red}
exit $result.ExitCode
