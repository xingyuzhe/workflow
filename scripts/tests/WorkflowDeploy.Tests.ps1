# WorkflowDeploy.Tests.ps1 — minimal harness (no Pester required)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here '..\..')).Path
Import-Module (Join-Path $here '..\lib\WorkflowDeploy.psm1') -Force

$failed = 0
function Assert-True($cond, $msg) {
  if (-not $cond) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:failed++ }
  else { Write-Host "PASS: $msg" -ForegroundColor Green }
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("wf-deploy-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $skills = Join-Path $tmp 'skills'
  New-Item -ItemType Directory -Path (Join-Path $skills 'superpowers-v6.1.1') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'openspec-v1.5.0') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'grilling') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'workflow') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'my-other-skill') | Out-Null

  $found = @(Get-WorkflowNamespaceSkillDirs -SkillsRoot $skills)
  Assert-True ($found.Count -eq 4) "finds 4 namespace skill dirs"
  Assert-True (-not ($found | Where-Object { $_.Name -eq 'my-other-skill' })) "ignores unrelated skills"

  Remove-WorkflowNamespaceSkills -SkillsRoot $skills
  Assert-True (-not (Test-Path (Join-Path $skills 'superpowers-v6.1.1'))) "purges superpowers"
  Assert-True (Test-Path (Join-Path $skills 'my-other-skill')) "keeps unrelated skills"

  $rules = Join-Path $tmp 'rules'
  $commands = Join-Path $tmp 'commands'
  New-Item -ItemType Directory -Path $rules, $commands | Out-Null
  Set-Content (Join-Path $commands 'opsx-apply.md') 'old'
  Set-Content (Join-Path $commands 'opsx-new.md') 'old'
  Set-Content (Join-Path $commands 'user-cmd.md') 'keep'
  New-Item -ItemType Directory -Path (Join-Path $rules 'superpowers-v6.1.1') | Out-Null
  Set-Content (Join-Path $rules 'superpowers-v6.1.1\superpowers-bootstrap.mdc') 'old'
  Set-Content (Join-Path $rules 'superpowers-v6.1.1\superpowers-router.mdc') 'old'
  Set-Content (Join-Path $rules 'my-company.mdc') 'keep'

  Remove-WorkflowOwnedEntries -RulesRoot $rules -CommandsRoot $commands
  Assert-True (-not (Test-Path (Join-Path $commands 'opsx-apply.md'))) "removes opsx-apply"
  Assert-True (Test-Path (Join-Path $commands 'user-cmd.md')) "keeps user command"
  Assert-True (-not (Test-Path (Join-Path $rules 'superpowers-v6.1.1'))) "removes superpowers rules dir"
  Assert-True (Test-Path (Join-Path $rules 'my-company.mdc')) "keeps user rule"

  # install into disposable project from real source; seed legacy skill then expect doctor fail then pass after purge
  $proj = Join-Path $tmp 'proj'
  New-Item -ItemType Directory -Force -Path (Join-Path $proj '.cursor\skills\openspec-v1.5.0') | Out-Null
  Set-Content (Join-Path $proj '.cursor\skills\openspec-v1.5.0\SKILL.md') 'legacy'
  New-Item -ItemType Directory -Force -Path (Join-Path $proj 'openspec\specs\keep-me') | Out-Null
  Set-Content (Join-Path $proj 'openspec\specs\keep-me\spec.md') 'business spec stays'

  # doctor on incomplete project fails
  $r0 = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($r0.ExitCode -ne 0) "doctor fails on incomplete project"

  Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $proj
  Assert-True (-not (Test-Path (Join-Path $proj '.cursor\skills\openspec-v1.5.0'))) "install purges legacy skills"
  Assert-True (Test-Path (Join-Path $proj 'openspec\specs\keep-me\spec.md')) "preserves business specs"
  Assert-True (Test-Path (Join-Path $proj '.cursor\workflow\pack\prompts\apply.md')) "installs apply prompt"

  # business capability must be paired for doctor; preserve both files across install
  Set-Content (Join-Path $proj 'openspec\specs\keep-me\design.md') 'business design stays'
  $r2 = Invoke-WorkflowDoctor -ProjectRoot $proj
  if ($r2.ExitCode -ne 0) { $r2.Errors | ForEach-Object { Write-Host "  doctor: $_" } }
  Assert-True ($r2.ExitCode -eq 0) "doctor passes after install"
  Assert-True (Test-Path (Join-Path $proj 'openspec\specs\keep-me\design.md')) "preserves business design"

  # unpaired main spec → doctor fails
  Remove-Item -Force (Join-Path $proj 'openspec\specs\keep-me\design.md')
  $rPair = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($rPair.ExitCode -ne 0) "doctor fails when design.md missing"
  Assert-True (($rPair.Errors -join ' ') -match 'design\.md') "doctor mentions missing design.md"
  Set-Content (Join-Path $proj 'openspec\specs\keep-me\design.md') 'business design stays'

  # Git Bash style paths must map to Windows drive roots
  Assert-True ((Resolve-WorkflowPath '/d/work/bill') -eq 'D:\work\bill') "maps /d/work/bill to D:\work\bill"
  Assert-True ((Resolve-WorkflowPath '/c/Users/wps') -eq 'C:\Users\wps') "maps /c/Users/wps"
  Assert-True ((Resolve-WorkflowPath 'D:/work/bill') -eq 'D:\work\bill') "normalizes D:/work/bill"
  Assert-True ((Resolve-WorkflowPath 'D:\work\bill') -eq 'D:\work\bill') "keeps Windows path"

  # --- config isolation merge ---
  $cfgDir = Join-Path $tmp 'cfg'
  New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
  $wfOnly = Join-Path $cfgDir 'workflow-only.yaml'
  $projRules = Join-Path $cfgDir 'project-rules.yaml'
  $out1 = Join-Path $cfgDir 'out1.yaml'
  @(
    'schema: workflow-spec',
    'rules:',
    '  proposal:',
    '    - Own Why only',
    '  specs:',
    '    - Both spec and design'
  ) | Set-Content -Encoding utf8 $wfOnly
  Merge-WorkflowOpenSpecConfig -WorkflowPath $wfOnly -ProjectPath $null -OutPath $out1
  $o1 = Get-Content -Raw $out1
  Assert-True ($o1 -match 'schema:\s*workflow-spec') "merge workflow-only keeps schema"
  Assert-True ($o1 -match 'Own Why only') "merge workflow-only keeps rules"
  Assert-True ($o1 -match 'AUTO-GENERATED|DO NOT EDIT') "merged file has generated banner"

  @(
    'schema: custom-schema',
    'rules:',
    '  proposal:',
    '    - Own Why only',
    '    - Project private rule',
    '  design:',
    '    - Project design rule'
  ) | Set-Content -Encoding utf8 $projRules
  $out2 = Join-Path $cfgDir 'out2.yaml'
  Merge-WorkflowOpenSpecConfig -WorkflowPath $wfOnly -ProjectPath $projRules -OutPath $out2
  $o2 = Get-Content -Raw $out2
  Assert-True ($o2 -match 'schema:\s*custom-schema') "project schema overrides"
  Assert-True ($o2 -match 'Project private rule') "project rules appended"
  Assert-True (($o2 -split 'Own Why only').Count -eq 2) "dedupes repeated rule text"

  # install: never overwrite project config; migrate bare config.yaml once
  $proj2 = Join-Path $tmp 'proj2'
  New-Item -ItemType Directory -Force -Path (Join-Path $proj2 'openspec') | Out-Null
  @(
    'schema: old-project',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 'openspec\config.yaml')
  Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $proj2
  Assert-True (Test-Path (Join-Path $proj2 'openspec\config.workflow.yaml')) "writes config.workflow.yaml"
  Assert-True (Test-Path (Join-Path $proj2 'openspec\config.project.yaml')) "creates config.project.yaml via migrate"
  $projCfg1 = Get-Content -Raw (Join-Path $proj2 'openspec\config.project.yaml')
  Assert-True ($projCfg1 -match 'Keep my private rule forever') "migrated private rule into project file"
  $merged1 = Get-Content -Raw (Join-Path $proj2 'openspec\config.yaml')
  Assert-True ($merged1 -match 'Keep my private rule forever') "merged config includes private rule"
  Assert-True ($merged1 -match 'workflow-spec|Both spec|Own Why|create BOTH|Never leave') "merged includes workflow rules"

  @(
    'schema: workflow-spec',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever',
    '    - Second private line'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 'openspec\config.project.yaml')
  Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $proj2
  $projCfg2 = Get-Content -Raw (Join-Path $proj2 'openspec\config.project.yaml')
  Assert-True ($projCfg2 -match 'Second private line') "second install does not overwrite project config"

  # machine sync: project edit + stale config.yaml → Sync/doctor heals without init
  @(
    'schema: workflow-spec',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever',
    '    - DoctorAutoSyncRule'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 'openspec\config.project.yaml')
  @(
    'schema: workflow-spec',
    'rules:',
    '  proposal:',
    '    - stale merged only'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 'openspec\config.yaml')
  $sync1 = Sync-WorkflowOpenSpecConfig -ProjectRoot $proj2
  Assert-True ($sync1.Changed -eq $true) "sync merges when project changed"
  Assert-True ($sync1.Status -eq 'Merged') "sync status Merged"
  $healed = Get-Content -Raw (Join-Path $proj2 'openspec\config.yaml')
  Assert-True ($healed -match 'DoctorAutoSyncRule') "sync writes project rule into config.yaml"
  $sync2 = Sync-WorkflowOpenSpecConfig -ProjectRoot $proj2
  Assert-True ($sync2.Changed -eq $false) "second sync is no-op when up to date"
  Assert-True ($sync2.Status -eq 'Unchanged') "sync status Unchanged"

  @(
    'schema: workflow-spec',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever',
    '    - DoctorAutoSyncRule',
    '    - ViaDoctorRule'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 'openspec\config.project.yaml')
  @(
    '# stale',
    'schema: workflow-spec',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 'openspec\config.yaml')
  $rDocSync = Invoke-WorkflowDoctor -ProjectRoot $proj2
  if ($rDocSync.ExitCode -ne 0) { $rDocSync.Errors | ForEach-Object { Write-Host "  doctor: $_" } }
  Assert-True ($rDocSync.ExitCode -eq 0) "doctor passes after auto-sync"
  $viaDoc = Get-Content -Raw (Join-Path $proj2 'openspec\config.yaml')
  Assert-True ($viaDoc -match 'ViaDoctorRule') "doctor auto-syncs project rules into config.yaml"

  # reintroduce legacy → doctor fails
  New-Item -ItemType Directory -Force -Path (Join-Path $proj '.cursor\skills\superpowers-v9') | Out-Null
  $r3 = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($r3.ExitCode -ne 0) "doctor fails when legacy skills remain"

  # self-install must not wipe source pack
  Assert-True (Test-Path (Join-Path $repoRoot '.cursor\workflow\pack\prompts\apply.md')) "repo pack exists before self-init"
  Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $repoRoot
  Assert-True (Test-Path (Join-Path $repoRoot '.cursor\workflow\pack\prompts\apply.md')) "self-init preserves pack"
  Assert-True (Test-Path (Join-Path $repoRoot '.cursor\commands\opsx-apply.md')) "self-init preserves opsx-apply"

} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { Write-Host "`n$failed failed" -ForegroundColor Red; exit 1 }
Write-Host "`nAll tests passed" -ForegroundColor Green
exit 0
