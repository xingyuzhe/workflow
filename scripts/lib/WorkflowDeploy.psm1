# WorkflowDeploy.psm1 — shared init/doctor logic for Workflow v2

$script:WorkflowVersion = '2.1.0'
$script:WorkflowAgentsStart = '<!-- BEGIN WORKFLOW MANAGED -->'
$script:WorkflowAgentsEnd = '<!-- END WORKFLOW MANAGED -->'
$script:WorkflowCodexConfigStart = '# BEGIN WORKFLOW MANAGED MCP'
$script:WorkflowCodexConfigEnd = '# END WORKFLOW MANAGED MCP'

function Resolve-WorkflowPath {
  param([Parameter(Mandatory)][string]$Path)
  $p = $Path.Trim().Trim('"').Trim("'")
  # Git Bash / MSYS: /d/work/bill -> D:\work\bill
  if ($p -match '^/([a-zA-Z])/(.*)$') {
    $drive = $Matches[1].ToUpperInvariant()
    $rest = ($Matches[2] -replace '/', '\')
    $p = "${drive}:\$rest"
  }
  elseif ($p -match '^([a-zA-Z]):/(.*)$') {
    $drive = $Matches[1].ToUpperInvariant()
    $rest = ($Matches[2] -replace '/', '\')
    $p = "${drive}:\$rest"
  }
  elseif ($p -match '^([a-zA-Z]):\\') {
    $p = $p.Substring(0, 1).ToUpperInvariant() + $p.Substring(1)
  }
  return [System.IO.Path]::GetFullPath($p)
}

function Get-WorkflowNamespaceSkillDirs {
  param([Parameter(Mandatory)][string]$SkillsRoot)
  if (-not (Test-Path $SkillsRoot)) { return @() }
  Get-ChildItem -Path $SkillsRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object {
      $_.Name -like 'superpowers*' -or
      $_.Name -like 'openspec*' -or
      $_.Name -like 'grilling*' -or
      $_.Name -like 'workflow*'
    }
}

function Remove-WorkflowNamespaceSkills {
  param([Parameter(Mandatory)][string]$SkillsRoot)
  Get-WorkflowNamespaceSkillDirs -SkillsRoot $SkillsRoot | ForEach-Object {
    Remove-Item -LiteralPath $_.FullName -Recurse -Force
  }
}

function Remove-WorkflowOwnedEntries {
  param(
    [Parameter(Mandatory)][string]$RulesRoot,
    [Parameter(Mandatory)][string]$CommandsRoot
  )
  if (Test-Path $CommandsRoot) {
    Get-ChildItem -Path $CommandsRoot -File -Filter 'opsx-*.md' -ErrorAction SilentlyContinue |
      Remove-Item -Force
    Get-ChildItem -Path $CommandsRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'openspec*' -or $_.Name -like 'superpowers*' } |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
  }
  if (Test-Path $RulesRoot) {
    # flat obsolete names
    @(
      'superpowers-bootstrap.mdc',
      'superpowers-router.mdc',
      'workflow-bootstrap.mdc'
    ) | ForEach-Object {
      $p = Join-Path $RulesRoot $_
      if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
    }
    # versioned rule dirs from v1
    Get-ChildItem -Path $RulesRoot -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'superpowers*' -or $_.Name -like 'openspec*' } |
      ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
  }
}

function Copy-WorkflowTree {
  param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination
  )
  if (-not (Test-Path $Source)) {
    throw "Source missing: $Source"
  }
  $srcFull = (Resolve-Path -LiteralPath $Source).Path
  if (Test-Path $Destination) {
    $dstFull = (Resolve-Path -LiteralPath $Destination).Path
    if ($srcFull -eq $dstFull) {
      return
    }
    Remove-Item -LiteralPath $Destination -Recurse -Force
  }
  $destParent = Split-Path -Parent $Destination
  if ($destParent -and -not (Test-Path $destParent)) {
    New-Item -ItemType Directory -Force -Path $destParent | Out-Null
  }
  Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
}

