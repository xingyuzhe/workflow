# WorkflowDeploy.psm1 — platform-neutral workflow deployment

$script:WorkflowVersion = '4.0.1'
$script:WorkflowAgentsStart = '<!-- BEGIN WORKFLOW MANAGED -->'
$script:WorkflowAgentsEnd = '<!-- END WORKFLOW MANAGED -->'
$script:WorkflowCodexConfigStart = '# BEGIN WORKFLOW MANAGED MCP'
$script:WorkflowCodexConfigEnd = '# END WORKFLOW MANAGED MCP'

function Resolve-WorkflowClients {
  param([string[]]$Clients = @('cursor', 'codex'))
  $resolved = New-Object System.Collections.Generic.List[string]
  foreach ($client in @($Clients)) {
    $name = "$client".Trim().ToLowerInvariant()
    if ($name -notin @('cursor', 'codex')) { throw "unsupported workflow client: $client" }
    if (-not $resolved.Contains($name)) { $resolved.Add($name) }
  }
  if ($resolved.Count -eq 0) { throw 'at least one workflow client is required' }
  return $resolved.ToArray()
}

function Get-WorkflowInstalledClients {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $versionPath = Join-Path $ProjectRoot '.workflow/version.json'
  if (Test-Path -LiteralPath $versionPath -PathType Leaf) {
    try {
      $metadata = Read-WorkflowJsonFile $versionPath
      if ($metadata.clients) { return @(Resolve-WorkflowClients @($metadata.clients)) }
    } catch { }
  }
  return @('cursor', 'codex')
}

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
    $srcDir = Join-Path $SourceRoot ".workflow/pack/$kind"
    $dstDir = Join-Path $refs $kind
    New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
    Get-ChildItem -LiteralPath $srcDir -File -Filter '*.md' | ForEach-Object {
      Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $dstDir $_.Name) -Force
    }
  }
}

