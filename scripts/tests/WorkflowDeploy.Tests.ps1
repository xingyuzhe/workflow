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
function Assert-Throws([scriptblock]$Action, [string]$Pattern, [string]$msg) {
  try { & $Action; Assert-True $false $msg }
  catch { Assert-True ($_.Exception.Message -match $Pattern) $msg }
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
  New-Item -ItemType Directory -Force -Path (Join-Path $proj '.workflow\rules') | Out-Null
  @(
    '---',
    'description: Early project rule',
    'alwaysApply: true',
    '---',
    '',
    '# Early project rule',
    '',
    'Keep this project rule.'
  ) | Set-Content -Encoding utf8 (Join-Path $proj '.workflow\rules\early-project.md')
  @(
    '---',
    'description: Deployment project rule',
    'globs: src/deploy/**/*,docs/deploy/**/*',
    'alwaysApply: false',
    '---',
    '',
    '# Deployment project rule'
  ) | Set-Content -Encoding utf8 (Join-Path $proj '.workflow\rules\deployment-scope.md')
  @(
    '{',
    '  "schemaVersion": 1,',
    '  "servers": {',
    '    "example.mcp": {',
    '      "transport": "stdio",',
    '      "command": "npx",',
    '      "args": ["-y", "example-mcp"],',
    '      "env": { "EXAMPLE_MODE": "test" }',
    '    }',
    '  }',
    '}'
  ) | Set-Content -Encoding utf8 (Join-Path $proj '.workflow\mcp.json')
  @(
    '{',
    '  "schemaVersion": 1,',
    '  "rules": [',
    '    { "path": "early-project.md", "description": "Early project rule", "always": true, "paths": [] },',
    '    { "path": "deployment-scope.md", "description": "Deployment project rule", "always": false, "paths": ["src/deploy/**/*", "docs/deploy/**/*"] }',
    '  ]',
    '}'
  ) | Set-Content -Encoding utf8 (Join-Path $proj '.workflow\rules.json')
  Set-Content -Encoding utf8 (Join-Path $proj 'AGENTS.md') "# Project guidance`n`nKeep this custom guidance.`n"
  New-Item -ItemType Directory -Force -Path (Join-Path $proj 'openspec\specs\keep-me') | Out-Null
  Set-Content (Join-Path $proj 'openspec\specs\keep-me\spec.md') 'business spec stays'

  # doctor on incomplete project fails
  $r0 = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($r0.ExitCode -ne 0) "doctor fails on incomplete project"

  Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $proj
  Assert-True (-not (Test-Path (Join-Path $proj '.cursor\skills\openspec-v1.5.0'))) "install purges legacy skills"
  Assert-True (Test-Path (Join-Path $proj 'openspec\specs\keep-me\spec.md')) "preserves business specs"
  Assert-True (Test-Path (Join-Path $proj '.workflow\pack\prompts\apply.md')) "installs neutral apply prompt"
  Assert-True (-not (Test-Path (Join-Path $proj '.cursor\workflow\pack'))) "removes superseded Cursor pack"
  Assert-True (Test-Path (Join-Path $proj '.agents\skills\openspec-workflow\SKILL.md')) "installs Codex workflow skill"
  Assert-True (Test-Path (Join-Path $proj '.agents\skills\openspec-workflow\references\prompts\apply.md')) "installs Codex apply prompt"
  Assert-True (Test-Path (Join-Path $proj '.agents\skills\openspec-workflow\references\gates\acceptance.md')) "installs Codex acceptance contract"
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $proj '.workflow\pack\gates') -File).Count -eq 1) "installs only the shared acceptance contract"
  foreach ($oldGate in @('tdd.md','debug.md','verify.md')) {
    Assert-True (-not (Test-Path (Join-Path $proj ".workflow\pack\gates\$oldGate"))) "removes superseded source gate $oldGate"
    Assert-True (-not (Test-Path (Join-Path $proj ".agents\skills\openspec-workflow\references\gates\$oldGate"))) "removes superseded Codex gate $oldGate"
  }
  Assert-True (Test-Path (Join-Path $proj '.agents\rules\early-project.md')) "migrates project Cursor rule for Codex"
  $agents1 = Get-Content -Raw -Encoding utf8 (Join-Path $proj 'AGENTS.md')
  Assert-True ($agents1 -match 'Keep this custom guidance') "preserves project-owned AGENTS guidance"
  Assert-True ($agents1 -match 'BEGIN WORKFLOW MANAGED') "adds managed workflow guidance to AGENTS.md"
  Assert-True ($agents1 -notmatch 'Bugs, test failures') "does not route unrelated debugging into OpenSpec"
  $applyContract = Get-Content -Raw -Encoding utf8 (Join-Path $proj '.workflow\pack\prompts\apply.md')
  Assert-True ($applyContract -match '## Preconditions' -and $applyContract -match '## Outputs' -and $applyContract -match '## Acceptance' -and $applyContract -match '## Stop conditions') "apply is a delivery contract"
  Assert-True ($applyContract -notmatch 'RED|GREEN|REFACTOR|every 3 tasks') "apply does not prescribe generic implementation methods"
  $schemaContract = Get-Content -Raw -Encoding utf8 (Join-Path $proj 'openspec\schemas\workflow-spec\schema.yaml')
  Assert-True ($schemaContract -match 'This artifact is required because tasks depend on it') "schema makes change design unambiguously required"
  Assert-True ($schemaContract -notmatch 'When to include design') "schema has no optional-design contradiction"
  Assert-True ($agents1 -match 'Read `\.agents/rules/early-project\.md` before any work \(always apply\)') "routes always-apply project rule"
  Assert-True ($agents1 -match 'src/deploy/\*\*/\*.*docs/deploy/\*\*/\*') "routes path-scoped project rule"
  Assert-True ($agents1 -notmatch '\$\(') "renders project rule metadata without PowerShell expressions"
  $codexConfig1 = Get-Content -Raw -Encoding utf8 (Join-Path $proj '.codex\config.toml')
  Assert-True ($codexConfig1 -match '\[mcp_servers\."example\.mcp"\]') "generates safely quoted Codex MCP server"
  Assert-True ($codexConfig1 -match '"EXAMPLE_MODE"\s*=\s*"test"') "generates safely quoted Codex MCP environment"
  $cursorMcp1 = Get-Content -Raw -Encoding utf8 (Join-Path $proj '.cursor\mcp.json')
  Assert-True ($cursorMcp1 -match '"example\.mcp"') "generates Cursor MCP from neutral source"
  Assert-True (Test-Path (Join-Path $proj '.cursor\rules\early-project.mdc')) "generates Cursor rule from neutral source"

  Set-Content -Encoding utf8 (Join-Path $proj '.workflow\pack\gates\tdd.md') 'superseded'
  $oldGateResult = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($oldGateResult.ExitCode -ne 0 -and (($oldGateResult.Errors -join "`n") -match 'superseded method gate')) "doctor rejects superseded method gates"
  Remove-Item -LiteralPath (Join-Path $proj '.workflow\pack\gates\tdd.md') -Force
  Assert-True (Test-Path (Join-Path $proj '.workflow\version.json')) "writes one neutral version authority"
  Assert-True (-not (Test-Path (Join-Path $proj '.cursor\workflow\version.json'))) "does not duplicate Cursor metadata"
  Assert-True (-not (Test-Path (Join-Path $proj '.agents\workflow\version.json'))) "does not duplicate Codex metadata"

  Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $proj
  $agents2 = Get-Content -Raw -Encoding utf8 (Join-Path $proj 'AGENTS.md')
  Assert-True (($agents2 -split 'BEGIN WORKFLOW MANAGED').Count -eq 2) "reinstall keeps one managed AGENTS block"
  Assert-True ($agents2 -match 'Keep this custom guidance') "reinstall still preserves project AGENTS guidance"

  # business capability must be paired for doctor; preserve both files across install
  Set-Content (Join-Path $proj 'openspec\specs\keep-me\design.md') 'business design stays'
  $r2 = Invoke-WorkflowDoctor -ProjectRoot $proj
  if ($r2.ExitCode -ne 0) { $r2.Errors | ForEach-Object { Write-Host "  doctor: $_" } }
  Assert-True ($r2.ExitCode -eq 0) "doctor passes after install"
  Assert-True (Test-Path (Join-Path $proj 'openspec\specs\keep-me\design.md')) "preserves business design"

  $generatedRule = Join-Path $proj '.agents\rules\early-project.md'
  Set-Content -Encoding utf8 $generatedRule 'drifted'
  $beforeDoctor = Get-Content -Raw -Encoding utf8 $generatedRule
  $rDrift = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($rDrift.ExitCode -ne 0) "doctor reports generated content drift"
  Assert-True ((Get-Content -Raw -Encoding utf8 $generatedRule) -eq $beforeDoctor) "doctor is read-only"
  Repair-WorkflowInstall -ProjectRoot $proj
  Assert-True ((Get-Content -Raw -Encoding utf8 $generatedRule) -match 'Early project rule') "explicit repair restores generated rule"
  Assert-True ((Invoke-WorkflowDoctor -ProjectRoot $proj).ExitCode -eq 0) "doctor passes after explicit repair"

  $statePath = Write-WorkflowState -ProjectRoot $proj -ActiveChange 'neutral-test' -Phase 'apply'
  Assert-True ($statePath -eq (Join-Path $proj '.workflow\state.json')) "state writes only to neutral authority"
  Assert-True (-not (Test-Path (Join-Path $proj '.cursor\workflow\state.json'))) "does not duplicate Cursor state"
  Assert-True (-not (Test-Path (Join-Path $proj '.agents\workflow\state.json'))) "does not duplicate Codex state"

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
  Assert-True ($merged1 -notmatch 'Both spec|Own Why|create BOTH|Never leave') "merged config does not duplicate schema artifact contracts"

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

  # machine sync remains explicit; doctor only reports stale generated config
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
  $beforeDocConfig = Get-Content -Raw (Join-Path $proj2 'openspec\config.yaml')
  $rDocSync = Invoke-WorkflowDoctor -ProjectRoot $proj2
  Assert-True ($rDocSync.ExitCode -ne 0) "doctor reports stale merged config"
  $viaDoc = Get-Content -Raw (Join-Path $proj2 'openspec\config.yaml')
  Assert-True ($viaDoc -eq $beforeDocConfig) "doctor does not auto-sync project rules"
  Repair-WorkflowInstall -ProjectRoot $proj2
  Assert-True ((Get-Content -Raw (Join-Path $proj2 'openspec\config.yaml')) -match 'ViaDoctorRule') "explicit repair syncs project rules"

  # reintroduce legacy → doctor fails
  New-Item -ItemType Directory -Force -Path (Join-Path $proj '.cursor\skills\superpowers-v9') | Out-Null
  $r3 = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($r3.ExitCode -ne 0) "doctor fails when legacy skills remain"

  # self-install must not wipe source pack
  Assert-True (Test-Path (Join-Path $repoRoot '.workflow\pack\prompts\apply.md')) "neutral repo pack exists before self-init"
  Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $repoRoot
  Assert-True (Test-Path (Join-Path $repoRoot '.workflow\pack\prompts\apply.md')) "self-init preserves neutral pack"
  Assert-True (Test-Path (Join-Path $repoRoot '.cursor\commands\opsx-apply.md')) "self-init preserves opsx-apply"
  Assert-True (Test-Path (Join-Path $repoRoot '.agents\skills\openspec-workflow\SKILL.md')) "self-init preserves Codex workflow skill"

  $bad = Join-Path $tmp 'bad'
  New-Item -ItemType Directory -Force -Path (Join-Path $bad '.workflow') | Out-Null
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\mcp.json') '{ "schemaVersion": 1, "servers": { "bad": { "transport": "stdio", "command": "x", "mystery": true } } }'
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\rules.json') '{ "schemaVersion": 1, "rules": [] }'
  Assert-Throws { Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $bad } 'mystery' "unknown MCP fields fail explicitly"
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\mcp.json') '{ "schemaVersion": 1, "servers": { "bad": { "transport": "stdio", "command": "x", "enabled": "yes" } } }'
  Assert-Throws { Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $bad } 'enabled.*boolean' "invalid MCP field types fail explicitly"

  # Codex-only deployment must treat the entire Cursor tree as out of scope.
  $codexOnly = Join-Path $tmp 'codex-only'
  New-Item -ItemType Directory -Force -Path (Join-Path $codexOnly '.cursor\skills\openspec-private') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $codexOnly '.cursor\rules') | Out-Null
  [IO.File]::WriteAllBytes((Join-Path $codexOnly '.cursor\skills\openspec-private\SKILL.md'), [byte[]](0,1,2,13,10,255))
  Set-Content -Encoding utf8 (Join-Path $codexOnly '.cursor\rules\project-only.mdc') 'project-owned cursor rule'
  $cursorFingerprint = {
    $root = Join-Path $codexOnly '.cursor'
    return (@(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName | ForEach-Object {
      $_.FullName.Substring($root.Length) + ':' + (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
    }) -join "`n")
  }
  $cursorBefore = &$cursorFingerprint
  Install-WorkflowV2 -SourceRoot $repoRoot -TargetRoot $codexOnly -Clients codex
  $cursorAfter = &$cursorFingerprint
  Assert-True ($cursorAfter -eq $cursorBefore) "Codex-only install leaves Cursor tree byte-for-byte unchanged"
  Assert-True (Test-Path (Join-Path $codexOnly '.agents\skills\openspec-workflow\SKILL.md')) "Codex-only install creates Codex skill"
  Assert-True (-not (Test-Path (Join-Path $codexOnly '.cursor\commands\opsx-apply.md'))) "Codex-only install does not create Cursor commands"
  $codexMetadata = Get-Content -Raw (Join-Path $codexOnly '.workflow\version.json') | ConvertFrom-Json
  Assert-True ((@($codexMetadata.clients) -join ',') -eq 'codex') "Codex-only metadata records only Codex"
  Assert-True ((Invoke-WorkflowDoctor -ProjectRoot $codexOnly).ExitCode -eq 0) "Codex-only doctor ignores Cursor-private content"
  Repair-WorkflowInstall -ProjectRoot $codexOnly
  Assert-True ((&$cursorFingerprint) -eq $cursorBefore) "Codex-only repair preserves installed client scope"

  # Published downstream repositories receive only the built artifact, never its neutral source.
  Build-WorkflowCodexArtifact -SourceRoot $repoRoot | Out-Null
  $published = Join-Path $tmp 'published-artifact'
  New-Item -ItemType Directory -Force -Path (Join-Path $published '.agents\rules') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $published '.agents\skills\private-skill') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $published '.workflow\pack') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $published 'scripts\lib') | Out-Null
  Set-Content -Encoding utf8 (Join-Path $published '.agents\rules\private.md') 'private rule'
  Set-Content -Encoding utf8 (Join-Path $published '.agents\skills\private-skill\SKILL.md') 'private skill'
  Set-Content -Encoding utf8 (Join-Path $published '.workflow\pack\source.md') 'must not ship'
  Set-Content -Encoding utf8 (Join-Path $published '.agents\rules\.workflow-managed.json') '{"files":[]}'
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\init.ps1') 'Install-WorkflowV2'
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\doctor.ps1') 'Invoke-WorkflowDoctor'
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\lib\WorkflowDeploy.psm1') 'WorkflowVersion'
  Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $published
  Assert-True (-not(Test-Path (Join-Path $published '.workflow'))) "publication removes downstream neutral source"
  Assert-True (-not(Test-Path (Join-Path $published '.agents\rules\.workflow-managed.json'))) "publication removes empty generated rule index"
  Assert-True (-not(Test-Path (Join-Path $published 'scripts\init.ps1'))) "publication removes deployment init source"
  Assert-True (-not(Test-Path (Join-Path $published 'scripts\doctor.ps1'))) "publication removes deployment doctor source"
  Assert-True (-not(Test-Path (Join-Path $published 'scripts\lib\WorkflowDeploy.psm1'))) "publication removes deployment module source"
  Assert-True (Test-Path (Join-Path $published '.agents\rules\private.md')) "publication preserves private rules"
  Assert-True (Test-Path (Join-Path $published '.agents\skills\private-skill\SKILL.md')) "publication preserves unrelated skills"
  Assert-True (Test-Path (Join-Path $published '.agents\skills\openspec-workflow\artifact.json')) "publication includes artifact metadata"
  $doctorContract=Get-Content -Raw (Join-Path $repoRoot '.workflow\pack\prompts\doctor.md')
  Assert-True ($doctorContract -match 'check-deployment\.ps1') "doctor contract routes to source-owned checker"
  Assert-True ($doctorContract -notmatch 'pwsh -File scripts/doctor\.ps1') "doctor contract does not reference deleted downstream checker"
  Assert-True ($doctorContract -match 'Do not expect or recreate `\.workflow`') "doctor contract preserves artifact-only boundary"
  $publishedDoctor=Join-Path $published '.agents\skills\openspec-workflow\references\prompts\doctor.md'
  $publishedDoctorBytes=[System.IO.File]::ReadAllBytes($publishedDoctor)
  $lfDoctor=New-Object System.IO.MemoryStream
  try {
    for($i=0;$i -lt $publishedDoctorBytes.Length;$i++){
      if($publishedDoctorBytes[$i] -eq 13){
        if(($i+1) -lt $publishedDoctorBytes.Length -and $publishedDoctorBytes[$i+1] -eq 10){$i++}
        $lfDoctor.WriteByte(10)
      }else{$lfDoctor.WriteByte($publishedDoctorBytes[$i])}
    }
    [System.IO.File]::WriteAllBytes($publishedDoctor,$lfDoctor.ToArray())
  }finally{$lfDoctor.Dispose()}
  $artifactDoctor=Invoke-WorkflowArtifactDoctor -ProjectRoot $published -SourceRoot $repoRoot
  if($artifactDoctor.ExitCode -ne 0){$artifactDoctor.Errors|%{Write-Host "ARTIFACT DOCTOR: $_" -ForegroundColor Yellow}}
  Assert-True ($artifactDoctor.ExitCode -eq 0) "artifact Doctor accepts equivalent LF and CRLF content"
  [System.IO.File]::AppendAllText($publishedDoctor,"substantive drift",[System.Text.UTF8Encoding]::new($false))
  $beforeDoctorHash=(Get-FileHash -Algorithm SHA256 -LiteralPath $publishedDoctor).Hash
  $driftDoctor=Invoke-WorkflowArtifactDoctor -ProjectRoot $published -SourceRoot $repoRoot
  $afterDoctorHash=(Get-FileHash -Algorithm SHA256 -LiteralPath $publishedDoctor).Hash
  Assert-True ($driftDoctor.ExitCode -ne 0) "artifact Doctor rejects substantive content drift"
  Assert-True ($beforeDoctorHash -eq $afterDoctorHash) "artifact Doctor remains read-only on content drift"

} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

if ($failed -gt 0) { Write-Host "`n$failed failed" -ForegroundColor Red; exit 1 }
Write-Host "`nAll tests passed" -ForegroundColor Green
exit 0