function Get-WorkflowManifestFiles {
  @(
    '.cursor/workflow/pack/prompts/apply.md',
    '.cursor/workflow/pack/prompts/explore.md',
    '.cursor/workflow/pack/prompts/new.md',
    '.cursor/workflow/pack/prompts/continue.md',
    '.cursor/workflow/pack/prompts/ff.md',
    '.cursor/workflow/pack/prompts/verify.md',
    '.cursor/workflow/pack/prompts/sync.md',
    '.cursor/workflow/pack/prompts/archive.md',
    '.cursor/workflow/pack/prompts/grill.md',
    '.cursor/workflow/pack/prompts/branch.md',
    '.cursor/workflow/pack/prompts/finish.md',
    '.cursor/workflow/pack/prompts/doctor.md',
    '.cursor/workflow/pack/gates/tdd.md',
    '.cursor/workflow/pack/gates/verify.md',
    '.cursor/workflow/pack/gates/debug.md',
    '.cursor/rules/workflow-router.mdc',
    '.cursor/commands/opsx-explore.md',
    '.cursor/commands/opsx-new.md',
    '.cursor/commands/opsx-ff.md',
    '.cursor/commands/opsx-continue.md',
    '.cursor/commands/opsx-grill.md',
    '.cursor/commands/opsx-apply.md',
    '.cursor/commands/opsx-verify.md',
    '.cursor/commands/opsx-sync.md',
    '.cursor/commands/opsx-archive.md',
    '.cursor/commands/opsx-doctor.md',
    'AGENTS.md',
    '.agents/skills/openspec-workflow/SKILL.md',
    '.agents/skills/openspec-workflow/agents/openai.yaml',
    '.agents/skills/openspec-workflow/references/prompts/apply.md',
    '.agents/skills/openspec-workflow/references/prompts/explore.md',
    '.agents/skills/openspec-workflow/references/prompts/new.md',
    '.agents/skills/openspec-workflow/references/prompts/continue.md',
    '.agents/skills/openspec-workflow/references/prompts/ff.md',
    '.agents/skills/openspec-workflow/references/prompts/verify.md',
    '.agents/skills/openspec-workflow/references/prompts/sync.md',
    '.agents/skills/openspec-workflow/references/prompts/archive.md',
    '.agents/skills/openspec-workflow/references/prompts/grill.md',
    '.agents/skills/openspec-workflow/references/prompts/branch.md',
    '.agents/skills/openspec-workflow/references/prompts/finish.md',
    '.agents/skills/openspec-workflow/references/prompts/doctor.md',
    '.agents/skills/openspec-workflow/references/gates/tdd.md',
    '.agents/skills/openspec-workflow/references/gates/verify.md',
    '.agents/skills/openspec-workflow/references/gates/debug.md',
    '.agents/rules/.workflow-managed.json',
    '.agents/workflow/version.json',
    '.agents/workflow/manifest.json',
    'openspec/schemas/workflow-spec/schema.yaml',
    'openspec/config.workflow.yaml',
    'openspec/config.project.yaml',
    'openspec/config.yaml',
    '.cursor/workflow/version.json',
    '.cursor/workflow/manifest.json'
  )
}

function Read-WorkflowUtf8Text {
  param([Parameter(Mandatory)][string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function Write-WorkflowUtf8Text {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Text
  )
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  # UTF-8 with BOM helps Windows PowerShell 5.1 round-trip Chinese safely
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($true))
}

function Get-WorkflowCursorProjectRules {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $rulesRoot = Join-Path $ProjectRoot '.cursor/rules'
  if (-not (Test-Path -LiteralPath $rulesRoot)) { return @() }
  return @(Get-ChildItem -LiteralPath $rulesRoot -File -Filter '*.mdc' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'workflow-router.mdc' })
}

function Get-WorkflowMdcMetadata {
  param([Parameter(Mandatory)][string]$Path)
  $text = Read-WorkflowUtf8Text -Path $Path
  $description = ''
  $globs = ''
  $alwaysApply = $false
  if ($text -match '(?ms)^---\s*\r?\n(.*?)\r?\n---') {
    $front = $Matches[1]
    if ($front -match '(?m)^description:\s*(.+)$') { $description = $Matches[1].Trim() }
    if ($front -match '(?m)^globs:\s*(.*)$') { $globs = $Matches[1].Trim() }
    if ($front -match '(?m)^alwaysApply:\s*true\s*$') { $alwaysApply = $true }
  }
  return [pscustomobject]@{ Description = $description; Globs = $globs; AlwaysApply = $alwaysApply }
}

function Install-WorkflowCodexRules {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $dstRoot = Join-Path $ProjectRoot '.agents/rules'
  New-Item -ItemType Directory -Force -Path $dstRoot | Out-Null
  $indexPath = Join-Path $dstRoot '.workflow-managed.json'
  if (Test-Path -LiteralPath $indexPath) {
    try {
      $old = Get-Content -Raw -Encoding utf8 -LiteralPath $indexPath | ConvertFrom-Json
      foreach ($name in @($old.files)) {
        $oldPath = Join-Path $dstRoot $name
        if (Test-Path -LiteralPath $oldPath -PathType Leaf) { Remove-Item -LiteralPath $oldPath -Force }
      }
    } catch { }
  }

  $entries = New-Object System.Collections.Generic.List[object]
  foreach ($rule in (Get-WorkflowCursorProjectRules -ProjectRoot $ProjectRoot)) {
    $name = ([IO.Path]::GetFileNameWithoutExtension($rule.Name) + '.md')
    Copy-Item -LiteralPath $rule.FullName -Destination (Join-Path $dstRoot $name) -Force
    $meta = Get-WorkflowMdcMetadata -Path $rule.FullName
    [void]$entries.Add([pscustomobject]@{
      Name = $name
      Description = $meta.Description
      Globs = $meta.Globs
      AlwaysApply = $meta.AlwaysApply
    })
  }
  @{ files = @($entries | ForEach-Object { $_.Name }) } | ConvertTo-Json | Set-Content -Encoding utf8 -LiteralPath $indexPath
  return $entries.ToArray()
}

function Convert-WorkflowPromptForCodex {
  param([Parameter(Mandatory)][string]$Text)
  $out = $Text.Replace('.cursor/workflow/pack/gates/', '../gates/')
  $out = $out.Replace('.cursor/workflow/state.json', '.agents/workflow/state.json')
  $out = $out.Replace('`state.json` exists under `.cursor/workflow/`', '`.agents/workflow/state.json` exists')
  return $out
}