function Get-WorkflowAgentsBlock {
  param([object[]]$RuleEntries = @())
  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add($script:WorkflowAgentsStart)
  [void]$lines.Add('## OpenSpec workflow')
  [void]$lines.Add('')
  [void]$lines.Add('Use `$openspec-workflow` for explicit OpenSpec lifecycle work. Treat `/opsx:name`, `/opsx-name`, `$openspec-workflow name`, and equivalent lifecycle intent as aliases.')
  [void]$lines.Add('')
  [void]$lines.Add('Route operations as follows: `explore`, `new`, `ff`, `continue`, `grill`, `apply`, `verify`, `sync`, `archive`, and `doctor`. Failures remain in this workflow only when they occur within an active lifecycle operation.')
  [void]$lines.Add('')
  [void]$lines.Add('- Treat `openspec/config.yaml` as generated from `openspec/config.workflow.yaml` and `openspec/config.project.yaml`; do not hand-edit it.')
  [void]$lines.Add('- Reconcile `.workflow/state.json` with `openspec status`; CLI output wins and missing local state never blocks work.')
  [void]$lines.Add('- Preserve unrelated user changes. Do not merge, push, open a PR, discard a branch, or archive without the authorization required by the workflow.')
  if (@($RuleEntries).Count -gt 0) {
    [void]$lines.Add('')
    [void]$lines.Add('### Project rules')
    [void]$lines.Add('')
    foreach ($entry in $RuleEntries) {
      $desc = if ($entry.Description) { ' - ' + $entry.Description } else { '' }
      if ($entry.Always) {
        [void]$lines.Add('- Read `.agents/rules/' + $entry.Name + '` before any work (always apply)' + $desc + '.')
      } elseif (@($entry.Paths).Count -gt 0) {
        [void]$lines.Add('- Read `.agents/rules/' + $entry.Name + '` before changing files matching `' + (@($entry.Paths) -join '`, `') + '`' + $desc + '.')
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
    [void]$sb.AppendLine('# Edit openspec/config.workflow.yaml / openspec/config.project.yaml; init, explicit sync, or doctor -Fix regenerates this file.')
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
      '# Edit this file; init, explicit sync, or doctor -Fix merges into config.yaml.',
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
      '# Edit this file; init, explicit sync, or doctor -Fix merges into config.yaml.',
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

function Assert-WorkflowJsonProperties {
  param($Object, [string[]]$Allowed, [string]$Context)
  foreach ($property in $Object.PSObject.Properties.Name) {
    if ($property -notin $Allowed) { throw "$Context contains unsupported field '$property'" }
  }
}

function Read-WorkflowJsonFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "missing canonical source: $Path" }
  try { return (Read-WorkflowUtf8Text -Path $Path | ConvertFrom-Json) }
  catch { throw "invalid JSON in $Path`: $($_.Exception.Message)" }
}

function Get-WorkflowRuleEntries {
  param([string]$ProjectRoot)
  $catalog = Read-WorkflowJsonFile (Join-Path $ProjectRoot '.workflow/rules.json')
  Assert-WorkflowJsonProperties $catalog @('schemaVersion','rules') '.workflow/rules.json'
  if ($catalog.schemaVersion -ne 1) { throw '.workflow/rules.json schemaVersion must be 1' }
  $entries = New-Object System.Collections.Generic.List[object]
  $seen = @{}
  foreach ($rule in @($catalog.rules)) {
    Assert-WorkflowJsonProperties $rule @('path','description','always','paths') '.workflow/rules.json rule'
    $rel = "$($rule.path)" -replace '\\', '/'
    if (-not $rel -or $rel -notmatch '^[A-Za-z0-9._/-]+\.md$' -or $rel.StartsWith('/') -or $rel -match '(^|/)\.\.(/|$)') { throw ".workflow/rules.json invalid rule path '$rel'" }
    if ($seen.ContainsKey($rel.ToLowerInvariant())) { throw ".workflow/rules.json duplicate rule path '$rel'" }
    $seen[$rel.ToLowerInvariant()] = $true
    if ($rule.always -isnot [bool]) { throw ".workflow/rules.json rule '$rel' always must be boolean" }
    $paths = @()
    foreach ($item in @($rule.paths)) {
      if ($item -isnot [string] -or -not $item.Trim()) { throw ".workflow/rules.json rule '$rel' paths must contain strings" }
      $paths += $item
    }
    if ($rule.always -and $paths.Count) { throw ".workflow/rules.json rule '$rel' cannot set always and paths together" }
    $bodyPath = Join-Path $ProjectRoot ('.workflow/rules/' + $rel)
    if (-not (Test-Path -LiteralPath $bodyPath -PathType Leaf)) { throw "missing canonical rule body: .workflow/rules/$rel" }
    [void]$entries.Add([pscustomobject]@{ Name=$rel; Description="$($rule.description)"; Always=[bool]$rule.always; Paths=$paths; Body=(Read-WorkflowUtf8Text $bodyPath) })
  }
  return $entries.ToArray()
}

function Get-WorkflowMcpServers {
  param([string]$ProjectRoot)
  $root = Read-WorkflowJsonFile (Join-Path $ProjectRoot '.workflow/mcp.json')
  Assert-WorkflowJsonProperties $root @('schemaVersion','servers') '.workflow/mcp.json'
  if ($root.schemaVersion -ne 1) { throw '.workflow/mcp.json schemaVersion must be 1' }
  $allowed = @('transport','command','args','env','cwd','url','bearerTokenEnvVar','httpHeaders','envHttpHeaders','startupTimeoutSec','toolTimeoutSec','enabled','required','enabledTools','disabledTools')
  foreach ($property in $root.servers.PSObject.Properties) {
    $server = $property.Value
    Assert-WorkflowJsonProperties $server $allowed ".workflow/mcp.json server '$($property.Name)'"
    if ($server.transport -notin @('stdio','http')) { throw ".workflow/mcp.json server '$($property.Name)' transport must be stdio or http" }
    if ($server.transport -eq 'stdio' -and (-not $server.command -or $server.url)) { throw ".workflow/mcp.json server '$($property.Name)' invalid stdio definition" }
    if ($server.transport -eq 'http' -and (-not $server.url -or $server.command)) { throw ".workflow/mcp.json server '$($property.Name)' invalid http definition" }
    foreach($name in @('command','cwd','url','bearerTokenEnvVar')){if($null -ne $server.$name -and $server.$name -isnot [string]){throw ".workflow/mcp.json server '$($property.Name)' $name must be a string"}}
    foreach($name in @('enabled','required')){if($null -ne $server.$name -and $server.$name -isnot [bool]){throw ".workflow/mcp.json server '$($property.Name)' $name must be boolean"}}
    foreach($name in @('startupTimeoutSec','toolTimeoutSec')){if($null -ne $server.$name -and (($server.$name -isnot [ValueType]) -or [double]$server.$name -le 0)){throw ".workflow/mcp.json server '$($property.Name)' $name must be a positive number"}}
    foreach($name in @('args','enabledTools','disabledTools')){if($null -ne $server.$name){if($server.$name -is [string] -or $server.$name -isnot [array]){throw ".workflow/mcp.json server '$($property.Name)' $name must be an array"};foreach($item in @($server.$name)){if($item -isnot [string]){throw ".workflow/mcp.json server '$($property.Name)' $name must contain strings"}}}}
    foreach($name in @('env','httpHeaders','envHttpHeaders')){if($null -ne $server.$name){if($server.$name -is [string] -or $server.$name -is [array]){throw ".workflow/mcp.json server '$($property.Name)' $name must be an object"};foreach($item in $server.$name.PSObject.Properties){if($item.Value -isnot [string]){throw ".workflow/mcp.json server '$($property.Name)' $name values must be strings"}}}}
  }
  return $root.servers
}

function ConvertTo-WorkflowCursorMcpJson {
  param($Servers)
  $out = [ordered]@{ mcpServers=[ordered]@{} }
  foreach ($property in $Servers.PSObject.Properties) {
    $s=$property.Value; $native=[ordered]@{}
    if ($s.transport -eq 'stdio') { $native.command="$($s.command)"; if ($null -ne $s.args) {$native.args=@($s.args)}; if ($null -ne $s.env) {$native.env=$s.env}; if ($s.cwd) {$native.cwd="$($s.cwd)"} }
    else { $native.url="$($s.url)"; if ($null -ne $s.httpHeaders) {$native.headers=$s.httpHeaders} }
    $out.mcpServers[$property.Name]=$native
  }
  return (($out | ConvertTo-Json -Depth 20) + "`n")
}

function ConvertTo-WorkflowTomlKey { param([string]$Value) ConvertTo-WorkflowTomlString $Value }

function ConvertTo-WorkflowCodexMcpBlock {
  param($Servers)
  $lines=New-Object System.Collections.Generic.List[string]
  [void]$lines.Add($script:WorkflowCodexConfigStart); [void]$lines.Add('# Generated from .workflow/mcp.json. Edit the neutral source or project-owned TOML outside this block.')
  foreach ($property in $Servers.PSObject.Properties) {
    $name=ConvertTo-WorkflowTomlKey $property.Name; $s=$property.Value
    [void]$lines.Add(''); [void]$lines.Add("[mcp_servers.$name]")
    if ($s.transport -eq 'stdio') { [void]$lines.Add('command = '+(ConvertTo-WorkflowTomlString "$($s.command)")); if ($null -ne $s.args) {[void]$lines.Add('args = ['+((@($s.args)|%{ConvertTo-WorkflowTomlString "$_"}) -join ', ')+']')}; if ($s.cwd) {[void]$lines.Add('cwd = '+(ConvertTo-WorkflowTomlString "$($s.cwd)"))} }
    else { [void]$lines.Add('url = '+(ConvertTo-WorkflowTomlString "$($s.url)")); if ($s.bearerTokenEnvVar) {[void]$lines.Add('bearer_token_env_var = '+(ConvertTo-WorkflowTomlString "$($s.bearerTokenEnvVar)"))} }
    $map=[ordered]@{startupTimeoutSec='startup_timeout_sec';toolTimeoutSec='tool_timeout_sec';enabled='enabled';required='required'}
    foreach($k in $map.Keys){if($null -ne $s.$k){$v=$s.$k;if($v -is [bool]){$v="$v".ToLowerInvariant()};[void]$lines.Add("$($map[$k]) = $v")}}
    foreach($pair in @(@('enabledTools','enabled_tools'),@('disabledTools','disabled_tools'))){$v=$s.($pair[0]);if($null -ne $v){[void]$lines.Add("$($pair[1]) = ["+((@($v)|%{ConvertTo-WorkflowTomlString "$_"}) -join ', ')+']')}}
    foreach($section in @(@('env','env'),@('httpHeaders','http_headers'),@('envHttpHeaders','env_http_headers'))){$o=$s.($section[0]);if($null -ne $o){[void]$lines.Add('');[void]$lines.Add("[mcp_servers.$name.$($section[1])]");foreach($item in $o.PSObject.Properties){[void]$lines.Add((ConvertTo-WorkflowTomlKey $item.Name)+' = '+(ConvertTo-WorkflowTomlString "$($item.Value)"))}}}
  }
  [void]$lines.Add($script:WorkflowCodexConfigEnd); return ($lines -join "`n")
}

function Get-WorkflowCursorRuleText { param($Rule) (@('---',"description: $($Rule.Description)",'globs: '+(@($Rule.Paths)-join ','),"alwaysApply: $(if($Rule.Always){'true'}else{'false'})",'---','',$Rule.Body.TrimEnd()) -join "`n")+"`n" }
function Get-WorkflowRouterText { @'
---
description: Route OpenSpec lifecycle requests to the shared workflow pack
globs:
alwaysApply: true
---

# Workflow router

For explicit OpenSpec lifecycle intent, load the matching contract from `.workflow/pack/prompts/` and any contract it references.
'@ }
function Get-WorkflowCommandText { param([string]$Operation) "---`nname: /opsx-$Operation`nid: opsx-$Operation`ncategory: OpenSpec`ndescription: Run OpenSpec $Operation workflow`n---`n`nLoad and follow: ``.workflow/pack/prompts/$Operation.md```n" }

function Remove-WorkflowIndexedFiles {
  param([string]$Root, [string]$IndexPath)
  if (-not (Test-Path -LiteralPath $IndexPath -PathType Leaf)) { return }
  try { $index=Read-WorkflowJsonFile $IndexPath } catch { return }
  foreach($rel in @($index.files)) {
    $safe="$rel" -replace '\\','/'
    if ($safe -match '(^|/)\.\.(/|$)' -or $safe.StartsWith('/')) { throw "unsafe managed path '$safe' in $IndexPath" }
    $path=Join-Path $Root $safe
    if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force }
  }
}

function Set-WorkflowManagedBlock {
  param([string]$Path,[string]$Start,[string]$End,[string]$Block,[string]$Prefix='')
  $existing=if(Test-Path -LiteralPath $Path){Read-WorkflowUtf8Text $Path}else{$Prefix}
  $pattern='(?ms)'+[regex]::Escape($Start)+'.*?'+[regex]::Escape($End)
  if($existing -match $pattern){$updated=[regex]::Replace($existing,$pattern,[System.Text.RegularExpressions.MatchEvaluator]{param($m)$Block},1)}
  elseif($existing.Trim()){$updated=$existing.TrimEnd()+"`n`n"+$Block+"`n"}else{$updated=$Block+"`n"}
  Write-WorkflowUtf8Text $Path $updated
}

function Install-WorkflowGeneratedAdapters {
  param([string]$ProjectRoot,[string[]]$Clients=@('cursor','codex'))
  $Clients=@(Resolve-WorkflowClients $Clients)
  $rules=@(Get-WorkflowRuleEntries $ProjectRoot); $servers=Get-WorkflowMcpServers $ProjectRoot
  if($Clients -contains 'cursor'){
    $cursorRoot=Join-Path $ProjectRoot '.cursor/rules'; New-Item -ItemType Directory -Force -Path $cursorRoot | Out-Null
    Remove-WorkflowIndexedFiles $cursorRoot (Join-Path $cursorRoot '.workflow-managed.json')
    Write-WorkflowUtf8Text (Join-Path $cursorRoot 'workflow-router.mdc') ((Get-WorkflowRouterText).TrimEnd()+"`n")
    $cursorFiles=@('workflow-router.mdc')
    foreach($rule in $rules){$cursorRel=[IO.Path]::ChangeExtension($rule.Name,'.mdc');Write-WorkflowUtf8Text (Join-Path $cursorRoot $cursorRel) (Get-WorkflowCursorRuleText $rule);$cursorFiles+=$cursorRel}
    Write-WorkflowUtf8Text (Join-Path $cursorRoot '.workflow-managed.json') ((@{files=$cursorFiles}|ConvertTo-Json)+"`n")
    $commands=Join-Path $ProjectRoot '.cursor/commands'; New-Item -ItemType Directory -Force -Path $commands | Out-Null
    foreach($op in @('explore','new','ff','continue','grill','apply','verify','sync','archive','doctor')){Write-WorkflowUtf8Text (Join-Path $commands "opsx-$op.md") (Get-WorkflowCommandText $op)}
    Write-WorkflowUtf8Text (Join-Path $ProjectRoot '.cursor/mcp.json') (ConvertTo-WorkflowCursorMcpJson $servers)
  }
  if($Clients -contains 'codex'){
    $agentRoot=Join-Path $ProjectRoot '.agents/rules'; New-Item -ItemType Directory -Force -Path $agentRoot | Out-Null
    Remove-WorkflowIndexedFiles $agentRoot (Join-Path $agentRoot '.workflow-managed.json')
    $agentFiles=@();foreach($rule in $rules){Write-WorkflowUtf8Text (Join-Path $agentRoot $rule.Name) ($rule.Body.TrimEnd()+"`n");$agentFiles+=$rule.Name}
    Write-WorkflowUtf8Text (Join-Path $agentRoot '.workflow-managed.json') ((@{files=$agentFiles}|ConvertTo-Json)+"`n")
    $skill=Join-Path $ProjectRoot '.agents/skills/openspec-workflow'; $refs=Join-Path $skill 'references'
    if(Test-Path -LiteralPath $refs){Remove-Item -LiteralPath $refs -Recurse -Force}; Copy-WorkflowTree (Join-Path $ProjectRoot '.workflow/pack') $refs
    Install-WorkflowAgentsGuidance $ProjectRoot $rules
    $block=ConvertTo-WorkflowCodexMcpBlock $servers
    Set-WorkflowManagedBlock (Join-Path $ProjectRoot '.codex/config.toml') $script:WorkflowCodexConfigStart $script:WorkflowCodexConfigEnd $block
  }
}

function Write-WorkflowMetadata {
  param([Parameter(Mandatory)][string]$ProjectRoot,[string[]]$Clients=@('cursor','codex'))
  $Clients=@(Resolve-WorkflowClients $Clients)
  $wf=Join-Path $ProjectRoot '.workflow'; New-Item -ItemType Directory -Force -Path $wf | Out-Null
  Write-WorkflowUtf8Text (Join-Path $wf 'version.json') (([ordered]@{version=$script:WorkflowVersion;schema='workflow-spec';engine='powershell';clients=$Clients}|ConvertTo-Json)+"`n")
  $files=@('.workflow/pack','.workflow/mcp.json','.workflow/rules.json')
  if($Clients -contains 'cursor'){$files+=@('.cursor/mcp.json','.cursor/rules/workflow-router.mdc','.cursor/commands')}
  if($Clients -contains 'codex'){$files+=@('.codex/config.toml','AGENTS.md','.agents/skills/openspec-workflow/SKILL.md','.agents/skills/openspec-workflow/artifact.json','.agents/skills/openspec-workflow/artifact-manifest.json')}
  Write-WorkflowUtf8Text (Join-Path $wf 'manifest.json') (([ordered]@{version=$script:WorkflowVersion;files=$files}|ConvertTo-Json -Depth 5)+"`n")
}

function Install-WorkflowV2 {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TargetRoot,
    [string[]]$Clients=@('cursor','codex')
  )
  $Clients=@(Resolve-WorkflowClients $Clients)
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

  if($Clients -contains 'cursor'){Remove-WorkflowNamespaceSkills -SkillsRoot (Join-Path $TargetRoot '.cursor/skills')}
  if (-not $self) {
    Copy-WorkflowTree -Source (Join-Path $SourceRoot '.workflow/pack') -Destination (Join-Path $TargetRoot '.workflow/pack')
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

  foreach($name in @('mcp.json','rules.json')) {
    $dst=Join-Path $TargetRoot ".workflow/$name"
    if(-not(Test-Path -LiteralPath $dst)){Copy-Item -LiteralPath (Join-Path $SourceRoot ".workflow/$name") -Destination $dst -Force}
  }
  Install-WorkflowOpenSpecConfigs -SourceRoot $SourceRoot -TargetRoot $TargetRoot
  if($Clients -contains 'codex'){Install-WorkflowCodexSkill -SourceRoot $SourceRoot -TargetRoot $TargetRoot}
  Install-WorkflowGeneratedAdapters -ProjectRoot $TargetRoot -Clients $Clients
  $null=Sync-WorkflowOpenSpecConfig -ProjectRoot $TargetRoot
  Write-WorkflowMetadata -ProjectRoot $TargetRoot -Clients $Clients
  if($Clients -contains 'cursor'){
    foreach($legacy in @('.cursor/workflow/version.json','.cursor/workflow/manifest.json')){$p=Join-Path $TargetRoot $legacy;if(Test-Path -LiteralPath $p -PathType Leaf){Remove-Item -LiteralPath $p -Force}}
    $legacyPack=Join-Path $TargetRoot '.cursor/workflow/pack';if(Test-Path -LiteralPath $legacyPack -PathType Container){Remove-Item -LiteralPath $legacyPack -Recurse -Force}
    $legacyState=Join-Path $TargetRoot '.cursor/workflow/state.json';if(Test-Path -LiteralPath $legacyState -PathType Leaf){Remove-Item -LiteralPath $legacyState -Force}
  }
  if($Clients -contains 'codex'){
    foreach($legacy in @('.agents/workflow/version.json','.agents/workflow/manifest.json','.agents/workflow/state.json')){$p=Join-Path $TargetRoot $legacy;if(Test-Path -LiteralPath $p -PathType Leaf){Remove-Item -LiteralPath $p -Force}}
  }
}

function Repair-WorkflowInstall { param([string]$ProjectRoot,[string[]]$Clients=@()) if(@($Clients).Count -eq 0){$Clients=Get-WorkflowInstalledClients $ProjectRoot};Install-WorkflowV2 -SourceRoot $ProjectRoot -TargetRoot $ProjectRoot -Clients $Clients }

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
  param([Parameter(Mandatory)][string]$ProjectRoot,[string[]]$Clients=@())
  $ProjectRoot = Resolve-WorkflowPath -Path $ProjectRoot
  if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    return [pscustomobject]@{
      ExitCode = 1
      Errors   = @("project root not found: $ProjectRoot")
    }
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  if(@($Clients).Count -eq 0){$Clients=Get-WorkflowInstalledClients $ProjectRoot}else{$Clients=@(Resolve-WorkflowClients $Clients)}
  $errors = New-Object System.Collections.Generic.List[string]

  $normalize={param($t) (($t -replace "`r`n","`n").TrimEnd()+"`n")}
  $compare={param($rel,$expected)
    $p=Join-Path $ProjectRoot $rel
    if(-not(Test-Path -LiteralPath $p -PathType Leaf)){$errors.Add("missing: $rel");return}
    if((&$normalize (Read-WorkflowUtf8Text $p)) -ne (&$normalize $expected)){$errors.Add("generated content drift: $rel")}
  }
  try {
    $rules=@(Get-WorkflowRuleEntries $ProjectRoot);$servers=Get-WorkflowMcpServers $ProjectRoot
    if($Clients -contains 'cursor'){
      &$compare '.cursor/rules/workflow-router.mdc' (Get-WorkflowRouterText)
      foreach($rule in $rules){&$compare ('.cursor/rules/'+[IO.Path]::ChangeExtension($rule.Name,'.mdc')) (Get-WorkflowCursorRuleText $rule)}
      $cursorIndex=(@{files=@('workflow-router.mdc')+@($rules|%{[IO.Path]::ChangeExtension($_.Name,'.mdc')})}|ConvertTo-Json)+"`n";&$compare '.cursor/rules/.workflow-managed.json' $cursorIndex
      foreach($op in @('explore','new','ff','continue','grill','apply','verify','sync','archive','doctor')){&$compare ".cursor/commands/opsx-$op.md" (Get-WorkflowCommandText $op)}
      &$compare '.cursor/mcp.json' (ConvertTo-WorkflowCursorMcpJson $servers)
    }
    if($Clients -contains 'codex'){
      foreach($rule in $rules){&$compare ('.agents/rules/'+$rule.Name) $rule.Body}
      $agentIndex=(@{files=@($rules|%{$_.Name})}|ConvertTo-Json)+"`n";&$compare '.agents/rules/.workflow-managed.json' $agentIndex
      $codex=Join-Path $ProjectRoot '.codex/config.toml';$expectedBlock=ConvertTo-WorkflowCodexMcpBlock $servers
      if(-not(Test-Path -LiteralPath $codex)){$errors.Add('missing: .codex/config.toml')}else{$raw=Read-WorkflowUtf8Text $codex;$pattern='(?ms)'+[regex]::Escape($script:WorkflowCodexConfigStart)+'.*?'+[regex]::Escape($script:WorkflowCodexConfigEnd);if($raw -notmatch $pattern){$errors.Add('.codex/config.toml missing workflow managed MCP block')}elseif((&$normalize $Matches[0])-ne(&$normalize $expectedBlock)){$errors.Add('generated content drift: .codex/config.toml managed MCP block')}}
      $expectedAgents=Get-WorkflowAgentsBlock $rules;$agents=Join-Path $ProjectRoot 'AGENTS.md'
      if(-not(Test-Path -LiteralPath $agents)){$errors.Add('missing: AGENTS.md')}else{$raw=Read-WorkflowUtf8Text $agents;$pattern='(?ms)'+[regex]::Escape($script:WorkflowAgentsStart)+'.*?'+[regex]::Escape($script:WorkflowAgentsEnd);if($raw -notmatch $pattern){$errors.Add('AGENTS.md missing workflow managed block')}elseif((&$normalize $Matches[0])-ne(&$normalize $expectedAgents)){$errors.Add('generated content drift: AGENTS.md managed block')}}
      foreach($kind in @('prompts','gates')){Get-ChildItem -LiteralPath (Join-Path $ProjectRoot ".workflow/pack/$kind") -File | % {&$compare ('.agents/skills/openspec-workflow/references/'+$kind+'/'+$_.Name) (Read-WorkflowUtf8Text $_.FullName)}}
    }
    $gateRoot=Join-Path $ProjectRoot '.workflow/pack/gates'
    if(-not(Test-Path -LiteralPath (Join-Path $gateRoot 'acceptance.md') -PathType Leaf)){$errors.Add('missing contract: .workflow/pack/gates/acceptance.md')}
    foreach($oldGate in @('tdd.md','debug.md','verify.md')){if(Test-Path -LiteralPath (Join-Path $gateRoot $oldGate)){$errors.Add("superseded method gate present: .workflow/pack/gates/$oldGate")}}
  } catch {$errors.Add("canonical source invalid: $($_.Exception.Message)")}
  $required=@('.workflow/version.json','.workflow/manifest.json');if($Clients -contains 'codex'){$required+=@('.agents/skills/openspec-workflow/SKILL.md','.agents/skills/openspec-workflow/agents/openai.yaml')}
  foreach($rel in $required){if(-not(Test-Path -LiteralPath (Join-Path $ProjectRoot $rel) -PathType Leaf)){$errors.Add("missing: $rel")}}
  foreach($rel in @('.workflow/version.json','.workflow/manifest.json')){try{$meta=Read-WorkflowJsonFile (Join-Path $ProjectRoot $rel);if($meta.version -ne $script:WorkflowVersion){$errors.Add("metadata version drift: $rel")}}catch{$errors.Add("invalid metadata: $rel - $($_.Exception.Message)")}}
  if($Clients -contains 'cursor'){
    foreach($legacy in @('.cursor/workflow/version.json','.cursor/workflow/manifest.json','.cursor/workflow/state.json')){if(Test-Path -LiteralPath (Join-Path $ProjectRoot $legacy)){$errors.Add("superseded Cursor artifact present: $legacy")}}
    if(Test-Path -LiteralPath (Join-Path $ProjectRoot '.cursor/workflow/pack')){$errors.Add('superseded pack present: .cursor/workflow/pack')}
  }
  if($Clients -contains 'codex'){foreach($legacy in @('.agents/workflow/version.json','.agents/workflow/manifest.json','.agents/workflow/state.json')){if(Test-Path -LiteralPath (Join-Path $ProjectRoot $legacy)){$errors.Add("superseded Codex artifact present: $legacy")}}}

  $wfCfg=Join-Path $ProjectRoot 'openspec/config.workflow.yaml';$projCfg=Join-Path $ProjectRoot 'openspec/config.project.yaml';$mergedCfg=Join-Path $ProjectRoot 'openspec/config.yaml'
  if((Test-Path $wfCfg) -and (Test-Path $projCfg)){$tmpCfg=Join-Path ([IO.Path]::GetTempPath())('wf-doctor-'+[guid]::NewGuid().ToString('N')+'.yaml');try{Merge-WorkflowOpenSpecConfig $wfCfg $projCfg $tmpCfg;if(-not(Test-Path $mergedCfg) -or (&$normalize(Read-WorkflowUtf8Text $mergedCfg))-ne(&$normalize(Read-WorkflowUtf8Text $tmpCfg))){$errors.Add('generated content drift: openspec/config.yaml')}}finally{if(Test-Path $tmpCfg){Remove-Item -LiteralPath $tmpCfg -Force}}}

  if($Clients -contains 'cursor'){
    $legacy = Get-WorkflowNamespaceSkillDirs -SkillsRoot (Join-Path $ProjectRoot '.cursor/skills')
    foreach ($d in $legacy) {$errors.Add("legacy workflow skill must be purged: .cursor/skills/$($d.Name)")}

  # obsolete bootstrap alwaysApply residue
  $boot = Join-Path $ProjectRoot '.cursor/rules/superpowers-bootstrap.mdc'
  if (Test-Path $boot) {
    $errors.Add('legacy bootstrap present: .cursor/rules/superpowers-bootstrap.mdc')
  }
  $bootDir = Join-Path $ProjectRoot '.cursor/rules/superpowers-v6.1.1'
  if (Test-Path $bootDir) {
    $errors.Add('legacy rules dir present: .cursor/rules/superpowers-v6.1.1')
  }
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
      $nvmRoot = Join-Path $env:LOCALAPPDATA 'nvm'
      if (Test-Path -LiteralPath $nvmRoot) {
        $openspecCmd = Get-ChildItem -LiteralPath $nvmRoot -Directory -ErrorAction SilentlyContinue |
          ForEach-Object { Join-Path $_.FullName 'openspec.cmd' } | Where-Object { Test-Path -LiteralPath $_ } |
          Sort-Object -Descending | Select-Object -First 1
      }
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
    }
  }

  $exit = if ($errors.Count -gt 0) { 1 } else { 0 }
  [pscustomobject]@{
    ExitCode = $exit
    Errors   = $errors.ToArray()
  }
}

