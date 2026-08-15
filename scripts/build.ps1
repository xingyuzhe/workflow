param([string]$Source=(Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'lib/WorkflowDeploy.psm1') -Force
$Source=Resolve-WorkflowPath $Source
Build-WorkflowCodexArtifact -SourceRoot $Source|Out-Null
Write-Host "Codex artifact built: $Source\.agents\skills\workflow" -ForegroundColor Green
