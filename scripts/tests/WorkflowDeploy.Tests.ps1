# WorkflowDeploy.Tests.ps1 — minimal harness (no Pester required)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = (Resolve-Path (Join-Path $here '..\..')).Path
$testPowerShellPath = (Get-Process -Id $PID).Path
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
function Get-TreeFingerprint([string]$Root) {
  if (-not (Test-Path -LiteralPath $Root)) { return '<missing>' }
  return (@(Get-ChildItem -LiteralPath $Root -Recurse -Force | Sort-Object FullName | ForEach-Object {
    $rel=$_.FullName.Substring($Root.Length).Replace('\','/')
    if($_.PSIsContainer){'D:'+ $rel}else{'F:'+ $rel + ':' + (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash}
  }) -join "`n")
}

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("wf-deploy-test-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  Build-WorkflowCodexArtifact -SourceRoot $repoRoot | Out-Null
  $skills = Join-Path $tmp 'skills'
  New-Item -ItemType Directory -Path (Join-Path $skills 'superpowers-v6.1.1') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'openspec-v1.5.0') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'grilling') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'workflow') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'workflow-private') | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $skills 'my-other-skill') | Out-Null

  $found = @(Get-WorkflowNamespaceSkillDirs -SkillsRoot $skills)
  Assert-True ($found.Count -eq 4) "finds 4 namespace skill dirs"
  Assert-True (-not ($found | Where-Object { $_.Name -eq 'my-other-skill' })) "ignores unrelated skills"
  Assert-True (-not ($found | Where-Object { $_.Name -eq 'workflow-private' })) "does not claim workflow-prefixed private skills"

  Remove-WorkflowNamespaceSkills -SkillsRoot $skills
  Assert-True (-not (Test-Path (Join-Path $skills 'superpowers-v6.1.1'))) "purges superpowers"
  Assert-True (Test-Path (Join-Path $skills 'my-other-skill')) "keeps unrelated skills"
  Assert-True (Test-Path (Join-Path $skills 'workflow-private')) "keeps workflow-prefixed private skills"

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
  New-Item -ItemType Directory -Force -Path (Join-Path $proj '.cursor\skills\workflow-private') | Out-Null
  Set-Content (Join-Path $proj '.cursor\skills\openspec-v1.5.0\SKILL.md') 'legacy'
  Set-Content (Join-Path $proj '.cursor\skills\workflow-private\SKILL.md') 'private workflow helper'
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
  Set-Content (Join-Path $proj 'openspec\specs\keep-me\spec.md') "# keep-me Specification`n`n## Purpose`n`nKeep project behavior.`n`n### Requirement: Preserve business behavior`nThe project SHALL preserve its accepted behavior.`n`n#### Scenario: Validate accepted behavior`n- **WHEN** Doctor validates the project`n- **THEN** the accepted specification remains valid`n"

  # doctor on incomplete project fails
  $r0 = Invoke-WorkflowDoctor -ProjectRoot $proj
  Assert-True ($r0.ExitCode -ne 0) "doctor fails on incomplete project"

  Install-Workflow -SourceRoot $repoRoot -TargetRoot $proj
  Assert-True (-not (Test-Path (Join-Path $proj '.cursor\skills\openspec-v1.5.0'))) "install purges legacy skills"
  Assert-True ((Get-Content -Raw (Join-Path $proj '.cursor\skills\workflow-private\SKILL.md')) -match 'private workflow helper') "install preserves workflow-prefixed private skill"
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
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $proj
  Assert-True ((Get-Content -Raw -Encoding utf8 $generatedRule) -match 'Early project rule') "explicit reinstall restores generated rule"
  Assert-True ((Invoke-WorkflowDoctor -ProjectRoot $proj).ExitCode -eq 0) "doctor passes after explicit reinstall"

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
  $wfOnly = Join-Path $cfgDir 'workflow-only.json'
  $projRules = Join-Path $cfgDir 'project-rules.json'
  $out1 = Join-Path $cfgDir 'out1.json'
  Set-Content -Encoding utf8 $wfOnly '{"schema":"workflow-contract","rules":{"proposal":["Own Why only"],"capabilities":["Both spec and design"]}}'
  Merge-WorkflowConfig -WorkflowPath $wfOnly -ProjectPath $null -OutPath $out1
  $o1 = Get-Content -Raw $out1 | ConvertFrom-Json
  Assert-True ($o1.schema -eq 'workflow-contract') "merge workflow-only keeps schema"
  Assert-True (@($o1.rules.proposal) -contains 'Own Why only') "merge workflow-only keeps rules"
  Assert-True ((Get-Content -Raw $out1).TrimStart().StartsWith('{')) "merged configuration is strict JSON"

  Set-Content -Encoding utf8 $projRules '{"schema":"custom-schema","rules":{"proposal":["Own Why only","Project private rule"],"design":["Project design rule"]}}'
  $out2 = Join-Path $cfgDir 'out2.json'
  Merge-WorkflowConfig -WorkflowPath $wfOnly -ProjectPath $projRules -OutPath $out2
  $o2 = Get-Content -Raw $out2 | ConvertFrom-Json
  Assert-True ($o2.schema -eq 'custom-schema') "project schema overrides"
  Assert-True (@($o2.rules.proposal) -contains 'Project private rule') "project rules appended"
  Assert-True (@($o2.rules.proposal|Where-Object{$_ -eq 'Own Why only'}).Count -eq 1) "dedupes repeated rule text"
  Set-Content -Encoding utf8 (Join-Path $cfgDir 'invalid.json') '{"schema":"workflow-contract","rules":{"proposal":"not-an-array"}}'
  Assert-Throws { Merge-WorkflowConfig -WorkflowPath (Join-Path $cfgDir 'invalid.json') -ProjectPath $null -OutPath (Join-Path $cfgDir 'invalid-out.json') } 'must be an array' "strict JSON rejects invalid rule shapes"
  Set-Content -Encoding utf8 (Join-Path $cfgDir 'unknown.json') '{"schema":"workflow-contract","rules":{},"unknown":true}'
  Assert-Throws { Merge-WorkflowConfig -WorkflowPath (Join-Path $cfgDir 'unknown.json') -ProjectPath $null -OutPath (Join-Path $cfgDir 'unknown-out.json') } 'unsupported field' "strict JSON rejects unknown fields"

  # install: never overwrite project config and never reinterpret generated config as project input
  $proj2 = Join-Path $tmp 'proj2'
  New-Item -ItemType Directory -Force -Path (Join-Path $proj2 '.workflow') | Out-Null
  Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.project.json') '{"rules":{"proposal":["Keep my private rule forever"]}}'
  Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.json') '{"schema":"workflow-contract","rules":{"proposal":["generated content must not become project input"]}}'
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $proj2
  Assert-True (Test-Path (Join-Path $proj2 '.workflow\config.workflow.json')) "writes config.workflow.json"
  Assert-True (Test-Path (Join-Path $proj2 '.workflow\config.project.json')) "preserves config.project.json"
  $projCfg1 = Get-Content -Raw (Join-Path $proj2 '.workflow\config.project.json')
  Assert-True ($projCfg1 -match 'Keep my private rule forever') "preserves private project rules"
  Assert-True ($projCfg1 -notmatch 'generated content must not become project input') "does not promote generated config to project input"
  $merged1 = Get-Content -Raw (Join-Path $proj2 '.workflow\config.json')
  Assert-True ($merged1 -match 'Keep my private rule forever') "merged config includes private rule"
  Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.project.json') '{"rules":{"proposal":["Keep my private rule forever","Second private line"]}}'
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $proj2
  $projCfg2 = Get-Content -Raw (Join-Path $proj2 '.workflow\config.project.json')
  Assert-True ($projCfg2 -match 'Second private line') "second install does not overwrite project config"

  # machine sync remains explicit; doctor only reports stale generated config
  Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.project.json') '{"rules":{"proposal":["Keep my private rule forever","DoctorAutoSyncRule"]}}'
  Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.json') '{"schema":"workflow-contract","rules":{"proposal":["stale merged only"]}}'
  $sync1 = Sync-WorkflowConfig -ProjectRoot $proj2
  Assert-True ($sync1.Changed -eq $true) "sync merges when project changed"
  Assert-True ($sync1.Status -eq 'Merged') "sync status Merged"
  $healed = Get-Content -Raw (Join-Path $proj2 '.workflow\config.json')
  Assert-True ($healed -match 'DoctorAutoSyncRule') "sync writes project rule into config.json"
  $sync2 = Sync-WorkflowConfig -ProjectRoot $proj2
  Assert-True ($sync2.Changed -eq $false) "second sync is no-op when up to date"
  Assert-True ($sync2.Status -eq 'Unchanged') "sync status Unchanged"

  Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.project.json') '{"rules":{"proposal":["Keep my private rule forever","DoctorAutoSyncRule","ViaExplicitSync"]}}'
  Set-Content -Encoding utf8 (Join-Path $proj2 '.workflow\config.json') '{"schema":"workflow-contract","rules":{"proposal":["Keep my private rule forever"]}}'
  $beforeDocConfig = Get-Content -Raw (Join-Path $proj2 '.workflow\config.json')
  $rDocSync = Invoke-WorkflowDoctor -ProjectRoot $proj2
  Assert-True ($rDocSync.ExitCode -ne 0) "doctor reports stale merged config"
  $viaDoc = Get-Content -Raw (Join-Path $proj2 '.workflow\config.json')
  Assert-True ($viaDoc -eq $beforeDocConfig) "doctor does not auto-sync project rules"
  $null=Sync-WorkflowConfig -ProjectRoot $proj2
  Assert-True ((Get-Content -Raw (Join-Path $proj2 '.workflow\config.json')) -match 'ViaExplicitSync') "explicit config sync updates generated rules"

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

  $sourceGeneratedCli=Join-Path $repoRoot '.agents\skills\workflow\bin\WorkflowRuntime.psm1'
  $sourceGeneratedBackup=Join-Path $tmp 'source-generated-cli.backup';Copy-Item -LiteralPath $sourceGeneratedCli -Destination $sourceGeneratedBackup
  [IO.File]::AppendAllText($sourceGeneratedCli,"generated drift",[Text.UTF8Encoding]::new($false))
  $sourceDriftDoctor=Invoke-WorkflowDoctor -ProjectRoot $repoRoot
  Assert-True ($sourceDriftDoctor.ExitCode -ne 0 -and (($sourceDriftDoctor.Errors -join "`n") -match 'WorkflowRuntime|artifact content drift')) "source Doctor rejects generated CLI drift"
  Copy-Item -LiteralPath $sourceGeneratedBackup -Destination $sourceGeneratedCli -Force

  $bad = Join-Path $tmp 'bad'
  New-Item -ItemType Directory -Force -Path (Join-Path $bad '.workflow') | Out-Null
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\mcp.json') '{ "schemaVersion": 1, "servers": { "bad": { "transport": "stdio", "command": "x", "mystery": true } } }'
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\rules.json') '{ "schemaVersion": 1, "rules": [] }'
  Set-Content -Encoding utf8 (Join-Path $bad 'private.txt') 'must survive failed preflight'
  $badBefore=Get-TreeFingerprint $bad
  Assert-Throws { Install-Workflow -SourceRoot $repoRoot -TargetRoot $bad } 'mystery' "unknown MCP fields fail explicitly"
  Assert-True ((Get-TreeFingerprint $bad) -eq $badBefore) "invalid preflight leaves target byte-for-byte unchanged"
  Assert-True (-not(Test-Path (Join-Path $bad '.workflow\pack'))) "invalid preflight creates no partial workflow runtime"
  Set-Content -Encoding utf8 (Join-Path $bad '.workflow\mcp.json') '{ "schemaVersion": 1, "servers": { "bad": { "transport": "stdio", "command": "x", "enabled": "yes" } } }'
  Assert-Throws { Install-Workflow -SourceRoot $repoRoot -TargetRoot $bad } 'enabled.*boolean' "invalid MCP field types fail explicitly"

  # A deterministic post-preflight failure must restore every path already changed.
  $rollbackTarget=Join-Path $tmp 'rollback-install';New-Item -ItemType Directory -Force -Path (Join-Path $rollbackTarget '.cursor\skills\workflow')|Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $rollbackTarget '.workflow\specs\keep')|Out-Null
  Set-Content -Encoding utf8 (Join-Path $rollbackTarget '.cursor\skills\workflow\SKILL.md') 'old runtime'
  Set-Content -Encoding utf8 (Join-Path $rollbackTarget '.workflow\specs\keep\spec.md') 'old spec'
  Set-Content -Encoding utf8 (Join-Path $rollbackTarget 'scripts') 'project file blocks deployment directory'
  $rollbackBefore=Get-TreeFingerprint $rollbackTarget
  Assert-Throws { Install-Workflow -SourceRoot $repoRoot -TargetRoot $rollbackTarget } 'scripts|container|directory|exists' "install reports a mutation failure after preflight"
  Assert-True ((Get-TreeFingerprint $rollbackTarget) -eq $rollbackBefore) "install rollback restores the original target tree"

  # Codex-only deployment must preserve Cursor-private and current runtime content.
  $codexOnly = Join-Path $tmp 'codex-only'
  New-Item -ItemType Directory -Force -Path (Join-Path $codexOnly '.cursor\skills\openspec-private') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $codexOnly '.cursor\rules'),(Join-Path $codexOnly '.cursor\commands') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $codexOnly '.agents\skills\openspec-workflow'),(Join-Path $codexOnly '.agents\skills\private-skill') | Out-Null
  [IO.File]::WriteAllBytes((Join-Path $codexOnly '.cursor\skills\openspec-private\SKILL.md'), [byte[]](0,1,2,13,10,255))
  Set-Content -Encoding utf8 (Join-Path $codexOnly '.cursor\rules\project-only.mdc') 'project-owned cursor rule'
  Set-Content -Encoding utf8 (Join-Path $codexOnly '.cursor\rules\workflow-router.mdc') 'current private router for /workflow:* only'
  Set-Content -Encoding utf8 (Join-Path $codexOnly '.cursor\commands\workflow-apply.md') 'current project adapter'
  Set-Content -Encoding utf8 (Join-Path $codexOnly '.agents\skills\openspec-workflow\SKILL.md') 'legacy Codex runtime'
  Set-Content -Encoding utf8 (Join-Path $codexOnly '.agents\skills\private-skill\SKILL.md') 'private Codex runtime'
  $cursorFingerprint = {
    $root = Join-Path $codexOnly '.cursor'
    return (@(Get-ChildItem -LiteralPath $root -Recurse -File | Sort-Object FullName | ForEach-Object {
      $_.FullName.Substring($root.Length) + ':' + (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash
    }) -join "`n")
  }
  $cursorBefore = &$cursorFingerprint
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $codexOnly -Clients codex
  $cursorAfter = &$cursorFingerprint
  Assert-True ($cursorAfter -eq $cursorBefore) "Codex-only install preserves current and private Cursor content byte-for-byte"
  Assert-True (Test-Path (Join-Path $codexOnly '.agents\skills\workflow\SKILL.md')) "Codex-only install creates Codex skill"
  Assert-True (-not(Test-Path (Join-Path $codexOnly '.agents\skills\openspec-workflow')) -and (Get-Content -Raw (Join-Path $codexOnly '.agents\skills\private-skill\SKILL.md')) -match 'private Codex runtime') "Codex-only install removes only the exact legacy Codex skill"
  Assert-True ((Get-Content -Raw (Join-Path $codexOnly '.cursor\commands\workflow-apply.md')) -match 'current project adapter') "Codex-only install does not replace current Cursor commands"
  $codexMetadata = Get-Content -Raw (Join-Path $codexOnly '.workflow\version.json') | ConvertFrom-Json
  Assert-True ((@($codexMetadata.clients) -join ',') -eq 'codex') "Codex-only metadata records only Codex"
  Assert-True ((Invoke-WorkflowDoctor -ProjectRoot $codexOnly).ExitCode -eq 0) "Codex-only doctor ignores Cursor-private content"
  Install-Workflow -SourceRoot $repoRoot -TargetRoot $codexOnly -Clients codex
  Assert-True ((&$cursorFingerprint) -eq $cursorBefore) "Codex-only reinstall preserves installed client scope"

  # Published downstream repositories receive only the built artifact, never its neutral source.
  Build-WorkflowCodexArtifact -SourceRoot $repoRoot | Out-Null
  $publishRollback=Join-Path $tmp 'rollback-publish';New-Item -ItemType Directory -Force -Path (Join-Path $publishRollback '.agents\skills\workflow')|Out-Null
  Set-Content -Encoding utf8 (Join-Path $publishRollback '.agents\skills\workflow\private.txt') 'old published runtime'
  Set-Content -Encoding utf8 (Join-Path $publishRollback '.codex') 'project file blocks managed config directory'
  $publishRollbackBefore=Get-TreeFingerprint $publishRollback
  Assert-Throws { Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $publishRollback } '\.codex|container|directory|exists' "publication reports a mutation failure after preflight"
  Assert-True ((Get-TreeFingerprint $publishRollback) -eq $publishRollbackBefore) "publication rollback restores the original target tree"

  # A failure immediately after legacy cleanup restores project data and every bounded Cursor candidate.
  $cleanupRollback=Join-Path $tmp 'cleanup-rollback'
  New-Item -ItemType Directory -Force -Path (Join-Path $cleanupRollback 'openspec\changes\live'),(Join-Path $cleanupRollback '.workflow\changes\existing'),(Join-Path $cleanupRollback '.cursor\workflow\pack'),(Join-Path $cleanupRollback '.cursor\commands'),(Join-Path $cleanupRollback '.cursor\rules')|Out-Null
  Set-Content -Encoding utf8 (Join-Path $cleanupRollback 'openspec\design.md') 'legacy root design'
  Set-Content -Encoding utf8 (Join-Path $cleanupRollback 'openspec\changes\live\notes.md') 'active business notes'
  Set-Content -Encoding utf8 (Join-Path $cleanupRollback 'openspec\changes\live\.openspec.yaml') 'obsolete metadata'
  Set-Content -Encoding utf8 (Join-Path $cleanupRollback '.workflow\changes\existing\.openspec.yaml') 'obsolete current metadata'
  Set-Content -Encoding utf8 (Join-Path $cleanupRollback '.cursor\workflow\pack\apply.md') 'old cursor pack'
  Set-Content -Encoding utf8 (Join-Path $cleanupRollback '.cursor\commands\opsx-apply.md') 'old opsx adapter'
  Set-Content -Encoding utf8 (Join-Path $cleanupRollback '.cursor\rules\workflow-router.mdc') 'route /opsx:apply through OpenSpec workflow'
  $cleanupRollbackBefore=Get-TreeFingerprint $cleanupRollback
  try{
    $env:WORKFLOW_DEPLOY_TEST_FAILPOINT='after-legacy-cleanup'
    Assert-Throws { Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $cleanupRollback } 'after-legacy-cleanup' "publication failpoint runs after legacy cleanup"
  }finally{Remove-Item Env:WORKFLOW_DEPLOY_TEST_FAILPOINT -ErrorAction SilentlyContinue}
  Assert-True ((Get-TreeFingerprint $cleanupRollback) -eq $cleanupRollbackBefore) "publication rollback restores legacy project data and Cursor candidates byte-for-byte"

  # Root-design collisions are rejected before any target write.
  $designCollision=Join-Path $tmp 'design-collision'
  New-Item -ItemType Directory -Force -Path (Join-Path $designCollision 'openspec'),(Join-Path $designCollision '.workflow')|Out-Null
  Set-Content -Encoding utf8 (Join-Path $designCollision 'openspec\design.md') 'legacy design'
  Set-Content -Encoding utf8 (Join-Path $designCollision '.workflow\design.md') 'different current design'
  Set-Content -Encoding utf8 (Join-Path $designCollision 'private.txt') 'must remain'
  $designCollisionBefore=Get-TreeFingerprint $designCollision
  Assert-Throws { Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $designCollision } 'migration blocked.*\.workflow/design\.md' "conflicting root designs fail preflight"
  Assert-True ((Get-TreeFingerprint $designCollision) -eq $designCollisionBefore) "root-design conflict leaves target byte-for-byte unchanged"

  $invalidCleanup=Join-Path $tmp 'invalid-cleanup-shape';New-Item -ItemType Directory -Force -Path (Join-Path $invalidCleanup 'openspec'),(Join-Path $invalidCleanup '.cursor')|Out-Null
  Set-Content -Encoding utf8 (Join-Path $invalidCleanup 'openspec\schemas') 'not a schema directory'
  Set-Content -Encoding utf8 (Join-Path $invalidCleanup '.cursor\workflow') 'not a workflow namespace directory'
  $invalidCleanupBefore=Get-TreeFingerprint $invalidCleanup
  Assert-Throws { Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $invalidCleanup } 'migration blocked.*\.cursor/workflow.*openspec/schemas' "invalid legacy cleanup shapes fail preflight"
  Assert-True ((Get-TreeFingerprint $invalidCleanup) -eq $invalidCleanupBefore) "invalid cleanup shape leaves target byte-for-byte unchanged"

  # A realistic old installation converges in one standard Codex publication.
  $legacyPublished=Join-Path $tmp 'legacy-published'
  New-Item -ItemType Directory -Force -Path @(
    (Join-Path $legacyPublished 'openspec\changes\active-order'),
    (Join-Path $legacyPublished 'openspec\changes\archive\2026-01-01-old-order'),
    (Join-Path $legacyPublished 'openspec\specs\legacy-cap'),
    (Join-Path $legacyPublished '.workflow\changes\current-change'),
    (Join-Path $legacyPublished '.workflow\rules'),
    (Join-Path $legacyPublished '.agents\skills\openspec-workflow'),
    (Join-Path $legacyPublished '.agents\skills\private-skill'),
    (Join-Path $legacyPublished '.cursor\workflow\pack'),
    (Join-Path $legacyPublished '.cursor\commands'),
    (Join-Path $legacyPublished '.cursor\rules'),
    (Join-Path $legacyPublished '.cursor\skills\workflow-private')
  )|Out-Null
  $legacyDesign="# Legacy project design`n`nPreserve the root design.`n"
  Set-Content -Encoding utf8 (Join-Path $legacyPublished 'openspec\design.md') $legacyDesign
  $legacyDesignOnDisk=Get-Content -Raw (Join-Path $legacyPublished 'openspec\design.md')
  Set-Content -Encoding utf8 (Join-Path $legacyPublished 'openspec\changes\active-order\notes.md') 'active project notes'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished 'openspec\changes\active-order\.openspec.yaml') 'obsolete active metadata'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished 'openspec\changes\archive\2026-01-01-old-order\notes.md') 'archived project notes'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished 'openspec\changes\archive\2026-01-01-old-order\.openspec.yaml') 'obsolete archive metadata'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.workflow\changes\current-change\.openspec.yaml') 'obsolete current metadata'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished 'openspec\specs\legacy-cap\spec.md') "# legacy-cap Specification`n`n## Purpose`n`nPreserve legacy capability.`n`n### Requirement: Legacy behavior`nThe project SHALL preserve legacy behavior.`n`n#### Scenario: Upgrade`n- **WHEN** workflow is published`n- **THEN** legacy behavior remains specified`n"
  Set-Content -Encoding utf8 (Join-Path $legacyPublished 'openspec\specs\legacy-cap\design.md') "# legacy-cap Design`n`n## Context`nPreserved accepted design.`n"
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.workflow\rules\project.md') "# Project rule`n`nKeep project-owned guidance.`n"
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.workflow\rules.json') '{"schemaVersion":1,"rules":[{"path":"project.md","description":"Project rule","always":true,"paths":[]}]}'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.workflow\mcp.json') '{"schemaVersion":1,"servers":{}}'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.agents\skills\openspec-workflow\SKILL.md') 'old Codex runtime'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.agents\skills\private-skill\SKILL.md') 'private Codex skill'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.cursor\workflow\pack\apply.md') 'old Cursor pack'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.cursor\commands\opsx-apply.md') 'old opsx adapter'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.cursor\commands\workflow-apply.md') 'current workflow adapter'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.cursor\commands\private-command.md') 'private command'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.cursor\rules\workflow-router.mdc') 'route /opsx:apply through $openspec-workflow'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.cursor\rules\private.mdc') 'private Cursor rule'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.cursor\skills\workflow-private\SKILL.md') 'private Cursor skill'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished '.cursor\mcp.json') '{"mcpServers":{"private":{}}}'
  Set-Content -Encoding utf8 (Join-Path $legacyPublished 'AGENTS.md') "# Project guidance`n`nKeep this text outside managed blocks.`n"
  $legacyReport=Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $legacyPublished
  Assert-True (@($legacyReport.Migrated) -contains '.workflow/design.md') "migration report includes the root design"
  Assert-True (@($legacyReport.Migrated) -contains '.workflow/changes/active-order' -and @($legacyReport.Migrated) -contains '.workflow/specs/legacy-cap') "migration report includes project change and spec data"
  Assert-True (@($legacyReport.Removed) -contains 'openspec/changes/active-order/.openspec.yaml' -and @($legacyReport.Removed) -contains '.workflow/changes/current-change/.openspec.yaml') "migration report includes old and current change metadata"
  Assert-True (@($legacyReport.Removed) -contains '.cursor/workflow' -and @($legacyReport.Removed) -contains '.cursor/commands/opsx-apply.md' -and @($legacyReport.Removed) -contains '.cursor/rules/workflow-router.mdc') "migration report includes exact legacy Cursor assets"
  Assert-True ((@($legacyReport.Migrated)-join "`n") -eq (@($legacyReport.Migrated|Sort-Object -Unique)-join "`n") -and (@($legacyReport.Removed)-join "`n") -eq (@($legacyReport.Removed|Sort-Object -Unique)-join "`n")) "migration report action arrays are sorted and unique"
  Assert-True ((Get-Content -Raw (Join-Path $legacyPublished '.workflow\design.md')) -eq $legacyDesignOnDisk) "publication preserves the root design content byte-for-byte"
  Assert-True ((Test-Path (Join-Path $legacyPublished '.workflow\changes\active-order\notes.md')) -and (Test-Path (Join-Path $legacyPublished '.workflow\changes\archive\2026-01-01-old-order\notes.md'))) "publication preserves active and archived project data"
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $legacyPublished '.workflow\changes') -Recurse -Force -File|Where-Object{$_.Name -eq '.openspec.yaml'}).Count -eq 0) "publication removes legacy metadata from all change trees"
  Assert-True (-not(Test-Path (Join-Path $legacyPublished 'openspec')) -and -not(Test-Path (Join-Path $legacyPublished '.agents\skills\openspec-workflow')) -and -not(Test-Path (Join-Path $legacyPublished '.cursor\workflow'))) "publication removes superseded workflow namespaces"
  Assert-True (-not(Test-Path (Join-Path $legacyPublished '.cursor\commands\opsx-apply.md')) -and -not(Test-Path (Join-Path $legacyPublished '.cursor\rules\workflow-router.mdc'))) "publication removes old Cursor adapters"
  Assert-True ((Get-Content -Raw (Join-Path $legacyPublished '.cursor\commands\workflow-apply.md')) -match 'current workflow adapter' -and (Get-Content -Raw (Join-Path $legacyPublished '.cursor\commands\private-command.md')) -match 'private command') "publication preserves current and private Cursor commands"
  Assert-True ((Test-Path (Join-Path $legacyPublished '.cursor\rules\private.mdc')) -and (Test-Path (Join-Path $legacyPublished '.cursor\skills\workflow-private\SKILL.md')) -and (Test-Path (Join-Path $legacyPublished '.cursor\mcp.json'))) "publication preserves unrelated Cursor rules, skills, and MCP"
  Assert-True ((Get-Content -Raw (Join-Path $legacyPublished 'AGENTS.md')) -match 'Keep this text outside managed blocks') "publication preserves project AGENTS content"
  $legacyLocalCli=Join-Path $legacyPublished '.agents\skills\workflow\bin\workflow.ps1'
  $legacyLocalDoctor=((& $legacyLocalCli doctor --json -ProjectRoot $legacyPublished)|Out-String|ConvertFrom-Json)
  Assert-True ($legacyLocalDoctor.valid -eq $true -and (Invoke-WorkflowArtifactDoctor -ProjectRoot $legacyPublished -SourceRoot $repoRoot).ExitCode -eq 0) "local and Artifact Doctor accept the converged installation"
  $legacyConverged=Get-TreeFingerprint $legacyPublished
  $legacySecondReport=Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $legacyPublished
  Assert-True ((Get-TreeFingerprint $legacyPublished) -eq $legacyConverged) "second publication is filesystem-idempotent"
  Assert-True (@($legacySecondReport.Migrated).Count -eq 0 -and @($legacySecondReport.Removed).Count -eq 0) "second publication reports no completed legacy action again"

  # Both Doctors report exact residue and remain read-only.
  $doctorResidue=Join-Path $legacyPublished '.workflow\changes\doctor-residue\.openspec.yaml';New-Item -ItemType Directory -Force -Path (Split-Path -Parent $doctorResidue)|Out-Null;Set-Content -Encoding utf8 $doctorResidue 'obsolete'
  $residueBefore=Get-TreeFingerprint $legacyPublished
  $residueLocal=((& $legacyLocalCli doctor --json -ProjectRoot $legacyPublished)|Out-String|ConvertFrom-Json)
  $residueArtifact=Invoke-WorkflowArtifactDoctor -ProjectRoot $legacyPublished -SourceRoot $repoRoot
  Assert-True ($residueLocal.valid -eq $false -and (($residueLocal.errors -join "`n") -match '\.workflow/changes/doctor-residue/\.openspec\.yaml')) "published local Doctor reports the exact legacy metadata path"
  Assert-True ($residueArtifact.ExitCode -ne 0 -and (($residueArtifact.Errors -join "`n") -match '\.workflow/changes/doctor-residue/\.openspec\.yaml')) "Artifact Doctor reports the exact legacy metadata path"
  Assert-True ((Get-TreeFingerprint $legacyPublished) -eq $residueBefore) "legacy residue diagnosis is read-only"
  Remove-Item -LiteralPath (Split-Path -Parent $doctorResidue) -Recurse -Force

  $deployJsonRaw=(& pwsh -NoProfile -File (Join-Path $repoRoot 'scripts\deploy.ps1') -Source $repoRoot -Target $legacyPublished -Yes -Json)|Out-String
  $deployJson=$deployJsonRaw|ConvertFrom-Json
  Assert-True ($deployJson.version -eq '6.2.1' -and $deployJson.doctorValid -eq $true -and @($deployJson.migrated).Count -eq 0 -and @($deployJson.removed).Count -eq 0) "deploy JSON reports artifact version, idempotent actions, and Doctor validity"

  $customSource=Join-Path $tmp 'custom-source';$customSourceSkill=Join-Path $customSource '.agents\skills';$customSourceSchema=Join-Path $customSource '.workflow\schemas\portable-flow\templates'
  New-Item -ItemType Directory -Force -Path $customSourceSkill,$customSourceSchema|Out-Null
  Copy-Item -LiteralPath (Join-Path $repoRoot '.agents\skills\workflow') -Destination (Join-Path $customSourceSkill 'workflow') -Recurse -Force
  Set-Content -Encoding utf8 (Join-Path $customSource '.workflow\config.workflow.json') '{"schema":"portable-flow","rules":{}}'
  Set-Content -Encoding utf8 (Join-Path $customSource '.workflow\schemas\portable-flow\schema.json') '{"name":"portable-flow","version":1,"artifacts":[{"id":"brief","kind":"document","path":"brief.md","required":true,"requires":[],"template":"templates/brief.md","instruction":"Write the brief."}]}'
  Set-Content -Encoding utf8 (Join-Path $customSourceSchema 'brief.md') "# Brief`n"
  $customPublished=Join-Path $tmp 'custom-source-published'
  Publish-WorkflowCodexArtifact -SourceRoot $customSource -TargetRoot $customPublished|Out-Null
  Assert-True (Test-Path (Join-Path $customPublished '.workflow\schemas\portable-flow\schema.json')) "publication copies the workflow-selected custom schema"
  Assert-True (-not(Test-Path (Join-Path $customPublished '.workflow\schemas\workflow-contract'))) "publication does not require a hard-coded workflow-contract schema"
  Assert-True (((Get-Content -Raw (Join-Path $customPublished '.workflow\config.json')|ConvertFrom-Json).schema) -eq 'portable-flow') "publication records the workflow-selected custom schema"
  Assert-True ((Get-Content -Raw (Join-Path $customPublished 'AGENTS.md')) -notmatch '### Project rules') "publication omits the project-rules section when no project rules exist"

  $published = Join-Path $tmp 'published-artifact'
  New-Item -ItemType Directory -Force -Path (Join-Path $published '.agents\rules') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $published '.agents\skills\private-skill') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $published '.workflow\pack'),(Join-Path $published '.workflow\rules') | Out-Null
  New-Item -ItemType Directory -Force -Path (Join-Path $published 'scripts\lib') | Out-Null
  Set-Content -Encoding utf8 (Join-Path $published '.agents\rules\private.md') 'private rule'
  Set-Content -Encoding utf8 (Join-Path $published '.agents\skills\private-skill\SKILL.md') 'private skill'
  Set-Content -Encoding utf8 (Join-Path $published '.workflow\pack\source.md') 'must not ship'
  Set-Content -Encoding utf8 (Join-Path $published '.workflow\rules\project.md') "# Project rule`n`nPreserve project-specific guidance.`n"
  Set-Content -Encoding utf8 (Join-Path $published '.workflow\rules.json') '{"schemaVersion":1,"rules":[{"path":"project.md","description":"Project-specific guidance","always":true,"paths":[]}]}'
  Set-Content -Encoding utf8 (Join-Path $published '.workflow\mcp.json') '{"schemaVersion":1,"servers":{"project.api":{"transport":"http","url":"https://example.invalid/mcp"}}}'
  Set-Content -Encoding utf8 (Join-Path $published '.agents\rules\.workflow-managed.json') '{"files":[]}'
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\init.ps1') 'project wrapper calls Install-Workflow but is not the Workflow deployment source'
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\doctor.ps1') 'Validate a platform-neutral Workflow install; Invoke-WorkflowDoctor'
  Set-Content -Encoding utf8 (Join-Path $published 'scripts\lib\WorkflowDeploy.psm1') 'WorkflowDeploy.psm1 WorkflowVersion Install-Workflow'
  Publish-WorkflowCodexArtifact -SourceRoot $repoRoot -TargetRoot $published|Out-Null
  Assert-True (Test-Path (Join-Path $published '.workflow')) "publication preserves downstream workflow project data"
  Assert-True (-not(Test-Path (Join-Path $published '.workflow\pack'))) "publication removes source-only workflow pack"
  Assert-True (-not(Test-Path (Join-Path $published '.workflow\cli'))) "publication removes source-only CLI source"
  Assert-True (Test-Path (Join-Path $published '.workflow\schemas\workflow-contract\schema.json')) "publication includes workflow artifact contract"
  Assert-True (-not(Test-Path (Join-Path $published 'openspec'))) "publication removes legacy OpenSpec project data root"
  Assert-True (-not(Test-Path (Join-Path $published '.agents\skills\openspec-workflow'))) "publication removes legacy OpenSpec skill"
  Assert-True (Test-Path (Join-Path $published '.agents\rules\.workflow-managed.json')) "publication indexes generated project rules"
  Assert-True (Test-Path (Join-Path $published 'scripts\init.ps1')) "publication preserves a project script with only a loose workflow marker"
  Assert-True (-not(Test-Path (Join-Path $published 'scripts\doctor.ps1'))) "publication removes deployment doctor source"
  Assert-True (-not(Test-Path (Join-Path $published 'scripts\lib\WorkflowDeploy.psm1'))) "publication removes deployment module source"
  Assert-True (Test-Path (Join-Path $published '.agents\rules\private.md')) "publication preserves private rules"
  Assert-True (Test-Path (Join-Path $published '.agents\skills\private-skill\SKILL.md')) "publication preserves unrelated skills"
  Assert-True (Test-Path (Join-Path $published '.workflow\rules\project.md')) "publication preserves project-owned neutral rule source"
  Assert-True (Test-Path (Join-Path $published '.workflow\mcp.json')) "publication preserves project-owned neutral MCP source"
  Assert-True ((Get-Content -Raw (Join-Path $published '.agents\rules\project.md')) -match 'Preserve project-specific guidance') "publication compiles project-owned Codex rule"
  Assert-True ((Get-Content -Raw (Join-Path $published 'AGENTS.md')) -match 'Project-specific guidance') "publication routes project-owned rule in AGENTS"
  Assert-True ((Get-Content -Raw (Join-Path $published '.codex\config.toml')) -match 'project\.api') "publication compiles project-owned MCP configuration"
  Assert-True (Test-Path (Join-Path $published '.agents\skills\workflow\artifact.json')) "publication includes artifact metadata"
  $publishedCli=Join-Path $published '.agents\skills\workflow\bin\workflow.ps1'
  Assert-True (Test-Path $publishedCli) "publication includes repository-owned CLI"
  $publishedRuntimeText=@(Get-ChildItem -LiteralPath (Join-Path $published '.agents\skills\workflow') -Recurse -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
  Assert-True ($publishedRuntimeText -notmatch '(?im)^\s*(?:&\s*)?(?:npm|npx|openspec)(?:\.cmd|\.ps1|\.exe)?\s+(?:install|exec|status|archive|sync|validate|instructions)\b') "published runtime contains no external lifecycle package invocation"
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
    Set-Content -Encoding utf8 (Join-Path $multiMain 'spec.md') "# multi-cap Specification`n`n## Purpose`nTest delta operations.`n`n### Requirement: Alpha`nThe system SHALL keep alpha.`n`n#### Scenario: Alpha`n- **WHEN** alpha runs`n- **THEN** alpha succeeds`n`n### Requirement: Beta`nThe system SHALL keep beta.`n`n#### Scenario: Beta`n- **WHEN** beta runs`n- **THEN** beta succeeds`n`n### Requirement: Gamma`nThe system SHALL keep gamma.`n`n#### Scenario: Gamma`n- **WHEN** gamma runs`n- **THEN** gamma succeeds`n"
    Set-Content -Encoding utf8 (Join-Path $multiMain 'design.md') "# multi-cap Design`n`n## Context`nAccepted baseline.`n"
    (& $publishedCli new multi-delta --json -ProjectRoot $published) | Out-Null
    $multiRoot=Join-Path $published '.workflow\changes\multi-delta'
    Set-Content -Encoding utf8 (Join-Path $multiRoot 'proposal.md') "# Proposal`n`n## Why`nDelta coverage.`n`n## What Changes`nExercise all operations.`n`n## Capabilities`n`n### New Capabilities`nNone.`n`n### Modified Capabilities`n- multi-cap: update accepted requirements.`n`n## Impact`nTest.`n`n## Non-goals`nProduction.`n"
    Set-Content -Encoding utf8 (Join-Path $multiRoot 'design.md') "# Design`n`n## Context`nDelta operations.`n`n## Goals / Non-Goals`nVerify merge.`n`n## Decisions`nUse one delta.`n`n## Risks / Trade-offs`nNone.`n"
    Set-Content -Encoding utf8 (Join-Path $multiRoot 'tasks.md') "# Tasks`n`n- [x] 1.1 Exercise delta operations.`n"
    $multiDelta=Join-Path $multiRoot 'specs\multi-cap';New-Item -ItemType Directory -Force -Path $multiDelta|Out-Null
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') "# multi-cap Delta`n`n## ADDED Requirements`n`n### Requirement: Epsilon`nThe system SHALL add epsilon.`n`n#### Scenario: Epsilon`n- **WHEN** epsilon runs`n- **THEN** epsilon succeeds`n`n## MODIFIED Requirements`n`n### Requirement: Alpha`nThe system SHALL update alpha.`n`n#### Scenario: Updated alpha`n- **WHEN** alpha runs`n- **THEN** updated alpha succeeds`n`n## REMOVED Requirements`n`n### Requirement: Beta`n`n## RENAMED Requirements`n`nFROM: Gamma`nTO: Delta`n"
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'design.md') "# multi-cap Design`n`n## Context`nMerged design.`n"
    (& $publishedCli sync --change multi-delta --json -ProjectRoot $published) | Out-Null
    $multiMerged=Get-Content -Raw (Join-Path $multiMain 'spec.md')
    Assert-True ($multiMerged -match 'Requirement: Alpha' -and $multiMerged -match 'update alpha') "sync applies MODIFIED requirements"
    Assert-True ($multiMerged -notmatch 'Requirement: Beta') "sync applies REMOVED requirements"
    Assert-True ($multiMerged -match 'Requirement: Delta' -and $multiMerged -match 'Requirement: Epsilon' -and $multiMerged -notmatch 'Requirement: Gamma') "sync applies ADDED and RENAMED requirements"
    (& $publishedCli sync --change multi-delta --json -ProjectRoot $published) | Out-Null
    Assert-True ((Get-Content -Raw (Join-Path $multiMain 'spec.md')) -eq $multiMerged) "sync replay preserves equivalent accepted content"

    # Lifecycle writes are all-or-nothing and reject a concurrent writer.
    Set-Content -Encoding utf8 (Join-Path $multiMain 'project-notes.md') 'preserve capability-local project content'
    $transactionDeltaText="# multi-cap Delta`n`n## MODIFIED Requirements`n`n### Requirement: Alpha`nThe system SHALL publish alpha transactionally.`n`n#### Scenario: Transactional alpha`n- **WHEN** alpha publication fails`n- **THEN** every lifecycle target is restored`n"
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') $transactionDeltaText
    $secondDelta=Join-Path $multiRoot 'specs\multi-cap-two';New-Item -ItemType Directory -Force -Path $secondDelta|Out-Null
    Set-Content -Encoding utf8 (Join-Path $secondDelta 'spec.md') "# multi-cap-two Delta`n`n## ADDED Requirements`n`n### Requirement: Second capability`nThe system SHALL publish a second capability in the same transaction.`n`n#### Scenario: Publish second capability`n- **WHEN** multi-capability sync runs`n- **THEN** both capabilities commit together`n"
    Set-Content -Encoding utf8 (Join-Path $secondDelta 'design.md') "# multi-cap-two Design`n`n## Context`nMulti-capability transaction coverage.`n"
    $transactionBefore=Get-TreeFingerprint (Join-Path $published '.workflow\specs')
    $receiptBefore=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $multiRoot '.sync.json')).Hash
    try {
      $env:WORKFLOW_ENABLE_TEST_HOOKS='1'
      $env:WORKFLOW_TEST_FAILPOINT='after-first-target'
      $null=(& $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>&1 | Out-String)
      Assert-True ($LASTEXITCODE -ne 0) "multi-capability sync failpoint interrupts the transaction"
    } finally {
      Remove-Item Env:WORKFLOW_ENABLE_TEST_HOOKS -ErrorAction SilentlyContinue
      Remove-Item Env:WORKFLOW_TEST_FAILPOINT -ErrorAction SilentlyContinue
    }
    Assert-True ((Get-TreeFingerprint (Join-Path $published '.workflow\specs')) -eq $transactionBefore) "caught sync failure restores every accepted capability byte-for-byte"
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $multiRoot '.sync.json')).Hash -eq $receiptBefore) "caught sync failure restores the receipt byte-for-byte"
    Assert-True (-not(Test-Path -LiteralPath (Join-Path $published '.workflow\.mutation.lock'))) "caught sync failure releases the lifecycle lock"
    Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $published '.workflow\.transactions') -Force -ErrorAction SilentlyContinue).Count -eq 0) "caught sync failure removes transaction residue"

    $lockPath=Join-Path $published '.workflow\.mutation.lock';New-Item -ItemType Directory -Force -Path (Split-Path -Parent $lockPath)|Out-Null
    $heldLock=[IO.File]::Open($lockPath,[IO.FileMode]::Create,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try {
      $beforeConcurrent=Get-TreeFingerprint (Join-Path $published '.workflow\specs')
      $beforeConcurrentReceipt=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $multiRoot '.sync.json')).Hash
      $null=(& $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>&1 | Out-String)
      Assert-True ($LASTEXITCODE -ne 0) "a concurrent lifecycle writer is rejected"
      Assert-True ((Get-TreeFingerprint (Join-Path $published '.workflow\specs')) -eq $beforeConcurrent -and (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $multiRoot '.sync.json')).Hash -eq $beforeConcurrentReceipt -and @(Get-ChildItem -LiteralPath (Join-Path $published '.workflow\.transactions') -Force -ErrorAction SilentlyContinue).Count -eq 0) "writer rejection creates no transaction or lifecycle mutation"
      $lockedDoctor=((& $publishedCli doctor --json -ProjectRoot $published)|Out-String|ConvertFrom-Json)
      Assert-True ($lockedDoctor.valid -eq $false -and (($lockedDoctor.errors -join "`n") -match 'mutation lock')) "Doctor reports the lifecycle lock"
    } finally {
      $heldLock.Dispose()
      Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
    }

    # A hard process exit leaves committing state; Doctor observes without healing, then the next writer recovers first.
    try {
      $env:WORKFLOW_ENABLE_TEST_HOOKS='1'
      $env:WORKFLOW_TEST_FAILPOINT='crash-after-first-target'
      & $testPowerShellPath -NoProfile -ExecutionPolicy Bypass -File $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>$null | Out-Null
      $crashExit=$LASTEXITCODE
    } finally {
      Remove-Item Env:WORKFLOW_ENABLE_TEST_HOOKS -ErrorAction SilentlyContinue
      Remove-Item Env:WORKFLOW_TEST_FAILPOINT -ErrorAction SilentlyContinue
    }
    Assert-True ($crashExit -eq 86) "crash failpoint exits the mutating process after its first target"
    Assert-True ((Get-TreeFingerprint (Join-Path $published '.workflow\specs')) -ne $transactionBefore) "interrupted commit leaves observable partial target state for recovery"
    $residueBefore=Get-TreeFingerprint (Join-Path $published '.workflow\.transactions')
    $staleLockBefore=(Get-FileHash -Algorithm SHA256 -LiteralPath $lockPath).Hash
    $interruptedDoctor=((& $publishedCli doctor --json -ProjectRoot $published)|Out-String|ConvertFrom-Json)
    Assert-True ($interruptedDoctor.valid -eq $false -and (($interruptedDoctor.errors -join "`n") -match 'mutation lock') -and (($interruptedDoctor.errors -join "`n") -match 'committing')) "Doctor reports interrupted transaction and stale lock"
    Assert-True ((Get-TreeFingerprint (Join-Path $published '.workflow\.transactions')) -eq $residueBefore -and (Get-FileHash -Algorithm SHA256 -LiteralPath $lockPath).Hash -eq $staleLockBefore) "Doctor leaves interrupted transaction state byte-for-byte unchanged"
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') 'invalid delta after interruption'
    $null=(& $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>&1|Out-String)
    Assert-True ($LASTEXITCODE -ne 0) "post-crash sync can fail planning after recovery"
    Assert-True ((Get-TreeFingerprint (Join-Path $published '.workflow\specs')) -eq $transactionBefore -and (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $multiRoot '.sync.json')).Hash -eq $receiptBefore) "next writer restores interrupted targets before recomputing the plan"
    Assert-True (-not(Test-Path -LiteralPath $lockPath) -and @(Get-ChildItem -LiteralPath (Join-Path $published '.workflow\.transactions') -Force -ErrorAction SilentlyContinue).Count -eq 0) "recovery takes over the stale lock and removes transaction residue"
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') $transactionDeltaText

    # Receipt failure rolls back every earlier specification and design write.
    try {
      $env:WORKFLOW_ENABLE_TEST_HOOKS='1'
      $env:WORKFLOW_TEST_FAILPOINT='before-receipt-target'
      $null=(& $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>&1|Out-String)
      Assert-True ($LASTEXITCODE -ne 0) "receipt failpoint interrupts sync after capability writes"
    } finally {
      Remove-Item Env:WORKFLOW_ENABLE_TEST_HOOKS -ErrorAction SilentlyContinue
      Remove-Item Env:WORKFLOW_TEST_FAILPOINT -ErrorAction SilentlyContinue
    }
    Assert-True ((Get-TreeFingerprint (Join-Path $published '.workflow\specs')) -eq $transactionBefore -and (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $multiRoot '.sync.json')).Hash -eq $receiptBefore) "receipt failure restores every earlier lifecycle write"

    # Unsafe transaction journals block mutation and are never auto-deleted.
    $unsafeId=[guid]::NewGuid().ToString('N');$unsafeRoot=Join-Path $published ".workflow\.transactions\$unsafeId";New-Item -ItemType Directory -Force -Path $unsafeRoot|Out-Null
    $unsafeJournal=[ordered]@{schemaVersion=1;id=$unsafeId;phase='prepared';operation='sync';createdAt=[DateTimeOffset]::UtcNow.ToString('o');targets=@([ordered]@{target='../escape';operation='replace';existed=$false;original='';prepared='prepared/0';role='spec'})}|ConvertTo-Json -Depth 6 -Compress
    Set-Content -Encoding utf8 (Join-Path $unsafeRoot 'journal.json') $unsafeJournal
    $unsafeBefore=Get-TreeFingerprint $unsafeRoot
    $null=(& $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>&1|Out-String)
    Assert-True ($LASTEXITCODE -ne 0) "sync rejects an unsafe recovery journal"
    $unsafeDoctor=((& $publishedCli doctor --json -ProjectRoot $published)|Out-String|ConvertFrom-Json)
    Assert-True ($unsafeDoctor.valid -eq $false -and (($unsafeDoctor.errors -join "`n") -match 'unsafe target')) "Doctor reports an unsafe transaction journal"
    Assert-True ((Get-TreeFingerprint $unsafeRoot) -eq $unsafeBefore -and (Get-TreeFingerprint (Join-Path $published '.workflow\specs')) -eq $transactionBefore) "unsafe journal diagnosis and mutation rejection are read-only"
    Remove-Item -LiteralPath $unsafeRoot -Recurse -Force

    # A valid prepared transaction is discarded without touching its declared target.
    $preparedId=[guid]::NewGuid().ToString('N');$preparedRoot=Join-Path $published ".workflow\.transactions\$preparedId";New-Item -ItemType Directory -Force -Path $preparedRoot|Out-Null
    $preparedJournal=[ordered]@{schemaVersion=1;id=$preparedId;phase='prepared';operation='sync';createdAt=[DateTimeOffset]::UtcNow.ToString('o');targets=@([ordered]@{target='.workflow/specs/prepared-fixture';operation='replace';existed=$false;original='';prepared='prepared/0';role='capability'})}|ConvertTo-Json -Depth 6 -Compress
    Set-Content -Encoding utf8 (Join-Path $preparedRoot 'journal.json') $preparedJournal
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') 'invalid delta after prepared transaction'
    $null=(& $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>&1|Out-String)
    Assert-True ($LASTEXITCODE -ne 0 -and -not(Test-Path -LiteralPath $preparedRoot) -and -not(Test-Path -LiteralPath (Join-Path $published '.workflow\specs\prepared-fixture'))) "next writer discards prepared transaction before planning"
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') $transactionDeltaText

    # A committed journal keeps its published targets; the next writer only removes residue.
    try {
      $env:WORKFLOW_ENABLE_TEST_HOOKS='1'
      $env:WORKFLOW_TEST_FAILPOINT='crash-after-committed'
      & $testPowerShellPath -NoProfile -ExecutionPolicy Bypass -File $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>$null|Out-Null
      $committedCrashExit=$LASTEXITCODE
    } finally {
      Remove-Item Env:WORKFLOW_ENABLE_TEST_HOOKS -ErrorAction SilentlyContinue
      Remove-Item Env:WORKFLOW_TEST_FAILPOINT -ErrorAction SilentlyContinue
    }
    $committedTree=Get-TreeFingerprint (Join-Path $published '.workflow\specs');$committedReceipt=(Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $multiRoot '.sync.json')).Hash
    $committedDoctor=((& $publishedCli doctor --json -ProjectRoot $published)|Out-String|ConvertFrom-Json)
    Assert-True ($committedCrashExit -eq 86 -and $committedDoctor.valid -eq $false -and (($committedDoctor.errors -join "`n") -match 'committed')) "Doctor reports committed transaction cleanup residue"
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') 'invalid delta after committed transaction'
    $null=(& $publishedCli sync --change multi-delta --json -ProjectRoot $published 2>&1|Out-String)
    Assert-True ($LASTEXITCODE -ne 0 -and (Get-TreeFingerprint (Join-Path $published '.workflow\specs')) -eq $committedTree -and (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $multiRoot '.sync.json')).Hash -eq $committedReceipt) "committed recovery preserves published targets before planning"
    Assert-True ((Get-Content -Raw (Join-Path $multiMain 'project-notes.md')).Trim() -eq 'preserve capability-local project content') "capability directory publication preserves project-local files"
    Assert-True (-not(Test-Path -LiteralPath $lockPath) -and @(Get-ChildItem -LiteralPath (Join-Path $published '.workflow\.transactions') -Force -ErrorAction SilentlyContinue).Count -eq 0) "committed recovery removes only lock and transaction residue"
    Set-Content -Encoding utf8 (Join-Path $multiDelta 'spec.md') $transactionDeltaText

    # Rename collision must fail without altering accepted content.
    (& $publishedCli new rename-collision --json -ProjectRoot $published) | Out-Null
    $renameRoot=Join-Path $published '.workflow\changes\rename-collision'
    Set-Content -Encoding utf8 (Join-Path $renameRoot 'proposal.md') "# Proposal`n`n## Why`nCollision coverage.`n`n## What Changes`nReject ambiguous rename.`n`n## Capabilities`n`n### New Capabilities`nNone.`n`n### Modified Capabilities`n- multi-cap: reject collision.`n`n## Impact`nTest.`n`n## Non-goals`nProduction.`n"
    Set-Content -Encoding utf8 (Join-Path $renameRoot 'design.md') "# Design`n`n## Context`nRename collision.`n`n## Goals / Non-Goals`nReject ambiguity.`n`n## Decisions`nValidate first.`n`n## Risks / Trade-offs`nNone.`n"
    Set-Content -Encoding utf8 (Join-Path $renameRoot 'tasks.md') "# Tasks`n`n- [x] 1.1 Reject rename collision.`n"
    $renameDelta=Join-Path $renameRoot 'specs\multi-cap';New-Item -ItemType Directory -Force -Path $renameDelta|Out-Null
    Set-Content -Encoding utf8 (Join-Path $renameDelta 'spec.md') "# multi-cap Delta`n`n## RENAMED Requirements`n`nFROM: Alpha`nTO: Delta`n"
    Set-Content -Encoding utf8 (Join-Path $renameDelta 'design.md') "# multi-cap Design`n`n## Context`nCollision must fail.`n"
    $beforeRenameCollision=Get-Content -Raw (Join-Path $multiMain 'spec.md')
    $null=(& $publishedCli sync --change rename-collision --json -ProjectRoot $published 2>&1 | Out-String)
    Assert-True ($LASTEXITCODE -ne 0) "sync rejects a rename target that already exists"
    Assert-True ((Get-Content -Raw (Join-Path $multiMain 'spec.md')) -eq $beforeRenameCollision) "rename collision leaves accepted spec unchanged"

    # Archive publishes specs, creates the archive, and removes the active change as one transaction.
    (& $publishedCli new archive-transaction --json -ProjectRoot $published)|Out-Null
    $archiveChange=Join-Path $published '.workflow\changes\archive-transaction'
    Set-Content -Encoding utf8 (Join-Path $archiveChange 'proposal.md') "# Proposal`n`n## Why`nArchive safety.`n`n## What Changes`nMake archive atomic.`n`n## Capabilities`n`n### New Capabilities`n- archive-cap: archive transaction coverage.`n`n### Modified Capabilities`nNone.`n`n## Impact`nTest.`n`n## Non-goals`nProduction.`n"
    Set-Content -Encoding utf8 (Join-Path $archiveChange 'design.md') "# Design`n`n## Context`nArchive transaction.`n`n## Goals / Non-Goals`nKeep active state on failure.`n`n## Decisions`nUse one transaction.`n`n## Risks / Trade-offs`nNone.`n"
    Set-Content -Encoding utf8 (Join-Path $archiveChange 'tasks.md') "# Tasks`n`n- [x] 1.1 Verify archive rollback.`n"
    $archiveDelta=Join-Path $archiveChange 'specs\archive-cap';New-Item -ItemType Directory -Force -Path $archiveDelta|Out-Null
    Set-Content -Encoding utf8 (Join-Path $archiveDelta 'spec.md') "# archive-cap Delta`n`n## ADDED Requirements`n`n### Requirement: Atomic archive`nThe system SHALL archive lifecycle state atomically.`n`n#### Scenario: Archive target fails`n- **WHEN** archive commit stops after destination creation`n- **THEN** the active change and accepted specs are restored`n"
    Set-Content -Encoding utf8 (Join-Path $archiveDelta 'design.md') "# archive-cap Design`n`n## Context`nArchive transaction coverage.`n"
    $archiveChangeBefore=Get-TreeFingerprint $archiveChange;$archiveDestination=Join-Path $published ('.workflow\changes\archive\'+(Get-Date -Format 'yyyy-MM-dd')+'-archive-transaction');$archiveAccepted=Join-Path $published '.workflow\specs\archive-cap'
    try {
      $env:WORKFLOW_ENABLE_TEST_HOOKS='1'
      $env:WORKFLOW_TEST_FAILPOINT='after-archive-target'
      $null=(& $publishedCli archive archive-transaction --json -ProjectRoot $published 2>&1|Out-String)
      Assert-True ($LASTEXITCODE -ne 0) "archive failpoint interrupts after destination creation"
    } finally {
      Remove-Item Env:WORKFLOW_ENABLE_TEST_HOOKS -ErrorAction SilentlyContinue
      Remove-Item Env:WORKFLOW_TEST_FAILPOINT -ErrorAction SilentlyContinue
    }
    Assert-True ((Get-TreeFingerprint $archiveChange) -eq $archiveChangeBefore) "archive failure restores the complete active change byte-for-byte"
    Assert-True (-not(Test-Path -LiteralPath $archiveDestination) -and -not(Test-Path -LiteralPath $archiveAccepted)) "archive failure removes destination and accepted-spec writes"
    Assert-True (-not(Test-Path -LiteralPath $lockPath) -and @(Get-ChildItem -LiteralPath (Join-Path $published '.workflow\.transactions') -Force -ErrorAction SilentlyContinue).Count -eq 0) "archive rollback releases lock and removes transaction residue"

    $duplicateMain=Join-Path $published '.workflow\specs\duplicate-cap';New-Item -ItemType Directory -Force -Path $duplicateMain|Out-Null
    Set-Content -Encoding utf8 (Join-Path $duplicateMain 'spec.md') "# duplicate-cap Specification`n`n## Purpose`nDuplicate validation.`n`n### Requirement: Same name`nThe system SHALL do one thing.`n`n#### Scenario: One`n- **WHEN** one runs`n- **THEN** one succeeds`n`n### Requirement: Same name`nThe system SHALL do another thing.`n`n#### Scenario: Two`n- **WHEN** two runs`n- **THEN** two succeeds`n"
    Set-Content -Encoding utf8 (Join-Path $duplicateMain 'design.md') "# duplicate-cap Design`n`n## Context`nInvalid duplicate fixture.`n"
    $duplicateDoctor=((& $publishedCli doctor --json -ProjectRoot $published)|Out-String|ConvertFrom-Json)
    Assert-True ($duplicateDoctor.valid -eq $false -and (($duplicateDoctor.errors -join "`n") -match 'duplicate requirement name')) "local Doctor rejects duplicate accepted requirement names"
    Remove-Item -LiteralPath $duplicateMain -Recurse -Force

    # Doctor must detect drift in a file covered by the local artifact manifest.
    $manifestedPrompt=Join-Path $published '.agents\skills\workflow\references\prompts\apply.md'
    $manifestedBackup=Join-Path $tmp 'manifested-prompt.backup';Copy-Item -LiteralPath $manifestedPrompt -Destination $manifestedBackup
    [IO.File]::AppendAllText($manifestedPrompt,"manifest drift",[Text.UTF8Encoding]::new($false))
    $driftedLocalDoctor=((& $publishedCli doctor --json -ProjectRoot $published) | Out-String | ConvertFrom-Json)
    Assert-True ($driftedLocalDoctor.valid -eq $false) "published local CLI doctor detects manifested artifact drift"
    Copy-Item -LiteralPath $manifestedBackup -Destination $manifestedPrompt -Force

    $extraArtifactFile=Join-Path $published '.agents\skills\workflow\private-extra.txt';Set-Content -Encoding utf8 $extraArtifactFile 'not in manifest'
    $extraLocalDoctor=((& $publishedCli doctor --json -ProjectRoot $published)|Out-String|ConvertFrom-Json)
    $extraArtifactDoctor=Invoke-WorkflowArtifactDoctor -ProjectRoot $published -SourceRoot $repoRoot
    Assert-True ($extraLocalDoctor.valid -eq $false -and (($extraLocalDoctor.errors -join "`n") -match 'unmanifested')) "published local Doctor rejects an unmanifested runtime file"
    Assert-True ($extraArtifactDoctor.ExitCode -ne 0 -and (($extraArtifactDoctor.Errors -join "`n") -match 'unmanifested')) "Artifact Doctor rejects an unmanifested runtime file"
    Remove-Item -LiteralPath $extraArtifactFile -Force

    $selectedConfig=Join-Path $published '.workflow\config.json';$selectedConfigBackup=Join-Path $tmp 'selected-config.backup';Copy-Item -LiteralPath $selectedConfig -Destination $selectedConfigBackup
    Set-Content -Encoding utf8 $selectedConfig '{"schema":"missing-schema","rules":{}}'
    $missingSchemaLocal=((& $publishedCli doctor --json -ProjectRoot $published)|Out-String|ConvertFrom-Json)
    $missingSchemaArtifact=Invoke-WorkflowArtifactDoctor -ProjectRoot $published -SourceRoot $repoRoot
    Assert-True ($missingSchemaLocal.valid -eq $false -and (($missingSchemaLocal.errors -join "`n") -match 'missing workflow schema')) "published local Doctor rejects the missing selected schema"
    Assert-True ($missingSchemaArtifact.ExitCode -ne 0 -and (($missingSchemaArtifact.Errors -join "`n") -match 'missing workflow schema')) "Artifact Doctor rejects the missing selected schema"
    Copy-Item -LiteralPath $selectedConfigBackup -Destination $selectedConfig -Force

    # `new` must use the configured schema rather than a built-in workflow-contract path.
    $custom=Join-Path $tmp 'custom-schema-project';$customSchema=Join-Path $custom '.workflow\schemas\brief-flow';New-Item -ItemType Directory -Force -Path (Join-Path $customSchema 'templates')|Out-Null
    Set-Content -Encoding utf8 (Join-Path $custom '.workflow\config.workflow.json') '{"schema":"brief-flow","rules":{}}'
    Set-Content -Encoding utf8 (Join-Path $custom '.workflow\config.json') '{"schema":"brief-flow","rules":{}}'
    Set-Content -Encoding utf8 (Join-Path $customSchema 'schema.json') '{"name":"brief-flow","version":1,"artifacts":[{"id":"brief","kind":"document","path":"drafts/brief.md","required":true,"requires":[],"template":"templates/brief.md","instruction":"Write a brief."}]}'
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
