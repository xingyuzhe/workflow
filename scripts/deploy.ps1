param(
  [Parameter(Mandatory)][string]$Target,
  [string]$Source=(Split-Path -Parent $PSScriptRoot),
  [switch]$Yes,
  [switch]$Json
)

$ErrorActionPreference='Stop'
if(-not $Yes){Write-Error 'Refusing to publish without -Yes.';exit 2}
Import-Module (Join-Path $PSScriptRoot 'lib/WorkflowDeploy.psm1') -Force
$Source=Resolve-WorkflowPath $Source;$Target=Resolve-WorkflowPath $Target
$report=Publish-WorkflowCodexArtifact -SourceRoot $Source -TargetRoot $Target
$result=Invoke-WorkflowArtifactDoctor -ProjectRoot $Target -SourceRoot $Source
if($Json){
  $artifact=Get-Content -LiteralPath (Join-Path $Target '.agents/skills/workflow/artifact.json') -Raw|ConvertFrom-Json
  [ordered]@{
    target=$Target.Replace('\','/')
    version="$($artifact.version)"
    migrated=@($report.Migrated)
    removed=@($report.Removed)
    preserved=@($report.Preserved)
    blocked=@($report.Blocked)
    doctorValid=($result.ExitCode -eq 0)
  }|ConvertTo-Json -Depth 5 -Compress
}else{
  Write-Host "Migration: $(@($report.Migrated).Count) migrated, $(@($report.Removed).Count) removed, $(@($report.Preserved).Count) preserved, $(@($report.Blocked).Count) blocked"
  if($result.ExitCode -eq 0){Write-Host "Codex artifact published: $Target" -ForegroundColor Green}
}
if($result.ExitCode -ne 0){if(-not $Json){$result.Errors|ForEach-Object{Write-Host "  - $_" -ForegroundColor Red}};exit $result.ExitCode}
