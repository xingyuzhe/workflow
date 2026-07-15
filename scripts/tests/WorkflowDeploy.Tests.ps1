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

  $r2 = Invoke-WorkflowDoctor -ProjectRoot $proj
  if ($r2.ExitCode -ne 0) { $r2.Errors | ForEach-Object { Write-Host "  doctor: $_" } }
  Assert-True ($r2.ExitCode -eq 0) "doctor passes after install"

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