function Install-WorkflowCodexSkill {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TargetRoot
  )
  $srcSkill = Join-Path $SourceRoot '.agents/skills/openspec-workflow'
  $dstSkill = Join-Path $TargetRoot '.agents/skills/openspec-workflow'
  foreach ($rel in @('SKILL.md', 'agents/openai.yaml')) {
    $src = Join-Path $srcSkill $rel
    if (-not (Test-Path -LiteralPath $src)) { throw "Source missing: $src" }
    $dst = Join-Path $dstSkill $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    if ((Resolve-Path -LiteralPath $src).Path -ne [IO.Path]::GetFullPath($dst)) {
      Copy-Item -LiteralPath $src -Destination $dst -Force
    }
  }

  $refs = Join-Path $dstSkill 'references'
  if (Test-Path -LiteralPath $refs) { Remove-Item -LiteralPath $refs -Recurse -Force }
  foreach ($kind in @('prompts', 'gates')) {
    $srcDir = Join-Path $SourceRoot ".cursor/workflow/pack/$kind"
    $dstDir = Join-Path $refs $kind
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    Get-ChildItem -LiteralPath $srcDir -File -Filter '*.md' | ForEach-Object {
      $text = Read-WorkflowUtf8Text -Path $_.FullName
      if ($kind -eq 'prompts') { $text = Convert-WorkflowPromptForCodex -Text $text }
      Write-WorkflowUtf8Text -Path (Join-Path $dstDir $_.Name) -Text $text
    }
  }
}

function Get-WorkflowAgentsBlock {
  param([object[]]$RuleEntries = @())
  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add($script:WorkflowAgentsStart)
  [void]$lines.Add('## OpenSpec workflow')
  [void]$lines.Add('')
  [void]$lines.Add('Use `$openspec-workflow` for OpenSpec lifecycle work. Treat `/opsx:name`, `/opsx-name`, `$openspec-workflow name`, and a clear natural-language lifecycle request as equivalent.')
  [void]$lines.Add('')
  [void]$lines.Add('Route operations as follows: `explore`, `new`, `ff`, `continue`, `grill`, `apply`, `verify`, `sync`, `archive`, and `doctor`. Bugs, test failures, and unexpected behavior use the skill debug gate.')
  [void]$lines.Add('')
  [void]$lines.Add('- Treat `openspec/config.yaml` as generated from `openspec/config.workflow.yaml` and `openspec/config.project.yaml`; do not hand-edit it.')
  [void]$lines.Add('- Reconcile `.agents/workflow/state.json` with `openspec status`; CLI output wins and missing local state never blocks work.')
  [void]$lines.Add('- Preserve unrelated user changes. Do not merge, push, open a PR, discard a branch, or archive without the authorization required by the workflow.')
  if (@($RuleEntries).Count -gt 0) {
    [void]$lines.Add('')
    [void]$lines.Add('### Migrated project rules')
    [void]$lines.Add('')
    foreach ($entry in $RuleEntries) {
      $desc = if ($entry.Description) { ' - ' + $entry.Description } else { '' }
      if ($entry.AlwaysApply) {
        [void]$lines.Add('- Read `.agents/rules/' + $entry.Name + '` before any work (always apply)' + $desc + '.')
      } elseif ($entry.Globs) {
        [void]$lines.Add('- Read `.agents/rules/' + $entry.Name + '` before changing files matching `' + $entry.Globs + '`' + $desc + '.')
      } else {
        [void]$lines.Add('- Read `.agents/rules/' + $entry.Name + '` when its subject is relevant' + $desc + '.')
      }
    }
  }
  [void]$lines.Add($script:WorkflowAgentsEnd)
  return ($lines -join "`n")
}

function Install-WorkflowAgentsGuidance {
  param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [object[]]$RuleEntries = @()
  )
  $path = Join-Path $ProjectRoot 'AGENTS.md'
  $existing = if (Test-Path -LiteralPath $path) { Read-WorkflowUtf8Text -Path $path } else { '' }
  $block = Get-WorkflowAgentsBlock -RuleEntries $RuleEntries
  $pattern = '(?ms)' + [regex]::Escape($script:WorkflowAgentsStart) + '.*?' + [regex]::Escape($script:WorkflowAgentsEnd)
  if ($existing -match $pattern) {
    $updated = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $block }, 1)
  } elseif ($existing.Trim()) {
    $updated = $existing.TrimEnd() + "`n`n" + $block + "`n"
  } else {
    $updated = "# Repository guidance`n`n" + $block + "`n"
  }
  Write-WorkflowUtf8Text -Path $path -Text $updated
}