function Build-WorkflowCodexArtifact {
  param([Parameter(Mandatory)][string]$SourceRoot)
  $SourceRoot=Resolve-WorkflowPath $SourceRoot
  Install-WorkflowCodexSkill -SourceRoot $SourceRoot -TargetRoot $SourceRoot
  $skill=Join-Path $SourceRoot '.agents/skills/openspec-workflow'
  $files=@(Get-ChildItem -LiteralPath $skill -Recurse -File | Where-Object {$_.Name -notin @('artifact.json','artifact-manifest.json')} | Sort-Object FullName | ForEach-Object {
    $rel=$_.FullName.Substring($skill.Length+1).Replace('\','/')
    [ordered]@{path=$rel;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash}
  })
  Write-WorkflowUtf8Text (Join-Path $skill 'artifact.json') (([ordered]@{schemaVersion=1;name='openspec-workflow';version=$script:WorkflowVersion;source='.workflow/pack'}|ConvertTo-Json)+"`n")
  Write-WorkflowUtf8Text (Join-Path $skill 'artifact-manifest.json') (([ordered]@{schemaVersion=1;version=$script:WorkflowVersion;files=$files}|ConvertTo-Json -Depth 5)+"`n")
  Write-WorkflowMetadata -ProjectRoot $SourceRoot -Clients @('cursor','codex')
  return $skill
}

function Test-WorkflowCodexArtifact {
  param([Parameter(Mandatory)][string]$SkillRoot)
  foreach($name in @('SKILL.md','agents/openai.yaml','artifact.json','artifact-manifest.json')){if(-not(Test-Path -LiteralPath (Join-Path $SkillRoot $name) -PathType Leaf)){throw "artifact missing: $name"}}
  $meta=Read-WorkflowJsonFile (Join-Path $SkillRoot 'artifact.json')
  if($meta.version -ne $script:WorkflowVersion){throw "artifact version drift: expected $script:WorkflowVersion, got $($meta.version)"}
  $manifest=Read-WorkflowJsonFile (Join-Path $SkillRoot 'artifact-manifest.json')
  if($manifest.version -ne $script:WorkflowVersion){throw 'artifact manifest version drift'}
  foreach($entry in @($manifest.files)){
    $rel="$($entry.path)".Replace('\','/')
    if(-not $rel -or $rel.StartsWith('/') -or $rel -match '(^|/)\.\.(/|$)'){throw "unsafe artifact path: $rel"}
    $path=Join-Path $SkillRoot $rel
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "artifact file missing: $rel"}
    $actual=(Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    if($actual -ne "$($entry.sha256)"){throw "artifact content drift: $rel"}
  }
}

function Remove-WorkflowPublishedLegacyScripts {
  param([Parameter(Mandatory)][string]$TargetRoot)
  $candidates=@(
    @{path='scripts/init.ps1';marker='Install-WorkflowV2'},
    @{path='scripts/doctor.ps1';marker='Invoke-WorkflowDoctor'},
    @{path='scripts/lib/WorkflowDeploy.psm1';marker='WorkflowVersion'}
  )
  foreach($candidate in $candidates){
    $path=Join-Path $TargetRoot $candidate.path
    if(Test-Path -LiteralPath $path -PathType Leaf){
      $text=Read-WorkflowUtf8Text $path
      if($text -match [regex]::Escape($candidate.marker)){Remove-Item -LiteralPath $path -Force}
    }
  }
  $lib=Join-Path $TargetRoot 'scripts/lib'
  if((Test-Path -LiteralPath $lib -PathType Container) -and -not(Get-ChildItem -LiteralPath $lib -Force)){Remove-Item -LiteralPath $lib -Force}
}

function Publish-WorkflowCodexArtifact {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TargetRoot
  )
  $SourceRoot=Resolve-WorkflowPath $SourceRoot;$TargetRoot=Resolve-WorkflowPath $TargetRoot
  if(-not(Test-Path -LiteralPath $TargetRoot)){New-Item -ItemType Directory -Force -Path $TargetRoot|Out-Null}
  $sourceSkill=Join-Path $SourceRoot '.agents/skills/openspec-workflow'
  Test-WorkflowCodexArtifact $sourceSkill
  Copy-WorkflowTree $sourceSkill (Join-Path $TargetRoot '.agents/skills/openspec-workflow')

  Copy-WorkflowTree (Join-Path $SourceRoot 'openspec/schemas/workflow-spec') (Join-Path $TargetRoot 'openspec/schemas/workflow-spec')
  Install-WorkflowOpenSpecConfigs -SourceRoot $SourceRoot -TargetRoot $TargetRoot
  $null=Sync-WorkflowOpenSpecConfig -ProjectRoot $TargetRoot
  Install-WorkflowAgentsGuidance -ProjectRoot $TargetRoot -RuleEntries @()
  $servers=Get-WorkflowMcpServers $SourceRoot
  $block=ConvertTo-WorkflowCodexMcpBlock $servers
  Set-WorkflowManagedBlock (Join-Path $TargetRoot '.codex/config.toml') $script:WorkflowCodexConfigStart $script:WorkflowCodexConfigEnd $block

  $agentRules=Join-Path $TargetRoot '.agents/rules';$agentIndex=Join-Path $agentRules '.workflow-managed.json'
  if(Test-Path -LiteralPath $agentIndex -PathType Leaf){Remove-WorkflowIndexedFiles $agentRules $agentIndex;Remove-Item -LiteralPath $agentIndex -Force}
  $neutral=Join-Path $TargetRoot '.workflow'
  if(Test-Path -LiteralPath $neutral -PathType Container){Remove-Item -LiteralPath $neutral -Recurse -Force}
  Remove-WorkflowPublishedLegacyScripts $TargetRoot
}

function Invoke-WorkflowArtifactDoctor {
  param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$SourceRoot=''
  )
  $ProjectRoot=Resolve-WorkflowPath $ProjectRoot
  $errors=New-Object System.Collections.Generic.List[string]
  if(Test-Path -LiteralPath (Join-Path $ProjectRoot '.workflow')){$errors.Add('downstream source layout present: .workflow')}
  if(Test-Path -LiteralPath (Join-Path $ProjectRoot '.agents/rules/.workflow-managed.json')){$errors.Add('superseded generated rule index present: .agents/rules/.workflow-managed.json')}
  $skill=Join-Path $ProjectRoot '.agents/skills/openspec-workflow'
  try{Test-WorkflowCodexArtifact $skill}catch{$errors.Add($_.Exception.Message)}
  foreach($candidate in @(@('scripts/init.ps1','Install-WorkflowV2'),@('scripts/doctor.ps1','Invoke-WorkflowDoctor'),@('scripts/lib/WorkflowDeploy.psm1','WorkflowVersion'))){
    $path=Join-Path $ProjectRoot $candidate[0]
    if((Test-Path -LiteralPath $path -PathType Leaf) -and (Read-WorkflowUtf8Text $path) -match [regex]::Escape($candidate[1])){$errors.Add("deployment engine present downstream: $($candidate[0])")}
  }
  if($SourceRoot){
    $SourceRoot=Resolve-WorkflowPath $SourceRoot;$sourceSkill=Join-Path $SourceRoot '.agents/skills/openspec-workflow'
    try{Test-WorkflowCodexArtifact $sourceSkill}catch{$errors.Add("source artifact invalid: $($_.Exception.Message)")}
    if(Test-Path -LiteralPath $sourceSkill){
      $sourceFiles=@(Get-ChildItem -LiteralPath $sourceSkill -Recurse -File|%{$_.FullName.Substring($sourceSkill.Length+1).Replace('\','/')})
      $targetFiles=@(Get-ChildItem -LiteralPath $skill -Recurse -File -ErrorAction SilentlyContinue|%{$_.FullName.Substring($skill.Length+1).Replace('\','/')})
      foreach($rel in @($sourceFiles+$targetFiles|Sort-Object -Unique)){
        $s=Join-Path $sourceSkill $rel;$t=Join-Path $skill $rel
        if(-not(Test-Path -LiteralPath $s) -or -not(Test-Path -LiteralPath $t)){$errors.Add("published artifact file set drift: $rel")}
        elseif((Get-FileHash -Algorithm SHA256 -LiteralPath $s).Hash -ne (Get-FileHash -Algorithm SHA256 -LiteralPath $t).Hash){$errors.Add("published artifact content drift: $rel")}
      }
    }
  }
  foreach($e in (Get-WorkflowSpecPairErrors $ProjectRoot)){$errors.Add($e)}
  $schema=Join-Path $ProjectRoot 'openspec/schemas/workflow-spec/schema.yaml';if(-not(Test-Path -LiteralPath $schema -PathType Leaf)){$errors.Add('missing: openspec/schemas/workflow-spec/schema.yaml')}
  return [pscustomobject]@{ExitCode=if($errors.Count){1}else{0};Errors=$errors.ToArray()}
}

function Write-WorkflowState {
  param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$ActiveChange = '',
    [string]$Phase = '',
    [string]$Branch = ''
  )
  $wf = Join-Path $ProjectRoot '.workflow'
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
  return $path
}

Export-ModuleMember -Function @(
  'Resolve-WorkflowPath',
  'Resolve-WorkflowClients',
  'Get-WorkflowInstalledClients',
  'Build-WorkflowCodexArtifact',
  'Publish-WorkflowCodexArtifact',
  'Invoke-WorkflowArtifactDoctor',
  'Get-WorkflowNamespaceSkillDirs',
  'Remove-WorkflowNamespaceSkills',
  'Remove-WorkflowOwnedEntries',
  'Copy-WorkflowTree',
  'Install-WorkflowCodexSkill',
  'Install-WorkflowAgentsGuidance',
  'Write-WorkflowMetadata',
  'Merge-WorkflowOpenSpecConfig',
  'Install-WorkflowOpenSpecConfigs',
  'Sync-WorkflowOpenSpecConfig',
  'Install-WorkflowV2',
  'Repair-WorkflowInstall',
  'Invoke-WorkflowDoctor',
  'Get-WorkflowSpecPairErrors',
  'Write-WorkflowState'
)
