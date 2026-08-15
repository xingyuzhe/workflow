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
  Set-Content (Join-Path $commands 'workflow-apply.md') 'generated'
  Set-Content (Join-Path $commands 'user-cmd.md') 'keep'
  New-Item -ItemType Directory -Path (Join-Path $rules 'superpowers-v6.1.1') | Out-Null
  Set-Content (Join-Path $rules 'superpowers-v6.1.1\superpowers-bootstrap.mdc') 'old'
  Set-Content (Join-Path $rules 'superpowers-v6.1.1\superpowers-router.mdc') 'old'
  Set-Content (Join-Path $rules 'my-company.mdc') 'keep'

  Remove-WorkflowOwnedEntries -RulesRoot $rules -CommandsRoot $commands
  Assert-True (-not (Test-Path (Join-Path $commands 'opsx-apply.md'))) "removes opsx-apply"
  Assert-True (-not (Test-Path (Join-Path $commands 'workflow-apply.md'))) "removes generated workflow-apply"
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

  Install-Workflow -SourceRoot $repoRoot -TargetRoot $proj
  Assert-True (-not (Test-Path (Join-Path $proj '.cursor\skills\openspec-v1.5.0'))) "install purges legacy skills"
  Assert-True (Test-Path (Join-Path $proj '.workflow\specs\keep-me\spec.md')) "migrates and preserves business specs"
  Assert-True (-not(Test-Path (Join-Path $proj 'openspec'))) "removes superseded openspec data root"
  Assert-True (Test-Path (Join-Path $proj '.workflow\pack\prompts\apply.md')) "installs neutral apply prompt"
  Assert-True (-not (Test-Path (Join-Path $proj '.cursor\workflow\pack'))) "removes superseded Cursor pack"
  Assert-True (Test-Path (Join-Path $proj '.agents\skills\workflow\SKILL.md')) "installs Codex workflow skill"
  Assert-True (Test-Path (Join-Path $proj '.agents\skills\workflow\references\prompts\apply.md')) "installs Codex apply prompt"
  Assert-True (Test-Path (Join-Path $proj '.agents\skills\workflow\references\gates\acceptance.md')) "installs Codex acceptance contract"
  Assert-True (Test-Path (Join-Path $proj '.agents\skills\workflow\bin\workflow.ps1')) "installs repository-local workflow CLI"
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $proj '.workflow\pack\gates') -File).Count -eq 1) "installs only the shared acceptance contract"
  foreach ($oldGate in @('tdd.md','debug.md','verify.md')) {
    Assert-True (-not (Test-Path (Join-Path $proj ".workflow\pack\gates\$oldGate"))) "removes superseded source gate $oldGate"
    Assert-True (-not (Test-Path (Join-Path $proj ".agents\skills\workflow\references\gates\$oldGate"))) "removes superseded Codex gate $oldGate"
  }
  Assert-True (Test-Path (Join-Path $proj '.agents\rules\early-project.md')) "migrates project Cursor rule for Codex"
  $agents1 = Get-Content -Raw -Encoding utf8 (Join-Path $proj 'AGENTS.md')
  Assert-True ($agents1 -match 'Keep this custom guidance') "preserves project-owned AGENTS guidance"
  Assert-True ($agents1 -match 'BEGIN WORKFLOW MANAGED') "adds managed workflow guidance to AGENTS.md"
  Assert-True ($agents1 -notmatch 'Bugs, test failures') "does not route unrelated debugging into workflow"
  $applyContract = Get-Content -Raw -Encoding utf8 (Join-Path $proj '.workflow\pack\prompts\apply.md')
  Assert-True ($applyContract -match '## Preconditions' -and $applyContract -match '## Outputs' -and $applyContract -match '## Acceptance' -and $applyContract -match '## Stop conditions') "apply is a lifecycle contract"
  Assert-True ($applyContract -notmatch 'RED|GREEN|REFACTOR|every 3 tasks') "apply does not prescribe generic implementation methods"
  $schemaContract = Get-Content -Raw -Encoding utf8 (Join-Path $proj '.workflow\schemas\workflow-contract\schema.json') | ConvertFrom-Json
  Assert-True ((@($schemaContract.artifacts|Where-Object{$_.id -eq 'design'}|Select-Object -First 1).required) -contains $true) "schema makes change design unambiguously required"
  Assert-True ($schemaContract.name -eq 'workflow-contract') "schema resolves from repository-local workflow contract"
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

  Install-Workflow -SourceRoot $repoRoot -TargetRoot $proj
  $agents2 = Get-Content -Raw -Encoding utf8 (Join-Path $proj 'AGENTS.md')
  Assert-True (($agents2 -split 'BEGIN WORKFLOW MANAGED').Count -eq 2) "reinstall keeps one managed AGENTS block"
  Assert-True ($agents2 -match 'Keep this custom guidance') "reinstall still preserves project AGENTS guidance"

  # business capability must be paired for doctor; preserve both files across install
  Set-Content (Join-Path $proj '.workflow\specs\keep-me\design.md') 'business design stays'
  $r2 = Invoke-WorkflowDoctor -ProjectRoot $proj
  if ($r2.ExitCode -ne 0) { $r2.Errors | ForEach-Object { Write-Host "  doctor: $_" } }
  Assert-True ($r2.ExitCode -eq 0) "doctor passes after install"
  Assert-True (Test-Path (Join-Path $proj '.workflow\specs\keep-me\design.md')) "preserves business design"

  $generatedRule = Join-Path $proj '.agents\rules\early-project.md'
  Set-Content -Encoding utf8 $generatedRule 'drifted'
  $beforeDoctor = Get-Content -Raw -Encoding utf8 $generatedRule
  $rDrift = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($rDrift.ExitCode -ne 0) "doctor reports generated content drift"
  Assert-True ((Get-Content -Raw -Encoding utf8 $generatedRule) -eq $beforeDoctor) "doctor is read-only"
  Repair-WorkflowInstall -ProjectRoot $proj
  Assert-True ((Get-Content -Raw -Encoding utf8 $generatedRule) -match 'Early project rule') "explicit repair restores generated rule"
  Assert-True ((Invoke-WorkflowDoctor -ProjectRoot $proj).ExitCode -eq 0) "doctor passes after explicit repair"

  # unpaired main spec → doctor fails
  Remove-Item -Force (Join-Path $proj '.workflow\specs\keep-me\design.md')
  $rPair = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($rPair.ExitCode -ne 0) "doctor fails when design.md missing"
  Assert-True (($rPair.Errors -join ' ') -match 'design\.md') "doctor mentions missing design.md"
  Set-Content (Join-Path $proj '.workflow\specs\keep-me\design.md') 'business design stays'

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
    'schema: workflow-contract',
    'rules:',
    '  proposal:',
    '    - Own Why only',
    '  specs:',
    '    - Both spec and design'
  ) | Set-Content -Encoding utf8 $wfOnly
  Merge-WorkflowConfig -WorkflowPath $wfOnly -ProjectPath $null -OutPath $out1
  $o1 = Get-Content -Raw $out1
  Assert-True ($o1 -match 'schema:\s*workflow-contract') "merge workflow-only keeps schema"
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
  Merge-WorkflowConfig -WorkflowPath $wfOnly -ProjectPath $projRules -OutPath $out2
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
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $proj2
  Assert-True (Test-Path (Join-Path $proj2 '.workflow\config.workflow.yaml')) "writes config.workflow.yaml"
  Assert-True (Test-Path (Join-Path $proj2 '.workflow\config.project.yaml')) "creates config.project.yaml via migrate"
  $projCfg1 = Get-Content -Raw (Join-Path $proj2 '.workflow\config.project.yaml')
  Assert-True ($projCfg1 -match 'Keep my private rule forever') "migrated private rule into project file"
  $merged1 = Get-Content -Raw (Join-Path $proj2 '.workflow\config.yaml')
  Assert-True ($merged1 -match 'Keep my private rule forever') "merged config includes private rule"
  Assert-True ($merged1 -notmatch 'Both spec|Own Why|create BOTH|Never leave') "merged config does not duplicate schema artifact contracts"

  @(
    'schema: workflow-contract',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever',
    '    - Second private line'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.project.yaml')
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $proj2
  $projCfg2 = Get-Content -Raw (Join-Path $proj2 '.workflow\config.project.yaml')
  Assert-True ($projCfg2 -match 'Second private line') "second install does not overwrite project config"

  # machine sync remains explicit; doctor only reports stale generated config
  @(
    'schema: workflow-contract',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever',
    '    - DoctorAutoSyncRule'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.project.yaml')
  @(
    'schema: workflow-contract',
    'rules:',
    '  proposal:',
    '    - stale merged only'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.yaml')
  $sync1 = Sync-WorkflowConfig -ProjectRoot $proj2
  Assert-True ($sync1.Changed -eq $true) "sync merges when project changed"
  Assert-True ($sync1.Status -eq 'Merged') "sync status Merged"
  $healed = Get-Content -Raw (Join-Path $proj2 '.workflow\config.yaml')
  Assert-True ($healed -match 'DoctorAutoSyncRule') "sync writes project rule into config.yaml"
  $sync2 = Sync-WorkflowConfig -ProjectRoot $proj2
  Assert-True ($sync2.Changed -eq $false) "second sync is no-op when up to date"
  Assert-True ($sync2.Status -eq 'Unchanged') "sync status Unchanged"

  @(
    'schema: workflow-contract',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever',
    '    - DoctorAutoSyncRule',
    '    - ViaDoctorRule'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.project.yaml')
  @(
    '# stale',
    'schema: workflow-contract',
    'rules:',
    '  proposal:',
    '    - Keep my private rule forever'
  ) | Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.yaml')
  $beforeDocConfig = Get-Content -Raw (Join-Path $proj2 '.workflow\config.yaml')
  $rDocSync = Invoke-WorkflowDoctor -ProjectRoot $proj2
  Assert-True ($rDocSync.ExitCode -ne 0) "doctor reports stale merged config"
  $viaDoc = Get-Content -Raw (Join-Path $proj2 '.workflow\config.yaml')
  Assert-True ($viaDoc -eq $beforeDocConfig) "doctor does not auto-sync project rules"
  Repair-WorkflowInstall -ProjectRoot $proj2
  Assert-True ((Get-Content -Raw (Join-Path $proj2 '.workflow\config.yaml')) -match 'ViaDoctorRule') "explicit repair syncs project rules"

  # reintroduce legacy → doctor fails
  New-Item -ItemType Directory -Force -Path (Join-Path $proj '.cursor\skills\superpowers-v9') | Out-Null
  $r3 = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($r3.ExitCode -ne 0) "doctor fails when legacy skills remain"

  # self-install must not wipe source pack
  Assert-True (Test-Path (Join-Path $repoRoot '.workflow\pack\prompts\apply.md')) "neutral repo pack exists before self-init"
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $repoRoot
  Assert-True (Test-Path (Join-Path $repoRoot '.workflow\pack\prompts\apply.md')) "self-init preserves neutral pack"
  Assert-True (Test-Path (Join-Path $repoRoot '.cursor\commands\workflow-apply.md')) "self-init preserves workflow-apply"
  Assert-True (Test-Path (Join-Path $repoRoot '.agents\skills\workflow\SKILL.md')) "self-init preserves Codex workflow skill"

  $bad = Join-Path $tmp 'bad'
  New-Item -ItemType Directory -Force -Path (Join-Path $bad '.workflow') | Out-Null
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\mcp.json') '{ "schemaVersion": 1, "servers": { "bad": { "transport": "stdio", "command": "x", "mystery": true } } }'
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\rules.json') '{ "schemaVersion": 1, "rules": [] }'
  Assert-Throws { Install-Workflow -SourceRoot $repoRoot -TargetRoot $bad } 'mystery' "unknown MCP fields fail explicitly"
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\mcp.json') '{ "schemaVersion": 1, "servers": { "bad": { "transport": "stdio", "command": "x", "enabled": "yes" } } }'
  Assert-Throws { Install-Workflow -SourceRoot $repoRoot -TargetRoot $bad } 'enabled.*boolean' "invalid MCP field types fail explicitly"

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
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $codexOnly -Clients codex
  $cursorAfter = &$cursorFingerprint
  Assert-True ($cursorAfter -eq $cursorBefore) "Codex-only install leaves Cursor tree byte-for-byte unchanged"
  Assert-True (Test-Path (Join-Path $codexOnly '.agents\skills\workflow\SKILL.md')) "Codex-only install creates Codex skill"
  Assert-True (-not (Test-Path (Join-Path $codexOnly '.cursor\commands\workflow-apply.md'))) "Codex-only install does not create Cursor commands"
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
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\init.ps1') 'Install-Workflow'
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\doctor.ps1') 'Invoke-WorkflowDoctor'
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\lib\WorkflowDeploy.psm1') 'WorkflowVersion'
  Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $published
  Assert-True (Test-Path (Join-Path $published '.workflow')) "publication preserves downstream workflow project data"
  Assert-True (-not(Test-Path (Join-Path $published '.workflow\pack'))) "publication removes source-only workflow pack"
  Assert-True (-not(Test-Path (Join-Path $published '.workflow\cli'))) "publication removes source-only CLI source"
  Assert-True (Test-Path (Join-Path $published '.workflow\schemas\workflow-contract\schema.json')) "publication includes workflow artifact contract"
  Assert-True (-not(Test-Path (Join-Path $published 'openspec'))) "publication removes legacy OpenSpec project data root"
  Assert-True (-not(Test-Path (Join-Path $published '.agents\skills\openspec-workflow'))) "publication removes legacy OpenSpec skill"
  Assert-True (-not(Test-Path (Join-Path $published '.agents\rules\.workflow-managed.json'))) "publication removes empty generated rule index"
  Assert-True (-not(Test-Path (Join-Path $published 'scripts\init.ps1'))) "publication removes deployment init source"
  Assert-True (-not(Test-Path (Join-Path $published 'scripts\doctor.ps1'))) "publication removes deployment doctor source"
  Assert-True (-not(Test-Path (Join-Path $published 'scripts\lib\WorkflowDeploy.psm1'))) "publication removes deployment module source"
  Assert-True (Test-Path (Join-Path $published '.agents\rules\private.md')) "publication preserves private rules"
  Assert-True (Test-Path (Join-Path $published '.agents\skills\private-skill\SKILL.md')) "publication preserves unrelated skills"
  Assert-True (Test-Path (Join-Path $published '.agents\skills\workflow\artifact.json')) "publication includes artifact metadata"
  $publishedCli=Join-Path $published '.agents\skills\workflow\bin\workflow.ps1'
  Assert-True (Test-Path $publishedCli) "publication includes repository-owned CLI"
  $publishedRuntimeText=@(Get-ChildItem -LiteralPath (Join-Path $published '.agents\skills\workflow') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
  Assert-True ($publishedRuntimeText -notmatch '(?i)openspec|opsx|\bnpm\b|\bnpx\b') "published runtime contains no external lifecycle identity or package command"
  Assert-True ($publishedRuntimeText -match '(?i)never install, download, discover, or invoke an external lifecycle CLI or package') "published runtime explicitly rejects external lifecycle dependencies"

  # The published lifecycle works without npm, npx, or any external lifecycle CLI on PATH.
  $savedPath=$env:PATH
  try {
    $env:PATH=''
    $publishedDoctorResult=((& $publishedCli doctor --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    Assert-True ($publishedDoctorResult.valid -eq $true) "published local CLI doctor succeeds with empty PATH"

    # Incomplete content must not become apply-ready merely because files exist.
    (& $publishedCli new incomplete-content --json -ProjectRoot $published) | Out-Null
    $incompleteRoot=Join-Path $published '.workflow\changes\incomplete-content'
    Set-Content -Encoding utf8 (Join-Path $incompleteRoot 'proposal.md') "# Proposal`n`n## Why`nReady.`n`n## What Changes`nTest validation.`n`n## Capabilities`n`n### New Capabilities`nNone.`n`n### Modified Capabilities`nNone.`n`n## Impact`nTest.`n`n## Non-goals`nProduction.`n"
    $dependencyStatus=((& $publishedCli status --change incomplete-content --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    $tasksStatus=@($dependencyStatus.artifacts|Where-Object{$_.id -eq 'tasks'})[0]
    Assert-True ($tasksStatus.status -eq 'blocked') "status blocks tasks while design dependency is incomplete"
    Assert-True (@($tasksStatus.missingDeps) -contains 'design') "status reports the missing design dependency"
    Set-Content -Encoding utf8 (Join-Path $incompleteRoot 'design.md') ''
    Set-Content -Encoding utf8 (Join-Path $incompleteRoot 'tasks.md') ''
    $incompleteStatus=((& $publishedCli status --change incomplete-content --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    Assert-True ($incompleteStatus.applyReady -eq $false) "empty artifact files are not apply-ready"
    $incompleteValidation=((& $publishedCli validate incomplete-content --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    Assert-True ($incompleteValidation.valid -eq $false) "validate honors the positional change name and rejects empty artifacts"
    Set-Content -Encoding utf8 (Join-Path $incompleteRoot 'design.md') "# Design`n`n## Context`nValidation.`n`n## Goals / Non-Goals`nComplete artifacts.`n`n## Decisions`nUse fixtures.`n`n## Risks / Trade-offs`nNone.`n"
    Set-Content -Encoding utf8 (Join-Path $incompleteRoot 'tasks.md') "# Tasks`n`nNo checklist exists.`n"
    $null=(& $publishedCli archive incomplete-content --json -ProjectRoot $published 2>&1 | Out-String)
    Assert-True ($LASTEXITCODE -ne 0) "archive rejects a tasks artifact with no checklist items"

    # Archive collision must fail before sync mutates accepted specifications.
    (& $publishedCli new collision-check --json -ProjectRoot $published) | Out-Null
    $collisionRoot=Join-Path $published '.workflow\changes\collision-check'
    Set-Content -Encoding utf8 (Join-Path $collisionRoot 'proposal.md') "# Proposal`n`n## Why`nCollision.`n`n## What Changes`nCheck failure safety.`n`n## Capabilities`n`n### New Capabilities`n- collision-cap: collision behavior.`n`n### Modified Capabilities`nNone.`n`n## Impact`nTest.`n`n## Non-goals`nProduction.`n"
    Set-Content -Encoding utf8 (Join-Path $collisionRoot 'design.md') "# Design`n`n## Context`nCollision.`n`n## Goals / Non-Goals`nAvoid partial writes.`n`n## Decisions`nPreflight destination.`n`n## Risks / Trade-offs`nNone.`n"
    Set-Content -Encoding utf8 (Join-Path $collisionRoot 'tasks.md') "# Tasks`n`n- [x] 1.1 Check collision safety.`n"
    $collisionSpec=Join-Path $collisionRoot 'specs\collision-cap';New-Item -ItemType Directory -Force -Path $collisionSpec|Out-Null
    Set-Content -Encoding utf8 (Join-Path $collisionSpec 'spec.md') "# collision-cap Specification`n`n## ADDED Requirements`n`n### Requirement: Collision safety`nThe system SHALL preflight archive collisions.`n`n#### Scenario: Destination exists`n- **WHEN** archive starts`n- **THEN** accepted specifications remain unchanged`n"
    Set-Content -Encoding utf8 (Join-Path $collisionSpec 'design.md') "# collision-cap Design`n`n## Context`nCollision safety.`n"
    $collisionArchive=Join-Path $published ('.workflow\changes\archive\'+(Get-Date -Format 'yyyy-MM-dd')+'-collision-check');New-Item -ItemType Directory -Force -Path $collisionArchive|Out-Null
    $collisionMain=Join-Path $published '.workflow\specs\collision-cap\spec.md'
    $null=(& $publishedCli archive collision-check --json -ProjectRoot $published 2>&1 | Out-String)
    Assert-True ($LASTEXITCODE -ne 0) "archive rejects an existing destination"
    Assert-True (-not(Test-Path -LiteralPath $collisionMain)) "archive collision causes no specification write"

    # Delta synchronization supports all operations and commits only a validated result.
    $multiMain=Join-Path $published '.workflow\specs\multi-cap';New-Item -ItemType Directory -Force -Path $multiMain|Out-Null
    Set-Content -Encoding utf8 (Join-Path $multiMain 'spec.md') "# multi-cap Specification`n`n## Purpose`nTest delta operations.`n`n### Requirement: Alpha`nThe system SHALL keep alpha.`n`n#### Scenario: Alpha`n- **WHEN** alpha runs`n- **THEN** alpha succeeds`n`n### Requirement: Beta`nThe system SHALL keep beta.`n`n#### Scenario: Beta`n- **WHEN** beta runs`n- **THEN** beta succeeds`n"
    Set-Content -Encoding utf8 (Join-Path $multiMain 'design.md') "# multi-cap Design`n`n## Context`nAccepted baseline.`n"
    (& $publishedCli new multi-delta --json -ProjectRoot $published) | Out-Null
    $multiRoot=Join-Path $published '.workflow\changes\multi-delta'
    Set-Content -Encoding utf8 (Join-Path $multiRoot 'proposal.md') "# Proposal`n`n## Why`nDelta coverage.`n`n## What Changes`nExercise all operations.`n`n## Capabilities`n`n### New Capabilities`nNone.`n`n### Modified Capabilities`n- multi-cap: update accepted requirements.`n`n## Impact`nTest.`n`n## Non-goals`nProduction.`n"
    Set-Content -Encoding utf8 (Join-Path $multiRoot 'design.md') "# Design`n`n## Context`nDelta operations.`n`n## Goals / Non-Goals`nVerify merge.`n`n## Decisions`nUse one delta.`n`n## Risks / Trade-offs`nNone.`n"
    Set-Content -Encoding utf8 (Join-Path $multiRoot 'tasks.md') "# Tasks`n`n- [x] 1.1 Exercise delta operations.`n"
    $multiDelta=Join-Path $multiRoot 'specs\multi-cap';New-Item -ItemType Directory -Force -Path $multiDelta|Out-Null
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') "# multi-cap Delta`n`n## ADDED Requirements`n`n### Requirement: Gamma`nThe system SHALL add gamma.`n`n#### Scenario: Gamma`n- **WHEN** gamma runs`n- **THEN** gamma succeeds`n`n## MODIFIED Requirements`n`n### Requirement: Alpha`nThe system SHALL update alpha.`n`n#### Scenario: Updated alpha`n- **WHEN** alpha runs`n- **THEN** updated alpha succeeds`n`n## REMOVED Requirements`n`n### Requirement: Beta`n`n## RENAMED Requirements`n`nFROM: Gamma`nTO: Delta`n"
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'design.md') "# multi-cap Design`n`n## Context`nMerged design.`n"
    (& $publishedCli sync --change multi-delta --json -ProjectRoot $published) | Out-Null
    $multiMerged=Get-Content -Raw (Join-Path $multiMain 'spec.md')
    Assert-True ($multiMerged -match 'Requirement: Alpha' -and $multiMerged -match 'update alpha') "sync applies MODIFIED requirements"
    Assert-True ($multiMerged -notmatch 'Requirement: Beta') "sync applies REMOVED requirements"
    Assert-True ($multiMerged -match 'Requirement: Delta' -and $multiMerged -notmatch 'Requirement: Gamma') "sync applies ADDED and RENAMED requirements"

    # Doctor must detect drift in a file covered by the local artifact manifest.
    $manifestedPrompt=Join-Path $published '.agents\skills\workflow\references\prompts\apply.md'
    $manifestedBackup=Join-Path $tmp 'manifested-prompt.backup';Copy-Item -LiteralPath $manifestedPrompt -Destination $manifestedBackup
    [IO.File]::AppendAllText($manifestedPrompt,"manifest drift",[Text.UTF8Encoding]::new($false))
    $driftedLocalDoctor=((& $publishedCli doctor --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    Assert-True ($driftedLocalDoctor.valid -eq $false) "published local CLI doctor detects manifested artifact drift"
    Copy-Item -LiteralPath $manifestedBackup -Destination $manifestedPrompt -Force

    # `new` must use the configured schema rather than a built-in workflow-contract path.
    $custom=Join-Path $tmp 'custom-schema-project';$customSchema=Join-Path $custom '.workflow\schemas\brief-flow';New-Item -ItemType Directory -Force -Path (Join-Path $customSchema 'templates')|Out-Null
    Set-Content -Encoding utf8 (Join-Path $custom '.workflow\config.workflow.yaml') "schema: brief-flow`n"
    Set-Content -Encoding utf8 (Join-Path $custom '.workflow\config.yaml') "schema: brief-flow`n"
    Set-Content -Encoding utf8 (Join-Path $customSchema 'schema.json') '{"name":"brief-flow","version":1,"artifacts":[{"id":"brief","path":"drafts/brief.md","required":true,"requires":[],"template":"templates/brief.md","instruction":"Write a brief."}]}'
    Set-Content -Encoding utf8 (Join-Path $customSchema 'templates\brief.md') "## Intent`n`n<!-- Explain intent -->`n"
    $customNew=((& $publishedCli new custom-change --json -ProjectRoot $custom) | Out-String | ConvertFrom-Json)
    Assert-True ($customNew.schema -eq 'brief-flow') "new resolves the configured custom schema"
    Assert-True (Test-Path (Join-Path $custom '.workflow\changes\custom-change\drafts\brief.md')) "new creates the configured nested artifact path"

    (& $publishedCli new cli-smoke --json -ProjectRoot $published) | Out-Null
    $smokeRoot=Join-Path $published '.workflow\changes\cli-smoke'
    Set-Content -Encoding utf8 (Join-Path $smokeRoot 'proposal.md') "# Proposal`n`n## Why`nSmoke.`n`n## What Changes`nLocal lifecycle.`n`n## Capabilities`n`n### New Capabilities`n- workflow-smoke: local lifecycle smoke coverage.`n`n### Modified Capabilities`nNone.`n`n## Impact`nTest only.`n`n## Non-goals`nProduction behavior.`n"
    Set-Content -Encoding utf8 (Join-Path $smokeRoot 'design.md') "# Design`n`n## Context`nSmoke.`n`n## Goals / Non-Goals`n- Goal: verify local CLI.`n`n## Decisions`nUse local files.`n`n## Risks / Trade-offs`nNone.`n"
    Set-Content -Encoding utf8 (Join-Path $smokeRoot 'tasks.md') "# Tasks`n`n- [x] 1.1 Verify local CLI lifecycle.`n"
    $smokeSpecRoot=Join-Path $smokeRoot 'specs\workflow-smoke'
    New-Item -ItemType Directory -Force -Path $smokeSpecRoot | Out-Null
    Set-Content -Encoding utf8 (Join-Path $smokeSpecRoot 'spec.md') "# workflow-smoke Specification`n`n## ADDED Requirements`n`n### Requirement: Local smoke lifecycle`nThe system SHALL execute the repository-owned lifecycle.`n`n#### Scenario: Execute locally`n- **WHEN** the local CLI is invoked`n- **THEN** it completes without an external lifecycle package`n"
    Set-Content -Encoding utf8 (Join-Path $smokeSpecRoot 'design.md') "# workflow-smoke Design`n`n## Context`nLocal smoke lifecycle.`n`n## Goals / Non-Goals`n- Goal: verify the local CLI.`n`n## Decisions`nUse repository files.`n`n## Risks / Trade-offs`nNone.`n"
    $smokeStatus=((& $publishedCli status --change cli-smoke --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    Assert-True ($smokeStatus.applyReady -eq $true) "published local CLI reports complete change artifacts"
    $smokeValidation=((& $publishedCli validate cli-smoke --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    Assert-True ($smokeValidation.valid -eq $true) "published local CLI validates change artifacts"
    (& $publishedCli sync --change cli-smoke --json -ProjectRoot $published) | Out-Null
    (& $publishedCli sync --change cli-smoke --json -ProjectRoot $published) | Out-Null
    Assert-True (Test-Path (Join-Path $published '.workflow\specs\workflow-smoke\spec.md')) "published local CLI sync is repeatable"
    $smokeArchive=((& $publishedCli archive cli-smoke --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    Assert-True ($smokeArchive.archived -eq $true) "published local CLI archives a complete change"
    Assert-True (Test-Path (Join-Path $published '.workflow\specs\workflow-smoke\spec.md')) "published local CLI syncs the main specification"
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $published '.workflow\changes\archive') -Directory -Filter '*-cli-smoke').Count -eq 1) "published local CLI moves the change to archive"
  } finally {
    $env:PATH=$savedPath
  }
  $doctorContract=Get-Content -Raw (Join-Path $repoRoot '.workflow\pack\prompts\doctor.md')
  Assert-True ($doctorContract -match 'check-deployment\.ps1') "doctor contract routes to source-owned checker"
  Assert-True ($doctorContract -notmatch 'pwsh -File scripts/doctor\.ps1') "doctor contract does not reference deleted downstream checker"
  Assert-True ($doctorContract -match 'source-only `\.workflow/pack`') "doctor contract distinguishes project data from source runtime"
  $publishedDoctor=Join-Path $published '.agents\skills\workflow\references\prompts\doctor.md'
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