function ConvertTo-WorkflowTomlString {
  param([AllowNull()][string]$Value)
  if ($null -eq $Value) { return '""' }
  return '"' + $Value.Replace('\', '\\').Replace('"', '\"').Replace("`r", '\r').Replace("`n", '\n') + '"'
}

function Install-WorkflowCodexMcpConfig {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $cursorPath = Join-Path $ProjectRoot '.cursor/mcp.json'
  if (-not (Test-Path -LiteralPath $cursorPath)) { return }
  $json = Get-Content -Raw -Encoding utf8 -LiteralPath $cursorPath | ConvertFrom-Json
  if (-not $json.mcpServers) { return }
  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add($script:WorkflowCodexConfigStart)
  [void]$lines.Add('# Generated from .cursor/mcp.json by Workflow. Edit the Cursor source or project-owned TOML outside this block.')
  foreach ($prop in $json.mcpServers.psobject.Properties) {
    $name = $prop.Name
    $server = $prop.Value
    [void]$lines.Add('')
    [void]$lines.Add("[mcp_servers.$name]")
    if ($server.command) { [void]$lines.Add('command = ' + (ConvertTo-WorkflowTomlString "$($server.command)")) }
    if ($server.args) {
      $args = @($server.args | ForEach-Object { ConvertTo-WorkflowTomlString "$_" }) -join ', '
      [void]$lines.Add("args = [$args]")
    }
    if ($server.env) {
      [void]$lines.Add('')
      [void]$lines.Add("[mcp_servers.$name.env]")
      foreach ($envProp in $server.env.psobject.Properties) {
        [void]$lines.Add("$($envProp.Name) = " + (ConvertTo-WorkflowTomlString "$($envProp.Value)"))
      }
    }
  }
  [void]$lines.Add($script:WorkflowCodexConfigEnd)
  $block = $lines -join "`n"
  $path = Join-Path $ProjectRoot '.codex/config.toml'
  $existing = if (Test-Path -LiteralPath $path) { Read-WorkflowUtf8Text -Path $path } else { '' }
  $pattern = '(?ms)' + [regex]::Escape($script:WorkflowCodexConfigStart) + '.*?' + [regex]::Escape($script:WorkflowCodexConfigEnd)
  if ($existing -match $pattern) {
    $updated = [regex]::Replace($existing, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($match) $block }, 1)
  } elseif ($existing.Trim()) {
    $updated = $existing.TrimEnd() + "`n`n" + $block + "`n"
  } else {
    $updated = $block + "`n"
  }
  Write-WorkflowUtf8Text -Path $path -Text $updated
}

function ConvertFrom-WorkflowOpenSpecConfigText {
  param([Parameter(Mandatory)][string]$Text)
  $schema = $null
  $rules = [ordered]@{}
  $currentKey = $null
  $inRules = $false
  foreach ($line in ($Text -split "`r?`n")) {
    $t = $line.TrimEnd()
    $trim = $t.Trim()
    if ($trim -eq '' -or $trim.StartsWith('#')) { continue }
    if ($trim -match '^schema:\s*(.+)$') {
      $schema = $Matches[1].Trim().Trim('"').Trim("'")
      continue
    }
    if ($trim -eq 'rules:' -or $trim -match '^rules:\s*\{\s*\}\s*$') {
      $inRules = $true
      $currentKey = $null
      continue
    }
    if (-not $inRules) { continue }
    if ($trim -match '^([A-Za-z0-9_-]+):\s*$') {
      $currentKey = $Matches[1]
      if (-not $rules.Contains($currentKey)) {
        $rules[$currentKey] = New-Object System.Collections.Generic.List[string]
      }
      continue
    }
    if ($currentKey -and $trim -match '^-\s+(.+)$') {
      $item = $Matches[1].Trim()
      if (($item.StartsWith('"') -and $item.EndsWith('"')) -or ($item.StartsWith("'") -and $item.EndsWith("'"))) {
        $item = $item.Substring(1, $item.Length - 2)
      }
      [void]$rules[$currentKey].Add($item)
    }
  }
  return [pscustomobject]@{ Schema = $schema; Rules = $rules }
}

function Write-WorkflowOpenSpecConfigFile {
  param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Schema,
    [Parameter(Mandatory)]$Rules,
    [switch]$Generated
  )
  $sb = New-Object System.Text.StringBuilder
  if ($Generated) {
    [void]$sb.AppendLine('# AUTO-GENERATED - DO NOT EDIT.')
    [void]$sb.AppendLine('# Edit openspec/config.workflow.yaml / openspec/config.project.yaml; doctor/init auto-sync.')
    [void]$sb.AppendLine('')
  }
  if ($Schema) {
    [void]$sb.AppendLine("schema: $Schema")
    [void]$sb.AppendLine('')
  }
  [void]$sb.AppendLine('rules:')
  $keys = @($Rules.Keys)
  if ($keys.Count -eq 0) {
    [void]$sb.AppendLine('  {}')
  }
  else {
    foreach ($k in $keys) {
      [void]$sb.AppendLine("  ${k}:")
      foreach ($item in @($Rules[$k])) {
        [void]$sb.AppendLine("    - $item")
      }
    }
  }
  Write-WorkflowUtf8Text -Path $Path -Text (($sb.ToString().TrimEnd()) + "`n")
}

function Merge-WorkflowOpenSpecConfig {
  param(
    [Parameter(Mandatory)][string]$WorkflowPath,
    [string]$ProjectPath,
    [Parameter(Mandatory)][string]$OutPath
  )
  if (-not (Test-Path -LiteralPath $WorkflowPath)) {
    throw "Workflow config missing: $WorkflowPath"
  }
  $wf = ConvertFrom-WorkflowOpenSpecConfigText -Text (Read-WorkflowUtf8Text -Path $WorkflowPath)
  $proj = $null
  if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $proj = ConvertFrom-WorkflowOpenSpecConfigText -Text (Read-WorkflowUtf8Text -Path $ProjectPath)
  }

  $schema = $wf.Schema
  if ($proj -and $proj.Schema) { $schema = $proj.Schema }

  $mergedRules = [ordered]@{}
  $allKeys = New-Object System.Collections.Generic.List[string]
  foreach ($k in @($wf.Rules.Keys)) {
    if (-not $allKeys.Contains($k)) { [void]$allKeys.Add($k) }
  }
  if ($proj) {
    foreach ($k in @($proj.Rules.Keys)) {
      if (-not $allKeys.Contains($k)) { [void]$allKeys.Add($k) }
    }
  }
  foreach ($k in $allKeys) {
    $list = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    if ($wf.Rules.Contains($k)) {
      foreach ($item in @($wf.Rules[$k])) {
        if (-not $seen.ContainsKey($item)) {
          $seen[$item] = $true
          [void]$list.Add($item)
        }
      }
    }
    if ($proj -and $proj.Rules.Contains($k)) {
      foreach ($item in @($proj.Rules[$k])) {
        if (-not $seen.ContainsKey($item)) {
          $seen[$item] = $true
          [void]$list.Add($item)
        }
      }
    }
    $mergedRules[$k] = $list
  }

  Write-WorkflowOpenSpecConfigFile -Path $OutPath -Schema $schema -Rules $mergedRules -Generated
}

function Install-WorkflowOpenSpecConfigs {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TargetRoot
  )
  $cfgDstDir = Join-Path $TargetRoot 'openspec'
  New-Item -ItemType Directory -Force -Path $cfgDstDir | Out-Null

  $wfSrc = Join-Path $SourceRoot 'openspec/config.workflow.yaml'
  if (-not (Test-Path -LiteralPath $wfSrc)) {
    $legacy = Join-Path $SourceRoot 'openspec/config.yaml'
    if (Test-Path -LiteralPath $legacy) { $wfSrc = $legacy }
    else { throw "Missing openspec/config.workflow.yaml in source: $SourceRoot" }
  }
  $wfDst = Join-Path $cfgDstDir 'config.workflow.yaml'
  $wfSrcFull = (Resolve-Path -LiteralPath $wfSrc).Path
  $wfDstFull = [System.IO.Path]::GetFullPath($wfDst)
  if ($wfSrcFull -ne $wfDstFull) {
    Copy-Item -LiteralPath $wfSrc -Destination $wfDst -Force
  }
  $projDst = Join-Path $cfgDstDir 'config.project.yaml'
  $cfgDst = Join-Path $cfgDstDir 'config.yaml'
  if (-not (Test-Path -LiteralPath $projDst) -and (Test-Path -LiteralPath $cfgDst)) {
    Move-Item -LiteralPath $cfgDst -Destination $projDst -Force
  }
  if (-not (Test-Path -LiteralPath $projDst)) {
    $shell = @(
      '# Project-private OpenSpec config. Init never overwrites this file.',
      '# Edit this file; doctor/init auto-sync merges into config.yaml.',
      'rules: {}'
    ) -join "`n"
    Write-WorkflowUtf8Text -Path $projDst -Text ($shell + "`n")
  }

  Merge-WorkflowOpenSpecConfig -WorkflowPath $wfDst -ProjectPath $projDst -OutPath $cfgDst
}

function Sync-WorkflowOpenSpecConfig {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $ProjectRoot = Resolve-WorkflowPath -Path $ProjectRoot
  if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "project root not found: $ProjectRoot"
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $openspec = Join-Path $ProjectRoot 'openspec'
  $wf = Join-Path $openspec 'config.workflow.yaml'
  $proj = Join-Path $openspec 'config.project.yaml'
  $out = Join-Path $openspec 'config.yaml'

  if (-not (Test-Path -LiteralPath $wf)) {
    return [pscustomobject]@{ Status = 'MissingWorkflow'; Changed = $false }
  }
  if (-not (Test-Path -LiteralPath $proj)) {
    $shell = @(
      '# Project-private OpenSpec config. Init never overwrites this file.',
      '# Edit this file; doctor/init auto-sync merges into config.yaml.',
      'rules: {}'
    ) -join "`n"
    Write-WorkflowUtf8Text -Path $proj -Text ($shell + "`n")
  }

  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('wf-cfg-sync-' + [guid]::NewGuid().ToString('N') + '.yaml')
  try {
    Merge-WorkflowOpenSpecConfig -WorkflowPath $wf -ProjectPath $proj -OutPath $tmp
    $newText = Read-WorkflowUtf8Text -Path $tmp
    $changed = $true
    if (Test-Path -LiteralPath $out) {
      $oldText = Read-WorkflowUtf8Text -Path $out
      if (($oldText -replace "`r`n", "`n") -eq ($newText -replace "`r`n", "`n")) {
        $changed = $false
      }
    }
    if ($changed) {
      Write-WorkflowUtf8Text -Path $out -Text $newText
    }
    return [pscustomobject]@{
      Status  = $(if ($changed) { 'Merged' } else { 'Unchanged' })
      Changed = $changed
    }
  } finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
  }
}

function Write-WorkflowMetadata {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  foreach ($relativeRoot in @('.cursor/workflow', '.agents/workflow')) {
    $wf = Join-Path $ProjectRoot $relativeRoot
    New-Item -ItemType Directory -Force -Path $wf | Out-Null
    $versionPath = Join-Path $wf 'version.json'
    $manifestPath = Join-Path $wf 'manifest.json'
    @{
      version = $script:WorkflowVersion
      schema  = 'workflow-spec'
      engine  = 'powershell'
      clients = @('cursor', 'codex')
    } | ConvertTo-Json | Set-Content -Encoding utf8 $versionPath
    @{
      version = $script:WorkflowVersion
      files   = Get-WorkflowManifestFiles
    } | ConvertTo-Json | Set-Content -Encoding utf8 $manifestPath
  }
}

function Install-WorkflowV2 {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TargetRoot
  )
  $SourceRoot = Resolve-WorkflowPath -Path $SourceRoot
  $TargetRoot = Resolve-WorkflowPath -Path $TargetRoot
  if (-not (Test-Path -LiteralPath $SourceRoot)) {
    throw "Source root not found: $SourceRoot"
  }
  if (-not (Test-Path -LiteralPath $TargetRoot)) {
    New-Item -ItemType Directory -Force -Path $TargetRoot | Out-Null
  }
  $SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
  $TargetRoot = (Resolve-Path -LiteralPath $TargetRoot).Path
  $self = ($SourceRoot -eq $TargetRoot)

  Remove-WorkflowNamespaceSkills -SkillsRoot (Join-Path $TargetRoot '.cursor/skills')

  if ($self) {
    # Same tree: purge obsolete dirs only; do not delete live opsx/pack we would reinstall from themselves
    $rules = Join-Path $TargetRoot '.cursor/rules'
    $commands = Join-Path $TargetRoot '.cursor/commands'
    if (Test-Path $rules) {
      Get-ChildItem -Path $rules -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'superpowers*' -or $_.Name -like 'openspec*' } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
      foreach ($n in @('superpowers-bootstrap.mdc', 'superpowers-router.mdc', 'workflow-bootstrap.mdc')) {
        $p = Join-Path $rules $n
        if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
      }
    }
    if (Test-Path $commands) {
      Get-ChildItem -Path $commands -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'openspec*' -or $_.Name -like 'superpowers*' } |
        ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force }
    }
  } else {
    Remove-WorkflowOwnedEntries `
      -RulesRoot (Join-Path $TargetRoot '.cursor/rules') `
      -CommandsRoot (Join-Path $TargetRoot '.cursor/commands')

    Copy-WorkflowTree `
      -Source (Join-Path $SourceRoot '.cursor/workflow/pack') `
      -Destination (Join-Path $TargetRoot '.cursor/workflow/pack')

    $routerSrc = Join-Path $SourceRoot '.cursor/rules/workflow-router.mdc'
    $routerDstDir = Join-Path $TargetRoot '.cursor/rules'
    New-Item -ItemType Directory -Force -Path $routerDstDir | Out-Null
    Copy-Item -LiteralPath $routerSrc -Destination (Join-Path $routerDstDir 'workflow-router.mdc') -Force

    $cmdSrc = Join-Path $SourceRoot '.cursor/commands'
    $cmdDst = Join-Path $TargetRoot '.cursor/commands'
    New-Item -ItemType Directory -Force -Path $cmdDst | Out-Null
    Get-ChildItem -Path $cmdSrc -Filter 'opsx-*.md' | ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $cmdDst $_.Name) -Force
    }

    Copy-WorkflowTree `
      -Source (Join-Path $SourceRoot 'openspec/schemas/workflow-spec') `
      -Destination (Join-Path $TargetRoot 'openspec/schemas/workflow-spec')

    $scriptsDst = Join-Path $TargetRoot 'scripts'
    New-Item -ItemType Directory -Force -Path $scriptsDst | Out-Null
    foreach ($name in @('init.ps1', 'doctor.ps1')) {
      $s = Join-Path $SourceRoot "scripts/$name"
      if (Test-Path $s) {
        Copy-Item -LiteralPath $s -Destination (Join-Path $scriptsDst $name) -Force
      }
    }
    $libSrc = Join-Path $SourceRoot 'scripts/lib/WorkflowDeploy.psm1'
    if (Test-Path $libSrc) {
      $libDst = Join-Path $scriptsDst 'lib'
      New-Item -ItemType Directory -Force -Path $libDst | Out-Null
      Copy-Item -LiteralPath $libSrc -Destination (Join-Path $libDst 'WorkflowDeploy.psm1') -Force
    }
  }

  Install-WorkflowOpenSpecConfigs -SourceRoot $SourceRoot -TargetRoot $TargetRoot
  Install-WorkflowCodexSkill -SourceRoot $SourceRoot -TargetRoot $TargetRoot
  $codexRules = @(Install-WorkflowCodexRules -ProjectRoot $TargetRoot)
  Install-WorkflowAgentsGuidance -ProjectRoot $TargetRoot -RuleEntries $codexRules
  Install-WorkflowCodexMcpConfig -ProjectRoot $TargetRoot
  Write-WorkflowMetadata -ProjectRoot $TargetRoot
}

function Get-WorkflowSpecPairErrors {
  param(
    [Parameter(Mandatory)][string]$ProjectRoot
  )
  $errors = New-Object System.Collections.Generic.List[string]
  $roots = New-Object System.Collections.Generic.List[string]
  $main = Join-Path $ProjectRoot 'openspec/specs'
  if (Test-Path $main) { $roots.Add($main) }

  $changes = Join-Path $ProjectRoot 'openspec/changes'
  if (Test-Path $changes) {
    Get-ChildItem -Path $changes -Directory -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -ne 'archive' } |
      ForEach-Object {
        $capRoot = Join-Path $_.FullName 'specs'
        if (Test-Path $capRoot) { $roots.Add($capRoot) }
      }
  }

  foreach ($root in $roots) {
    Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue | ForEach-Object {
      $spec = Join-Path $_.FullName 'spec.md'
      $design = Join-Path $_.FullName 'design.md'
      $relBase = $_.FullName.Substring($ProjectRoot.Length).TrimStart('\', '/')
      $hasSpec = Test-Path $spec
      $hasDesign = Test-Path $design
      if ($hasSpec -and -not $hasDesign) {
        $errors.Add("spec/design pair incomplete: $relBase/design.md missing")
      }
      elseif ($hasDesign -and -not $hasSpec) {
        $errors.Add("spec/design pair incomplete: $relBase/spec.md missing")
      }
    }
  }
  return $errors.ToArray()
}

function Invoke-WorkflowDoctor {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $ProjectRoot = Resolve-WorkflowPath -Path $ProjectRoot
  if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    return [pscustomobject]@{
      ExitCode = 1
      Errors   = @("project root not found: $ProjectRoot")
    }
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $errors = New-Object System.Collections.Generic.List[string]

  try {
    $null = Sync-WorkflowOpenSpecConfig -ProjectRoot $ProjectRoot
  } catch {
    $errors.Add("config sync failed: $($_.Exception.Message)")
  }

  foreach ($rel in (Get-WorkflowManifestFiles)) {
    # version/manifest written together; still check core files
    if ($rel -in @('.cursor/workflow/version.json', '.cursor/workflow/manifest.json', '.agents/workflow/version.json', '.agents/workflow/manifest.json')) { continue }
    $p = Join-Path $ProjectRoot $rel
    if (-not (Test-Path $p)) {
      $errors.Add("missing: $rel")
    }
  }

  $ver = Join-Path $ProjectRoot '.cursor/workflow/version.json'
  $man = Join-Path $ProjectRoot '.cursor/workflow/manifest.json'
  if (-not (Test-Path $ver)) { $errors.Add('missing: .cursor/workflow/version.json') }
  if (-not (Test-Path $man)) { $errors.Add('missing: .cursor/workflow/manifest.json') }

  if (Test-Path $man) {
    try {
      $m = Get-Content -Raw $man | ConvertFrom-Json
      foreach ($rel in @($m.files)) {
        if (-not (Test-Path (Join-Path $ProjectRoot $rel))) {
          $errors.Add("manifest file missing: $rel")
        }
      }
    } catch {
      $errors.Add("invalid manifest.json: $($_.Exception.Message)")
    }
  }

  foreach ($rel in @('.agents/workflow/version.json', '.agents/workflow/manifest.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $rel))) { $errors.Add("missing: $rel") }
  }
  $agentsPath = Join-Path $ProjectRoot 'AGENTS.md'
  if (Test-Path -LiteralPath $agentsPath) {
    $agentsRaw = Get-Content -Raw -Encoding utf8 -LiteralPath $agentsPath
    if ($agentsRaw -notmatch [regex]::Escape($script:WorkflowAgentsStart)) {
      $errors.Add('AGENTS.md missing workflow managed block')
    }
  }
  $cursorMcp = Join-Path $ProjectRoot '.cursor/mcp.json'
  if (Test-Path -LiteralPath $cursorMcp) {
    $codexConfig = Join-Path $ProjectRoot '.codex/config.toml'
    if (-not (Test-Path -LiteralPath $codexConfig)) {
      $errors.Add('missing: .codex/config.toml')
    } elseif ((Get-Content -Raw -Encoding utf8 -LiteralPath $codexConfig) -notmatch [regex]::Escape($script:WorkflowCodexConfigStart)) {
      $errors.Add('.codex/config.toml missing workflow managed MCP block')
    }
  }

  $legacy = Get-WorkflowNamespaceSkillDirs -SkillsRoot (Join-Path $ProjectRoot '.cursor/skills')
  foreach ($d in $legacy) {
    $errors.Add("legacy workflow skill must be purged: .cursor/skills/$($d.Name)")
  }

  # obsolete bootstrap alwaysApply residue
  $boot = Join-Path $ProjectRoot '.cursor/rules/superpowers-bootstrap.mdc'
  if (Test-Path $boot) {
    $errors.Add('legacy bootstrap present: .cursor/rules/superpowers-bootstrap.mdc')
  }
  $bootDir = Join-Path $ProjectRoot '.cursor/rules/superpowers-v6.1.1'
  if (Test-Path $bootDir) {
    $errors.Add('legacy rules dir present: .cursor/rules/superpowers-v6.1.1')
  }

  foreach ($e in (Get-WorkflowSpecPairErrors -ProjectRoot $ProjectRoot)) {
    $errors.Add($e)
  }

  $mergedCfg = Join-Path $ProjectRoot 'openspec/config.yaml'
  if (Test-Path -LiteralPath $mergedCfg) {
    $cfgRaw = Get-Content -Raw -LiteralPath $mergedCfg
    if ($cfgRaw -notmatch '(?m)^schema:\s*\S') {
      $errors.Add('openspec/config.yaml missing schema: (expected merged OpenSpec config)')
    }
  }

  # schema resolution: prefer openspec CLI when available
  $schemaYaml = Join-Path $ProjectRoot 'openspec/schemas/workflow-spec/schema.yaml'
  if (-not (Test-Path $schemaYaml)) {
    $errors.Add('missing: openspec/schemas/workflow-spec/schema.yaml')
  } else {
    $openspecCmd = $null
    $cmd = Get-Command openspec -ErrorAction SilentlyContinue
    if ($cmd) { $openspecCmd = $cmd.Source }
    if (-not $openspecCmd) {
      $nvmCandidate = Join-Path $env:LOCALAPPDATA 'nvm\v16.20.2\openspec.cmd'
      if (Test-Path $nvmCandidate) { $openspecCmd = $nvmCandidate }
    }
    if ($openspecCmd) {
      $prevEap = $ErrorActionPreference
      $ErrorActionPreference = 'Continue'
      try {
        Push-Location $ProjectRoot
        try {
          $lines = @()
          & $openspecCmd schema which workflow-spec 2>&1 | ForEach-Object { $lines += "$_" }
          $whichOut = ($lines -join "`n")
        } finally {
          Pop-Location
        }
        if ($whichOut -notmatch 'openspec[/\\]schemas[/\\]workflow-spec') {
          $errors.Add("schema which did not resolve to project openspec/schemas/workflow-spec; output=$($whichOut.Trim())")
        }
        elseif ($whichOut -match 'Source:\s*package' -and $whichOut -notmatch 'Source:\s*project') {
          $errors.Add('schema which resolved from package, expected project-local workflow-spec')
        }
      } finally {
        $ErrorActionPreference = $prevEap
      }
    } else {
      $errors.Add('openspec CLI not found; cannot verify schema resolution (install openspec or add to PATH)')
    }
  }

  $exit = if ($errors.Count -gt 0) { 1 } else { 0 }
  [pscustomobject]@{
    ExitCode = $exit
    Errors   = $errors.ToArray()
  }
}

function Write-WorkflowState {
  param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$ActiveChange = '',
    [string]$Phase = '',
    [string]$Branch = ''
  )
  $wf = Join-Path $ProjectRoot '.agents/workflow'
  New-Item -ItemType Directory -Force -Path $wf | Out-Null
  $path = Join-Path $wf 'state.json'
  $existing = @{}
  if (Test-Path $path) {
    try { $existing = Get-Content -Raw $path | ConvertFrom-Json } catch { $existing = @{} }
  }
  $obj = [ordered]@{
    active_change = if ($ActiveChange) { $ActiveChange } elseif ($existing.active_change) { $existing.active_change } else { $null }
    phase         = if ($Phase) { $Phase } elseif ($existing.phase) { $existing.phase } else { $null }
    branch        = if ($Branch) { $Branch } elseif ($existing.branch) { $existing.branch } else { $null }
    updated_at    = (Get-Date).ToUniversalTime().ToString('o')
  }
  $json = ($obj | ConvertTo-Json)
  $json | Set-Content -Encoding utf8 $path
  $cursorWf = Join-Path $ProjectRoot '.cursor/workflow'
  New-Item -ItemType Directory -Force -Path $cursorWf | Out-Null
  $json | Set-Content -Encoding utf8 (Join-Path $cursorWf 'state.json')
  return $path
}

Export-ModuleMember -Function @(
  'Resolve-WorkflowPath',
  'Get-WorkflowNamespaceSkillDirs',
  'Remove-WorkflowNamespaceSkills',
  'Remove-WorkflowOwnedEntries',
  'Copy-WorkflowTree',
  'Get-WorkflowManifestFiles',
  'Install-WorkflowCodexSkill',
  'Install-WorkflowCodexRules',
  'Install-WorkflowAgentsGuidance',
  'Install-WorkflowCodexMcpConfig',
  'Write-WorkflowMetadata',
  'Merge-WorkflowOpenSpecConfig',
  'Install-WorkflowOpenSpecConfigs',
  'Sync-WorkflowOpenSpecConfig',
  'Install-WorkflowV2',
  'Invoke-WorkflowDoctor',
  'Get-WorkflowSpecPairErrors',
  'Write-WorkflowState'
)
