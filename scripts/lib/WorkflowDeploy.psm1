# WorkflowDeploy.psm1 — platform-neutral workflow deployment

$script:WorkflowVersion = '6.2.1'
$script:WorkflowAgentsStart = '<!-- BEGIN WORKFLOW MANAGED -->'
$script:WorkflowAgentsEnd = '<!-- END WORKFLOW MANAGED -->'
$script:WorkflowCodexConfigStart = '# BEGIN WORKFLOW MANAGED MCP'
$script:WorkflowCodexConfigEnd = '# END WORKFLOW MANAGED MCP'
$script:WorkflowLegacyOpsxCommands = @(
  'opsx-apply.md',
  'opsx-archive.md',
  'opsx-continue.md',
  'opsx-doctor.md',
  'opsx-explore.md',
  'opsx-ff.md',
  'opsx-grill.md',
  'opsx-new.md',
  'opsx-sync.md',
  'opsx-verify.md'
)
$script:WorkflowLegacyRouterMarkers = @(
  '$openspec-workflow',
  '/opsx:',
  '/opsx-',
  'OpenSpec workflow',
  'openspec status'
)

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
      $_.Name -eq 'workflow'
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
    Get-ChildItem -Path $CommandsRoot -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like 'opsx-*.md' -or $_.Name -like 'workflow-*.md' } |
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

function Get-WorkflowPortableContentHash {
  param([Parameter(Mandatory)][string]$Path)
  $inputBytes = [System.IO.File]::ReadAllBytes($Path)
  $canonical = New-Object System.IO.MemoryStream
  try {
    for ($i = 0; $i -lt $inputBytes.Length; $i++) {
      if ($inputBytes[$i] -eq 13) {
        if (($i + 1) -lt $inputBytes.Length -and $inputBytes[$i + 1] -eq 10) { $i++ }
        $canonical.WriteByte(10)
      } else {
        $canonical.WriteByte($inputBytes[$i])
      }
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
      return ([System.BitConverter]::ToString($sha.ComputeHash($canonical.ToArray()))).Replace('-', '')
    } finally {
      $sha.Dispose()
    }
  } finally {
    $canonical.Dispose()
  }
}

function Install-WorkflowCodexSkill {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TargetRoot
  )
  $srcSkill = Join-Path $SourceRoot '.agents/skills/workflow'
  $dstSkill = Join-Path $TargetRoot '.agents/skills/workflow'
  foreach ($rel in @('SKILL.md', 'agents/openai.yaml')) {
    $src = Join-Path $srcSkill $rel
    if (-not (Test-Path -LiteralPath $src)) { throw "Source missing: $src" }
    $dst = Join-Path $dstSkill $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
    if ((Resolve-Path -LiteralPath $src).Path -ne [IO.Path]::GetFullPath($dst)) {
      Copy-Item -LiteralPath $src -Destination $dst -Force
    }
  }
  if ((Resolve-WorkflowPath $SourceRoot) -ne (Resolve-WorkflowPath $TargetRoot)) {
    foreach ($rel in @('artifact.json', 'artifact-manifest.json')) {
      $src = Join-Path $srcSkill $rel
      if (-not (Test-Path -LiteralPath $src -PathType Leaf)) { throw "Source missing: $src" }
      Copy-Item -LiteralPath $src -Destination (Join-Path $dstSkill $rel) -Force
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
  $bin = Join-Path $dstSkill 'bin'
  $cliSource = Join-Path $SourceRoot '.workflow/cli'
  if (Test-Path -LiteralPath $cliSource -PathType Container) {
    if (Test-Path -LiteralPath $bin) { Remove-Item -LiteralPath $bin -Recurse -Force }
    Copy-WorkflowTree $cliSource $bin
  } elseif (-not (($SourceRoot -eq $TargetRoot) -and (Test-Path -LiteralPath (Join-Path $bin 'workflow.ps1') -PathType Leaf))) {
    throw "Source missing: $cliSource"
  }
}

function ConvertTo-WorkflowCanonicalJson {
  param([Parameter(Mandatory)]$Value,[int]$Depth=20)
  return (($Value | ConvertTo-Json -Depth $Depth -Compress) + "`n")
}

function Get-WorkflowAgentsBlock {
  param([object[]]$RuleEntries = @())
  $effectiveRules=@($RuleEntries|Where-Object{$null -ne $_})
  $lines = New-Object System.Collections.Generic.List[string]
  [void]$lines.Add($script:WorkflowAgentsStart)
  [void]$lines.Add('## Workflow')
  [void]$lines.Add('')
  [void]$lines.Add('Use `$workflow` for explicit workflow lifecycle work. Treat `/workflow:name`, `/workflow-name`, `$workflow name`, and equivalent lifecycle intent as aliases.')
  [void]$lines.Add('')
  [void]$lines.Add('Route operations as follows: `explore`, `new`, `ff`, `continue`, `grill`, `apply`, `verify`, `sync`, `archive`, and `doctor`. Failures remain in this workflow only when they occur within an active lifecycle operation.')
  [void]$lines.Add('')
  [void]$lines.Add('- Treat `.workflow/config.json` as generated from `.workflow/config.workflow.json` and `.workflow/config.project.json`; do not hand-edit it.')
  [void]$lines.Add('- Use `.agents/skills/workflow/bin/workflow.ps1` for lifecycle state and validation. Repository files are authoritative.')
  [void]$lines.Add('- Never install, download, discover, or invoke an external lifecycle CLI or package. A missing local CLI is an invalid workflow installation.')
  [void]$lines.Add('- Preserve unrelated user changes. Do not merge, push, open a PR, discard a branch, or archive without the authorization required by the workflow.')
  if ($effectiveRules.Count -gt 0) {
    [void]$lines.Add('')
    [void]$lines.Add('### Project rules')
    [void]$lines.Add('')
    foreach ($entry in $effectiveRules) {
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

function ConvertFrom-WorkflowConfigText {
  param([Parameter(Mandatory)][string]$Text)
  try{$value=$Text|ConvertFrom-Json}catch{throw "invalid workflow configuration JSON: $($_.Exception.Message)"}
  if($null -eq $value -or $value -is [string] -or $value -is [array]){throw 'workflow configuration must be a JSON object'}
  Assert-WorkflowJsonProperties $value @('schema','rules') 'workflow configuration'
  $schema=$null
  if($null -ne $value.schema){if($value.schema -isnot [string] -or "$($value.schema)" -notmatch '^[A-Za-z0-9._-]+$'){throw 'workflow configuration schema must be a safe non-empty string'};$schema="$($value.schema)"}
  $rules=[ordered]@{}
  if($null -ne $value.rules){
    if($value.rules -is [string] -or $value.rules -is [array]){throw 'workflow configuration rules must be an object'}
    foreach($property in $value.rules.PSObject.Properties){
      if($property.Name -notmatch '^[A-Za-z0-9_-]+$'){throw "workflow configuration invalid rule key '$($property.Name)'"}
      if($property.Value -is [string] -or $property.Value -isnot [array]){throw "workflow configuration rule '$($property.Name)' must be an array"}
      $list=New-Object System.Collections.Generic.List[string]
      foreach($item in @($property.Value)){if($item -isnot [string] -or -not $item.Trim()){throw "workflow configuration rule '$($property.Name)' must contain non-empty strings"};[void]$list.Add($item)}
      $rules[$property.Name]=$list
    }
  }
  return [pscustomobject]@{ Schema = $schema; Rules = $rules }
}

function Write-WorkflowConfigFile {
  param(
    [Parameter(Mandatory)][string]$Path,
    [string]$Schema,
    [Parameter(Mandatory)]$Rules,
    [switch]$Generated
  )
  $ruleObject=[ordered]@{}
  foreach($key in @($Rules.Keys)){$ruleObject[$key]=@($Rules[$key])}
  $value=[ordered]@{}
  if($Schema){$value.schema=$Schema}
  $value.rules=$ruleObject
  Write-WorkflowUtf8Text -Path $Path -Text (ConvertTo-WorkflowCanonicalJson $value)
}

function Merge-WorkflowConfig {
  param(
    [Parameter(Mandatory)][string]$WorkflowPath,
    [string]$ProjectPath,
    [Parameter(Mandatory)][string]$OutPath
  )
  if (-not (Test-Path -LiteralPath $WorkflowPath)) {
    throw "Workflow config missing: $WorkflowPath"
  }
  $wf = ConvertFrom-WorkflowConfigText -Text (Read-WorkflowUtf8Text -Path $WorkflowPath)
  $proj = $null
  if ($ProjectPath -and (Test-Path -LiteralPath $ProjectPath)) {
    $proj = ConvertFrom-WorkflowConfigText -Text (Read-WorkflowUtf8Text -Path $ProjectPath)
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

  Write-WorkflowConfigFile -Path $OutPath -Schema $schema -Rules $mergedRules -Generated
}

function Install-WorkflowConfigs {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TargetRoot
  )
  $cfgDstDir = Join-Path $TargetRoot '.workflow'
  New-Item -ItemType Directory -Force -Path $cfgDstDir | Out-Null

  $wfSrc = Join-Path $SourceRoot '.workflow/config.workflow.json'
  if (-not (Test-Path -LiteralPath $wfSrc)) { throw "Missing .workflow/config.workflow.json in source: $SourceRoot" }
  $wfDst = Join-Path $cfgDstDir 'config.workflow.json'
  $wfSrcFull = (Resolve-Path -LiteralPath $wfSrc).Path
  $wfDstFull = [System.IO.Path]::GetFullPath($wfDst)
  if ($wfSrcFull -ne $wfDstFull) {
    Copy-Item -LiteralPath $wfSrc -Destination $wfDst -Force
  }
  $projDst = Join-Path $cfgDstDir 'config.project.json'
  $cfgDst = Join-Path $cfgDstDir 'config.json'
  if (-not (Test-Path -LiteralPath $projDst)) {
    Write-WorkflowConfigFile -Path $projDst -Rules ([ordered]@{})
  }

  Merge-WorkflowConfig -WorkflowPath $wfDst -ProjectPath $projDst -OutPath $cfgDst
}

function Sync-WorkflowConfig {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $ProjectRoot = Resolve-WorkflowPath -Path $ProjectRoot
  if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    throw "project root not found: $ProjectRoot"
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  $workflow = Join-Path $ProjectRoot '.workflow'
  $wf = Join-Path $workflow 'config.workflow.json'
  $proj = Join-Path $workflow 'config.project.json'
  $out = Join-Path $workflow 'config.json'

  if (-not (Test-Path -LiteralPath $wf)) {
    return [pscustomobject]@{ Status = 'MissingWorkflow'; Changed = $false }
  }
  if (-not (Test-Path -LiteralPath $proj)) {
    Write-WorkflowConfigFile -Path $proj -Rules ([ordered]@{})
  }

  $tmp = Join-Path ([IO.Path]::GetTempPath()) ('wf-cfg-sync-' + [guid]::NewGuid().ToString('N') + '.json')
  try {
    Merge-WorkflowConfig -WorkflowPath $wf -ProjectPath $proj -OutPath $tmp
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
  return (ConvertTo-WorkflowCanonicalJson $out)
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
description: Route repository workflow lifecycle requests to the shared workflow pack
globs:
alwaysApply: true
---

# Workflow router

For explicit workflow lifecycle intent, load the matching contract from `.workflow/pack/prompts/` and any contract it references. Use only the repository-local workflow CLI and never install an external lifecycle package.
'@ }
function Get-WorkflowCommandText { param([string]$Operation) "---`nname: /workflow-$Operation`nid: workflow-$Operation`ncategory: Workflow`ndescription: Run repository workflow $Operation`n---`n`nLoad and follow: ``.workflow/pack/prompts/$Operation.md```n" }

function Remove-WorkflowIndexedFiles {
  param([string]$Root, [string]$IndexPath)
  if (-not (Test-Path -LiteralPath $IndexPath -PathType Leaf)) { return }
  try { $index=Read-WorkflowJsonFile $IndexPath } catch { return }
  foreach($rel in @($index.files)) {
    $safe="$rel" -replace '\\','/'
    if ([IO.Path]::IsPathRooted("$rel") -or $safe -match '(^|/)\.\.(/|$)' -or $safe.StartsWith('/')) { throw "unsafe managed path '$safe' in $IndexPath" }
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
    Write-WorkflowUtf8Text (Join-Path $cursorRoot '.workflow-managed.json') (ConvertTo-WorkflowCanonicalJson @{files=$cursorFiles})
    $commands=Join-Path $ProjectRoot '.cursor/commands'; New-Item -ItemType Directory -Force -Path $commands | Out-Null
    foreach($op in @('explore','new','ff','continue','grill','apply','verify','sync','archive','doctor')){Write-WorkflowUtf8Text (Join-Path $commands "workflow-$op.md") (Get-WorkflowCommandText $op)}
    Write-WorkflowUtf8Text (Join-Path $ProjectRoot '.cursor/mcp.json') (ConvertTo-WorkflowCursorMcpJson $servers)
  }
  if($Clients -contains 'codex'){
    $agentRoot=Join-Path $ProjectRoot '.agents/rules'; New-Item -ItemType Directory -Force -Path $agentRoot | Out-Null
    Remove-WorkflowIndexedFiles $agentRoot (Join-Path $agentRoot '.workflow-managed.json')
    $agentFiles=@();foreach($rule in $rules){Write-WorkflowUtf8Text (Join-Path $agentRoot $rule.Name) ($rule.Body.TrimEnd()+"`n");$agentFiles+=$rule.Name}
    Write-WorkflowUtf8Text (Join-Path $agentRoot '.workflow-managed.json') (ConvertTo-WorkflowCanonicalJson @{files=$agentFiles})
    $skill=Join-Path $ProjectRoot '.agents/skills/workflow'; $refs=Join-Path $skill 'references'
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
  $configPath=Join-Path $wf 'config.json';if(-not(Test-Path -LiteralPath $configPath -PathType Leaf)){$configPath=Join-Path $wf 'config.workflow.json'};$config=ConvertFrom-WorkflowConfigText (Read-WorkflowUtf8Text $configPath)
  if(-not $config.Schema){throw 'workflow metadata requires a selected schema'}
  Write-WorkflowUtf8Text (Join-Path $wf 'version.json') (ConvertTo-WorkflowCanonicalJson ([ordered]@{version=$script:WorkflowVersion;schema=$config.Schema;engine='powershell';clients=$Clients}))
  $files=@('.workflow/pack','.workflow/mcp.json','.workflow/rules.json')
  if($Clients -contains 'cursor'){$files+=@('.cursor/mcp.json','.cursor/rules/workflow-router.mdc','.cursor/commands')}
  if($Clients -contains 'codex'){$files+=@('.codex/config.toml','AGENTS.md','.agents/skills/workflow/SKILL.md','.agents/skills/workflow/artifact.json','.agents/skills/workflow/artifact-manifest.json')}
  Write-WorkflowUtf8Text (Join-Path $wf 'manifest.json') (ConvertTo-WorkflowCanonicalJson ([ordered]@{version=$script:WorkflowVersion;files=$files}) 5)
}

function Install-Workflow {
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
  $SourceRoot = (Resolve-Path -LiteralPath $SourceRoot).Path
  $targetExisted=Test-Path -LiteralPath $TargetRoot
  if($targetExisted){if(-not(Test-Path -LiteralPath $TargetRoot -PathType Container)){throw "Target root is not a directory: $TargetRoot"};$TargetRoot=(Resolve-Path -LiteralPath $TargetRoot).Path}
  $self = ($SourceRoot -eq $TargetRoot)
  Test-WorkflowMutationPreflight -SourceRoot $SourceRoot -TargetRoot $TargetRoot -Clients $Clients -FullInstall
  $targetCreated=$false
  $snapshot=$null
  if(-not $self){$snapshotPaths=@('.workflow','openspec','AGENTS.md','scripts/init.ps1','scripts/doctor.ps1','scripts/lib/WorkflowDeploy.psm1');if($Clients -contains 'cursor'){$snapshotPaths+='.cursor'}elseif($Clients -contains 'codex'){$snapshotPaths+=@('.cursor/workflow','.cursor/rules/workflow-router.mdc')+@($script:WorkflowLegacyOpsxCommands|ForEach-Object{".cursor/commands/$_"})};if($Clients -contains 'codex'){$snapshotPaths+=@('.agents/skills/workflow','.agents/skills/openspec-workflow','.agents/rules','.agents/workflow','.codex/config.toml')};$snapshot=New-WorkflowTargetSnapshot -TargetRoot $TargetRoot -RelativePaths $snapshotPaths}
  try {
    if(-not $targetExisted){New-Item -ItemType Directory -Force -Path $TargetRoot -ErrorAction Stop|Out-Null;$targetCreated=$true}
    if(-not $self){Move-WorkflowLegacyProjectData $TargetRoot;if($Clients -contains 'codex'){Remove-WorkflowLegacyCursorRuntime $TargetRoot;Remove-WorkflowLegacyCodexRuntime $TargetRoot}}
    if($Clients -contains 'cursor'){Remove-WorkflowNamespaceSkills -SkillsRoot (Join-Path $TargetRoot '.cursor/skills')}
    if (-not $self) {
      Copy-WorkflowTree -Source (Join-Path $SourceRoot '.workflow/pack') -Destination (Join-Path $TargetRoot '.workflow/pack')
      Copy-WorkflowTree -Source (Join-Path $SourceRoot '.workflow/cli') -Destination (Join-Path $TargetRoot '.workflow/cli')
      Install-WorkflowSelectedSchema -SourceRoot $SourceRoot -TargetRoot $TargetRoot
      $scriptsDst = Join-Path $TargetRoot 'scripts';New-Item -ItemType Directory -Force -Path $scriptsDst | Out-Null
      foreach ($name in @('init.ps1', 'doctor.ps1')) {$s = Join-Path $SourceRoot "scripts/$name";if (Test-Path $s) {Copy-Item -LiteralPath $s -Destination (Join-Path $scriptsDst $name) -Force}}
      $libSrc = Join-Path $SourceRoot 'scripts/lib/WorkflowDeploy.psm1';if (Test-Path $libSrc) {$libDst = Join-Path $scriptsDst 'lib';New-Item -ItemType Directory -Force -Path $libDst | Out-Null;Copy-Item -LiteralPath $libSrc -Destination (Join-Path $libDst 'WorkflowDeploy.psm1') -Force}
    }
    foreach($name in @('mcp.json','rules.json')) {$dst=Join-Path $TargetRoot ".workflow/$name";if(-not(Test-Path -LiteralPath $dst)){Copy-Item -LiteralPath (Join-Path $SourceRoot ".workflow/$name") -Destination $dst -Force}}
    Install-WorkflowConfigs -SourceRoot $SourceRoot -TargetRoot $TargetRoot
    if($Clients -contains 'codex'){Install-WorkflowCodexSkill -SourceRoot $SourceRoot -TargetRoot $TargetRoot}
    Install-WorkflowGeneratedAdapters -ProjectRoot $TargetRoot -Clients $Clients
    $null=Sync-WorkflowConfig -ProjectRoot $TargetRoot
    Write-WorkflowMetadata -ProjectRoot $TargetRoot -Clients $Clients
    if($Clients -contains 'cursor'){
      foreach($legacy in @('.cursor/workflow/version.json','.cursor/workflow/manifest.json')){$p=Join-Path $TargetRoot $legacy;if(Test-Path -LiteralPath $p -PathType Leaf){Remove-Item -LiteralPath $p -Force}}
      $legacyPack=Join-Path $TargetRoot '.cursor/workflow/pack';if(Test-Path -LiteralPath $legacyPack -PathType Container){Remove-Item -LiteralPath $legacyPack -Recurse -Force}
      $legacyState=Join-Path $TargetRoot '.cursor/workflow/state.json';if(Test-Path -LiteralPath $legacyState -PathType Leaf){Remove-Item -LiteralPath $legacyState -Force}
    }
    if($Clients -contains 'codex'){foreach($legacy in @('.agents/workflow/version.json','.agents/workflow/manifest.json','.agents/workflow/state.json')){$p=Join-Path $TargetRoot $legacy;if(Test-Path -LiteralPath $p -PathType Leaf){Remove-Item -LiteralPath $p -Force}}}
  } catch {
    $original=$_.Exception
    if($snapshot){try{Restore-WorkflowTargetSnapshot $snapshot;if($targetCreated){Remove-WorkflowCreatedTarget $TargetRoot}}catch{throw "workflow install failed: $($original.Message); rollback failed: $($_.Exception.Message)"}}
    throw $original
  } finally {if($snapshot){Remove-WorkflowTargetSnapshot $snapshot}}
}

function Get-WorkflowSpecPairErrors {
  param(
    [Parameter(Mandatory)][string]$ProjectRoot
  )
  $errors = New-Object System.Collections.Generic.List[string]
  $roots = New-Object System.Collections.Generic.List[string]
  $main = Join-Path $ProjectRoot '.workflow/specs'
  if (Test-Path $main) { $roots.Add($main) }

  $changes = Join-Path $ProjectRoot '.workflow/changes'
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
      $cursorIndex=ConvertTo-WorkflowCanonicalJson @{files=@('workflow-router.mdc')+@($rules|%{[IO.Path]::ChangeExtension($_.Name,'.mdc')})};&$compare '.cursor/rules/.workflow-managed.json' $cursorIndex
      foreach($op in @('explore','new','ff','continue','grill','apply','verify','sync','archive','doctor')){&$compare ".cursor/commands/workflow-$op.md" (Get-WorkflowCommandText $op)}
      &$compare '.cursor/mcp.json' (ConvertTo-WorkflowCursorMcpJson $servers)
    }
    if($Clients -contains 'codex'){
      foreach($rule in $rules){&$compare ('.agents/rules/'+$rule.Name) $rule.Body}
      $agentIndex=ConvertTo-WorkflowCanonicalJson @{files=@($rules|%{$_.Name})};&$compare '.agents/rules/.workflow-managed.json' $agentIndex
      $codex=Join-Path $ProjectRoot '.codex/config.toml';$expectedBlock=ConvertTo-WorkflowCodexMcpBlock $servers
      if(-not(Test-Path -LiteralPath $codex)){$errors.Add('missing: .codex/config.toml')}else{$raw=Read-WorkflowUtf8Text $codex;$pattern='(?ms)'+[regex]::Escape($script:WorkflowCodexConfigStart)+'.*?'+[regex]::Escape($script:WorkflowCodexConfigEnd);if($raw -notmatch $pattern){$errors.Add('.codex/config.toml missing workflow managed MCP block')}elseif((&$normalize $Matches[0])-ne(&$normalize $expectedBlock)){$errors.Add('generated content drift: .codex/config.toml managed MCP block')}}
      $expectedAgents=Get-WorkflowAgentsBlock $rules;$agents=Join-Path $ProjectRoot 'AGENTS.md'
      if(-not(Test-Path -LiteralPath $agents)){$errors.Add('missing: AGENTS.md')}else{$raw=Read-WorkflowUtf8Text $agents;$pattern='(?ms)'+[regex]::Escape($script:WorkflowAgentsStart)+'.*?'+[regex]::Escape($script:WorkflowAgentsEnd);if($raw -notmatch $pattern){$errors.Add('AGENTS.md missing workflow managed block')}elseif((&$normalize $Matches[0])-ne(&$normalize $expectedAgents)){$errors.Add('generated content drift: AGENTS.md managed block')}}
      foreach($kind in @('prompts','gates')){Get-ChildItem -LiteralPath (Join-Path $ProjectRoot ".workflow/pack/$kind") -File | % {&$compare ('.agents/skills/workflow/references/'+$kind+'/'+$_.Name) (Read-WorkflowUtf8Text $_.FullName)}}
      foreach($name in @('workflow.ps1','WorkflowRuntime.psm1')){&$compare ('.agents/skills/workflow/bin/'+$name) (Read-WorkflowUtf8Text (Join-Path $ProjectRoot ".workflow/cli/$name"))}
    }
    $gateRoot=Join-Path $ProjectRoot '.workflow/pack/gates'
    if(-not(Test-Path -LiteralPath (Join-Path $gateRoot 'acceptance.md') -PathType Leaf)){$errors.Add('missing contract: .workflow/pack/gates/acceptance.md')}
    foreach($oldGate in @('tdd.md','debug.md','verify.md')){if(Test-Path -LiteralPath (Join-Path $gateRoot $oldGate)){$errors.Add("superseded method gate present: .workflow/pack/gates/$oldGate")}}
  } catch {$errors.Add("canonical source invalid: $($_.Exception.Message)")}
  foreach($e in @(Get-WorkflowLegacyResidueErrors $ProjectRoot)){$errors.Add($e)}
  $required=@('.workflow/version.json','.workflow/manifest.json');if($Clients -contains 'codex'){$required+=@('.agents/skills/workflow/SKILL.md','.agents/skills/workflow/agents/openai.yaml','.agents/skills/workflow/bin/workflow.ps1','.agents/skills/workflow/bin/WorkflowRuntime.psm1')}
  foreach($rel in $required){if(-not(Test-Path -LiteralPath (Join-Path $ProjectRoot $rel) -PathType Leaf)){$errors.Add("missing: $rel")}}
  foreach($rel in @('.workflow/version.json','.workflow/manifest.json')){try{$meta=Read-WorkflowJsonFile (Join-Path $ProjectRoot $rel);if($meta.version -ne $script:WorkflowVersion){$errors.Add("metadata version drift: $rel")}}catch{$errors.Add("invalid metadata: $rel - $($_.Exception.Message)")}}
  if($Clients -contains 'cursor'){
    foreach($legacy in @('.cursor/workflow/version.json','.cursor/workflow/manifest.json','.cursor/workflow/state.json')){if(Test-Path -LiteralPath (Join-Path $ProjectRoot $legacy)){$errors.Add("superseded Cursor artifact present: $legacy")}}
    if(Test-Path -LiteralPath (Join-Path $ProjectRoot '.cursor/workflow/pack')){$errors.Add('superseded pack present: .cursor/workflow/pack')}
  }
  if($Clients -contains 'codex'){foreach($legacy in @('.agents/workflow/version.json','.agents/workflow/manifest.json','.agents/workflow/state.json')){if(Test-Path -LiteralPath (Join-Path $ProjectRoot $legacy)){$errors.Add("superseded Codex artifact present: $legacy")}}}

  $wfCfg=Join-Path $ProjectRoot '.workflow/config.workflow.json';$projCfg=Join-Path $ProjectRoot '.workflow/config.project.json';$mergedCfg=Join-Path $ProjectRoot '.workflow/config.json'
  if((Test-Path $wfCfg) -and (Test-Path $projCfg)){$tmpCfg=Join-Path ([IO.Path]::GetTempPath())('wf-doctor-'+[guid]::NewGuid().ToString('N')+'.json');try{Merge-WorkflowConfig $wfCfg $projCfg $tmpCfg;if(-not(Test-Path $mergedCfg) -or (&$normalize(Read-WorkflowUtf8Text $mergedCfg))-ne(&$normalize(Read-WorkflowUtf8Text $tmpCfg))){$errors.Add('generated content drift: .workflow/config.json')}}catch{$errors.Add("invalid workflow configuration: $($_.Exception.Message)")}finally{if(Test-Path $tmpCfg){Remove-Item -LiteralPath $tmpCfg -Force}}}else{foreach($path in @($wfCfg,$projCfg,$mergedCfg)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$errors.Add('missing: '+$path.Substring($ProjectRoot.Length+1).Replace('\','/'))}}}

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

  if($Clients -contains 'codex'){
    try{Test-WorkflowCodexArtifact (Join-Path $ProjectRoot '.agents/skills/workflow')}catch{$errors.Add($_.Exception.Message)}
    foreach($e in @(Get-WorkflowPublishedLocalDoctorErrors -ProjectRoot $ProjectRoot)){$errors.Add($e)}
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
  $skill=Join-Path $SourceRoot '.agents/skills/workflow'
  $files=@(Get-ChildItem -LiteralPath $skill -Recurse -File | Where-Object {$_.Name -notin @('artifact.json','artifact-manifest.json')} | Sort-Object FullName | ForEach-Object {
    $rel=$_.FullName.Substring($skill.Length+1).Replace('\','/')
    [ordered]@{path=$rel;sha256=(Get-WorkflowPortableContentHash $_.FullName)}
  })
  Write-WorkflowUtf8Text (Join-Path $skill 'artifact.json') (ConvertTo-WorkflowCanonicalJson ([ordered]@{schemaVersion=1;name='workflow';version=$script:WorkflowVersion;contracts='references';cli='bin/workflow.ps1'}))
  Write-WorkflowUtf8Text (Join-Path $skill 'artifact-manifest.json') (ConvertTo-WorkflowCanonicalJson ([ordered]@{schemaVersion=1;version=$script:WorkflowVersion;files=$files}) 5)
  Write-WorkflowMetadata -ProjectRoot $SourceRoot -Clients @('cursor','codex')
  return $skill
}

function Test-WorkflowCodexArtifact {
  param([Parameter(Mandatory)][string]$SkillRoot)
  foreach($name in @('SKILL.md','agents/openai.yaml','artifact.json','artifact-manifest.json')){if(-not(Test-Path -LiteralPath (Join-Path $SkillRoot $name) -PathType Leaf)){throw "artifact missing: $name"}}
  $meta=Read-WorkflowJsonFile (Join-Path $SkillRoot 'artifact.json')
  Assert-WorkflowJsonProperties $meta @('schemaVersion','name','version','contracts','cli') 'artifact metadata'
  if($meta.schemaVersion -ne 1){throw 'artifact metadata schemaVersion must be 1'}
  if($meta.name -ne 'workflow'){throw "artifact name drift: $($meta.name)"}
  if($meta.version -ne $script:WorkflowVersion){throw "artifact version drift: expected $script:WorkflowVersion, got $($meta.version)"}
  if($meta.contracts -ne 'references'){throw "artifact contracts path drift: $($meta.contracts)"}
  if($meta.cli -ne 'bin/workflow.ps1'){throw "artifact CLI path drift: $($meta.cli)"}
  $manifest=Read-WorkflowJsonFile (Join-Path $SkillRoot 'artifact-manifest.json')
  Assert-WorkflowJsonProperties $manifest @('schemaVersion','version','files') 'artifact manifest'
  if($manifest.schemaVersion -ne 1){throw 'artifact manifest schemaVersion must be 1'}
  if($manifest.version -ne $script:WorkflowVersion){throw 'artifact manifest version drift'}
  if($manifest.files -is [string] -or $null -eq $manifest.files -or @($manifest.files).Count -eq 0){throw 'artifact manifest files must be a non-empty array'}
  $expected=@{}
  foreach($entry in @($manifest.files)){
    Assert-WorkflowJsonProperties $entry @('path','sha256') 'artifact manifest entry'
    $rel="$($entry.path)".Replace('\','/')
    if(-not $rel -or [IO.Path]::IsPathRooted("$($entry.path)") -or $rel.StartsWith('/') -or $rel -match '(^|/)\.\.(/|$)'){throw "unsafe artifact path: $rel"}
    if($expected.ContainsKey($rel)){throw "duplicate artifact path: $rel"};if("$($entry.sha256)" -notmatch '^[A-Fa-f0-9]{64}$'){throw "invalid artifact hash: $rel"};$expected[$rel]=$true
    $path=Join-Path $SkillRoot $rel
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "artifact file missing: $rel"}
    $actual=Get-WorkflowPortableContentHash $path
    if($actual -ne "$($entry.sha256)"){throw "artifact content drift: $rel"}
  }
  foreach($file in @(Get-ChildItem -LiteralPath $SkillRoot -Recurse -File|Where-Object{$_.Name -notin @('artifact.json','artifact-manifest.json')})){$rel=$file.FullName.Substring($SkillRoot.Length+1).Replace('\','/');if(-not $expected.ContainsKey($rel)){throw "unmanifested artifact file: $rel"}}
}

function Get-WorkflowPublishedLocalDoctorErrors {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $errors=New-Object System.Collections.Generic.List[string]
  $cli=Join-Path $ProjectRoot '.agents/skills/workflow/bin/workflow.ps1'
  if(-not(Test-Path -LiteralPath $cli -PathType Leaf)){$errors.Add('local Doctor unavailable: .agents/skills/workflow/bin/workflow.ps1 missing');return $errors.ToArray()}
  try{
    $raw=@(& $cli -Command doctor -ProjectRoot $ProjectRoot -Arguments @('--json') 2>&1)-join "`n"
    if($LASTEXITCODE -ne 0){$errors.Add("local Doctor failed: $raw");return $errors.ToArray()}
    $result=$raw|ConvertFrom-Json
    if($null -eq $result.Valid){$errors.Add('local Doctor returned an invalid result')}
    elseif(-not [bool]$result.Valid){foreach($error in @($result.Errors)){$errors.Add("local Doctor: $error")}}
  }catch{$errors.Add("local Doctor failed: $($_.Exception.Message)")}
  return $errors.ToArray()
}

function Test-WorkflowManagedIndex {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$IndexPath)
  if(-not(Test-Path -LiteralPath $IndexPath -PathType Leaf)){return}
  $index=Read-WorkflowJsonFile $IndexPath
  Assert-WorkflowJsonProperties $index @('files') $IndexPath
  foreach($rel in @($index.files)){$safe="$rel".Replace('\','/');if(-not $safe -or [IO.Path]::IsPathRooted("$rel") -or $safe.StartsWith('/') -or $safe -match '(^|/)\.\.(/|$)'){throw "unsafe managed path '$safe' in $IndexPath"};$full=[IO.Path]::GetFullPath((Join-Path $Root $safe));$rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\';if(-not $full.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)){throw "managed path escapes root: $safe"}}
}

function Test-WorkflowSchemaDefinition {
  param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$ExpectedName)
  $schema=Read-WorkflowJsonFile $Path
  Assert-WorkflowJsonProperties $schema @('name','version','artifacts') "workflow schema '$ExpectedName'"
  if($schema.name -ne $ExpectedName){throw "workflow schema name mismatch: $Path"}
  $schemaVersion=0;if(-not [int]::TryParse("$($schema.version)",[ref]$schemaVersion) -or $schemaVersion -lt 1){throw "workflow schema version must be a positive integer: $Path"}
  if($schema.artifacts -is [string] -or $null -eq $schema.artifacts -or @($schema.artifacts).Count -eq 0){throw "workflow schema artifacts must be a non-empty array: $Path"}
  $ids=@{}
  foreach($artifact in @($schema.artifacts)){
    Assert-WorkflowJsonProperties $artifact @('id','kind','path','publishPath','required','requires','template','instruction') "workflow schema artifact"
    if(-not $artifact.id -or -not $artifact.kind -or -not $artifact.path -or -not $artifact.template){throw "workflow schema artifact is incomplete: $Path"}
    if("$($artifact.id)" -notmatch '^[A-Za-z0-9._-]+$'){throw "invalid workflow artifact id '$($artifact.id)'"}
    if($artifact.required -isnot [bool]){throw "workflow artifact required must be boolean: $($artifact.id)"}
    if($artifact.requires -is [string] -or $null -eq $artifact.requires -or $artifact.requires -isnot [array]){throw "workflow artifact requires must be an array: $($artifact.id)"}
    if($artifact.instruction -isnot [string] -or -not $artifact.instruction.Trim()){throw "workflow artifact instruction must be a non-empty string: $($artifact.id)"}
    if($artifact.kind -notin @('document','task-list','capability-deltas')){throw "unknown workflow artifact kind '$($artifact.kind)'"}
    if($artifact.kind -eq 'capability-deltas' -and -not $artifact.publishPath){throw "capability-deltas artifact missing publishPath: $($artifact.id)"}
    if($artifact.kind -ne 'capability-deltas' -and $artifact.publishPath){throw "publishPath is only valid for capability-deltas: $($artifact.id)"}
    if($ids.ContainsKey("$($artifact.id)")){throw "duplicate workflow artifact id: $($artifact.id)"};$ids["$($artifact.id)"]=$true
    foreach($relative in @("$($artifact.path)","$($artifact.template)","$($artifact.publishPath)")|Where-Object{$_}){$safe=$relative.Replace('\','/');if([IO.Path]::IsPathRooted($relative) -or $safe.StartsWith('/') -or $safe -match '(^|/)\.\.(/|$)'){throw "unsafe workflow schema path: $relative"}}
  }
  foreach($artifact in @($schema.artifacts)){foreach($dependency in @($artifact.requires)){if($dependency -isnot [string] -or -not $ids.ContainsKey("$dependency")){throw "unknown artifact dependency '$dependency' for $($artifact.id)"};if("$dependency" -eq "$($artifact.id)"){throw "workflow artifact cannot depend on itself: $($artifact.id)"}}}
  return $schema
}

function Get-WorkflowSelectedSchemaName {
  param([Parameter(Mandatory)][string]$SourceRoot,[Parameter(Mandatory)][string]$TargetRoot)
  $workflowPath=Join-Path $SourceRoot '.workflow/config.workflow.json'
  $workflow=ConvertFrom-WorkflowConfigText (Read-WorkflowUtf8Text $workflowPath)
  $projectPath=Join-Path $TargetRoot '.workflow/config.project.json'
  $project=if(Test-Path -LiteralPath $projectPath -PathType Leaf){ConvertFrom-WorkflowConfigText (Read-WorkflowUtf8Text $projectPath)}else{$null}
  $name=if($project -and $project.Schema){$project.Schema}else{$workflow.Schema}
  if(-not $name){throw 'workflow configuration does not select a schema'}
  return $name
}

function Install-WorkflowSelectedSchema {
  param([Parameter(Mandatory)][string]$SourceRoot,[Parameter(Mandatory)][string]$TargetRoot)
  $projectPath=Join-Path $TargetRoot '.workflow/config.project.json';$project=$null
  if(Test-Path -LiteralPath $projectPath -PathType Leaf){$project=ConvertFrom-WorkflowConfigText (Read-WorkflowUtf8Text $projectPath)}
  if($project -and $project.Schema){return}
  $workflow=ConvertFrom-WorkflowConfigText (Read-WorkflowUtf8Text (Join-Path $SourceRoot '.workflow/config.workflow.json'))
  if(-not $workflow.Schema){throw 'workflow source configuration does not select a schema'}
  Copy-WorkflowTree (Join-Path $SourceRoot ".workflow/schemas/$($workflow.Schema)") (Join-Path $TargetRoot ".workflow/schemas/$($workflow.Schema)")
}

function Get-WorkflowRepositoryRelativePath {
  param([Parameter(Mandatory)][string]$ProjectRoot,[Parameter(Mandatory)][string]$Path)
  $root=[IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\','/')
  $full=[IO.Path]::GetFullPath($Path)
  $prefix=$root+[IO.Path]::DirectorySeparatorChar
  if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "path escapes project root: $full"}
  return $full.Substring($prefix.Length).Replace('\','/')
}

function Test-WorkflowLegacyRouter {
  param([Parameter(Mandatory)][string]$Path)
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
  $text=Read-WorkflowUtf8Text $Path
  foreach($marker in $script:WorkflowLegacyRouterMarkers){if($text.IndexOf($marker,[StringComparison]::OrdinalIgnoreCase)-ge 0){return $true}}
  return $false
}

function Get-WorkflowLegacyMigrationPlan {
  param([Parameter(Mandatory)][string]$TargetRoot)
  $TargetRoot=Resolve-WorkflowPath $TargetRoot
  $migrated=New-Object System.Collections.Generic.List[string]
  $removed=New-Object System.Collections.Generic.List[string]
  $preserved=New-Object System.Collections.Generic.List[string]
  $blocked=New-Object System.Collections.Generic.List[string]
  $add={param($list,[string]$value)if($value -and -not $list.Contains($value)){$list.Add($value)}}
  $addReparseBlock={param($item)if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){&$add $blocked (Get-WorkflowRepositoryRelativePath $TargetRoot $item.FullName);return $true};return $false}

  $oldRoot=Join-Path $TargetRoot 'openspec'
  $newRoot=Join-Path $TargetRoot '.workflow'
  if(Test-Path -LiteralPath $oldRoot){
    if(-not(Test-Path -LiteralPath $oldRoot -PathType Container)){&$add $blocked 'openspec'}
    else{
      $oldRootItem=Get-Item -LiteralPath $oldRoot -Force
      if(-not(&$addReparseBlock $oldRootItem)){
        $supported=@('changes','specs','design.md','config.project.yaml','config.workflow.yaml','config.yaml','schemas')
        foreach($item in @(Get-ChildItem -LiteralPath $oldRoot -Force)){
          if(&$addReparseBlock $item){continue}
          if($item.Name -notin $supported){&$add $blocked (Get-WorkflowRepositoryRelativePath $TargetRoot $item.FullName)}
          elseif($item.Name -in @('changes','specs','schemas')){if(-not $item.PSIsContainer){&$add $blocked (Get-WorkflowRepositoryRelativePath $TargetRoot $item.FullName)}}
          elseif($item.PSIsContainer){&$add $blocked (Get-WorkflowRepositoryRelativePath $TargetRoot $item.FullName)}
        }
        foreach($name in @('changes','specs')){
          $old=Join-Path $oldRoot $name;$new=Join-Path $newRoot $name
          if(Test-Path -LiteralPath $old){
            $oldItem=Get-Item -LiteralPath $old -Force
            if(-not $oldItem.PSIsContainer){&$add $blocked (Get-WorkflowRepositoryRelativePath $TargetRoot $old)}
            elseif(-not(&$addReparseBlock $oldItem)){
              foreach($item in @(Get-ChildItem -LiteralPath $old -Force)){
                if($item.Name -eq '.openspec.yaml'){continue}
                if(&$addReparseBlock $item){continue}
                $dest=Join-Path $new $item.Name
                if(Test-Path -LiteralPath $dest){&$add $blocked (Get-WorkflowRepositoryRelativePath $TargetRoot $dest)}
                else{&$add $migrated (Get-WorkflowRepositoryRelativePath $TargetRoot $dest)}
              }
            }
          }
        }
        $oldDesign=Join-Path $oldRoot 'design.md';$newDesign=Join-Path $newRoot 'design.md'
        if(Test-Path -LiteralPath $oldDesign){
          $oldDesignItem=Get-Item -LiteralPath $oldDesign -Force
          if($oldDesignItem.PSIsContainer -or (&$addReparseBlock $oldDesignItem)){&$add $blocked 'openspec/design.md'}
          elseif(Test-Path -LiteralPath $newDesign){
            if(-not(Test-Path -LiteralPath $newDesign -PathType Leaf) -or (Get-WorkflowPortableContentHash $oldDesign) -ne (Get-WorkflowPortableContentHash $newDesign)){&$add $blocked '.workflow/design.md'}
            else{&$add $removed 'openspec/design.md';&$add $preserved '.workflow/design.md'}
          }else{&$add $migrated '.workflow/design.md'}
        }
        foreach($name in @('config.project.yaml','config.workflow.yaml','config.yaml','schemas')){if(Test-Path -LiteralPath (Join-Path $oldRoot $name)){&$add $removed "openspec/$name"}}
      }
    }
  }

  foreach($changesRoot in @((Join-Path $oldRoot 'changes'),(Join-Path $newRoot 'changes'))){
    if(Test-Path -LiteralPath $changesRoot){
      $changesRootItem=Get-Item -LiteralPath $changesRoot -Force
      if(-not $changesRootItem.PSIsContainer -or (&$addReparseBlock $changesRootItem)){&$add $blocked (Get-WorkflowRepositoryRelativePath $TargetRoot $changesRoot);continue}
      foreach($item in @(Get-ChildItem -LiteralPath $changesRoot -Recurse -Force -ErrorAction Stop)){
        if((&$addReparseBlock $item)){continue}
        if(-not $item.PSIsContainer -and $item.Name -eq '.openspec.yaml'){&$add $removed (Get-WorkflowRepositoryRelativePath $TargetRoot $item.FullName)}
      }
    }
  }

  $oldSkill=Join-Path $TargetRoot '.agents/skills/openspec-workflow';if(Test-Path -LiteralPath $oldSkill){$item=Get-Item -LiteralPath $oldSkill -Force;if(-not $item.PSIsContainer -or (&$addReparseBlock $item)){&$add $blocked '.agents/skills/openspec-workflow'}else{&$add $removed '.agents/skills/openspec-workflow'}}
  $cursorWorkflow=Join-Path $TargetRoot '.cursor/workflow'
  if(Test-Path -LiteralPath $cursorWorkflow){$item=Get-Item -LiteralPath $cursorWorkflow -Force;if(-not $item.PSIsContainer -or (&$addReparseBlock $item)){&$add $blocked '.cursor/workflow'}else{&$add $removed '.cursor/workflow'}}
  foreach($name in $script:WorkflowLegacyOpsxCommands){$rel=".cursor/commands/$name";$path=Join-Path $TargetRoot $rel;if(Test-Path -LiteralPath $path){$item=Get-Item -LiteralPath $path -Force;if(&$addReparseBlock $item){continue};if($item.PSIsContainer){&$add $blocked $rel}else{&$add $removed $rel}}}
  $routerRel='.cursor/rules/workflow-router.mdc';$router=Join-Path $TargetRoot $routerRel
  if(Test-Path -LiteralPath $router){$item=Get-Item -LiteralPath $router -Force;if(&$addReparseBlock $item){$null=$true}elseif($item.PSIsContainer){&$add $blocked $routerRel}elseif(Test-WorkflowLegacyRouter $router){&$add $removed $routerRel}else{&$add $preserved $routerRel}}
  foreach($rel in @('.workflow/config.project.json','.workflow/rules.json','.workflow/mcp.json','AGENTS.md','.cursor/mcp.json')){if(Test-Path -LiteralPath (Join-Path $TargetRoot $rel)){&$add $preserved $rel}}

  return [pscustomobject]@{
    Migrated=@($migrated.ToArray()|Sort-Object -Unique)
    Removed=@($removed.ToArray()|Sort-Object -Unique)
    Preserved=@($preserved.ToArray()|Sort-Object -Unique)
    Blocked=@($blocked.ToArray()|Sort-Object -Unique)
  }
}

function Remove-WorkflowLegacyChangeMetadata {
  param([Parameter(Mandatory)][string]$TargetRoot,[Parameter(Mandatory)][string]$ChangesRoot)
  if(-not(Test-Path -LiteralPath $ChangesRoot -PathType Container)){return}
  foreach($file in @(Get-ChildItem -LiteralPath $ChangesRoot -Recurse -Force -File -ErrorAction Stop|Where-Object{$_.Name -eq '.openspec.yaml'})){
    $null=Get-WorkflowRepositoryRelativePath $TargetRoot $file.FullName
    if(($file.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "legacy metadata is a reparse point: $($file.FullName)"}
    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
  }
}

function Remove-WorkflowLegacyCursorRuntime {
  param([Parameter(Mandatory)][string]$TargetRoot)
  $cursorWorkflow=Join-Path $TargetRoot '.cursor/workflow'
  if(Test-Path -LiteralPath $cursorWorkflow){$item=Get-Item -LiteralPath $cursorWorkflow -Force;if(-not $item.PSIsContainer -or ($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "invalid legacy Cursor namespace: $cursorWorkflow"};Remove-Item -LiteralPath $cursorWorkflow -Recurse -Force -ErrorAction Stop}
  foreach($name in $script:WorkflowLegacyOpsxCommands){$path=Join-Path $TargetRoot ".cursor/commands/$name";if(Test-Path -LiteralPath $path){$item=Get-Item -LiteralPath $path -Force;if($item.PSIsContainer -or ($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "invalid legacy Cursor command: $path"};Remove-Item -LiteralPath $path -Force -ErrorAction Stop}}
  $router=Join-Path $TargetRoot '.cursor/rules/workflow-router.mdc';if(Test-WorkflowLegacyRouter $router){$item=Get-Item -LiteralPath $router -Force;if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "legacy Cursor router is a reparse point: $router"};Remove-Item -LiteralPath $router -Force -ErrorAction Stop}
}

function Remove-WorkflowLegacyCodexRuntime {
  param([Parameter(Mandatory)][string]$TargetRoot)
  $oldSkill=Join-Path $TargetRoot '.agents/skills/openspec-workflow'
  if(Test-Path -LiteralPath $oldSkill){
    $item=Get-Item -LiteralPath $oldSkill -Force
    if(-not $item.PSIsContainer -or ($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne 0){throw "invalid legacy Codex skill: $oldSkill"}
    Remove-Item -LiteralPath $oldSkill -Recurse -Force -ErrorAction Stop
  }
}

function Get-WorkflowLegacyResidueErrors {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $errors=New-Object System.Collections.Generic.List[string]
  foreach($rel in @('openspec','.agents/skills/openspec-workflow','.cursor/workflow')){if(Test-Path -LiteralPath (Join-Path $ProjectRoot $rel)){$errors.Add("superseded workflow path present: $rel")}}
  $changes=Join-Path $ProjectRoot '.workflow/changes';if(Test-Path -LiteralPath $changes -PathType Container){foreach($file in @(Get-ChildItem -LiteralPath $changes -Recurse -Force -File -ErrorAction SilentlyContinue|Where-Object{$_.Name -eq '.openspec.yaml'})){$errors.Add("legacy workflow metadata present: $(Get-WorkflowRepositoryRelativePath $ProjectRoot $file.FullName)")}}
  foreach($name in $script:WorkflowLegacyOpsxCommands){$rel=".cursor/commands/$name";if(Test-Path -LiteralPath (Join-Path $ProjectRoot $rel)){$errors.Add("superseded workflow path present: $rel")}}
  $routerRel='.cursor/rules/workflow-router.mdc';$router=Join-Path $ProjectRoot $routerRel;if(Test-WorkflowLegacyRouter $router){$errors.Add("superseded workflow path present: $routerRel")}
  return $errors.ToArray()
}

function Test-WorkflowMutationPreflight {
  param([Parameter(Mandatory)][string]$SourceRoot,[Parameter(Mandatory)][string]$TargetRoot,[string[]]$Clients=@('codex'),[switch]$FullInstall)
  $Clients=@(Resolve-WorkflowClients $Clients)
  foreach($rel in @('.workflow/config.workflow.json','.workflow/schemas','.agents/skills/workflow/SKILL.md')){if(-not(Test-Path -LiteralPath (Join-Path $SourceRoot $rel))){throw "source prerequisite missing: $rel"}}
  if($FullInstall){foreach($rel in @('.workflow/mcp.json','.workflow/rules.json','.workflow/pack/prompts','.workflow/pack/gates','scripts/init.ps1','scripts/doctor.ps1','scripts/lib/WorkflowDeploy.psm1')){if(-not(Test-Path -LiteralPath (Join-Path $SourceRoot $rel))){throw "source prerequisite missing: $rel"}}}
  if($Clients -contains 'codex'){Test-WorkflowCodexArtifact (Join-Path $SourceRoot '.agents/skills/workflow')}
  $rulesRoot=if(Test-Path -LiteralPath (Join-Path $TargetRoot '.workflow/rules.json')){$TargetRoot}elseif($FullInstall){$SourceRoot}else{$null};if($rulesRoot){$null=Get-WorkflowRuleEntries $rulesRoot}
  $mcpRoot=if(Test-Path -LiteralPath (Join-Path $TargetRoot '.workflow/mcp.json')){$TargetRoot}elseif($FullInstall){$SourceRoot}else{$null};if($mcpRoot){$null=Get-WorkflowMcpServers $mcpRoot}
  $schemaName=Get-WorkflowSelectedSchemaName -SourceRoot $SourceRoot -TargetRoot $TargetRoot
  $projectConfigPath=Join-Path $TargetRoot '.workflow/config.project.json';$projectConfig=if(Test-Path -LiteralPath $projectConfigPath -PathType Leaf){ConvertFrom-WorkflowConfigText (Read-WorkflowUtf8Text $projectConfigPath)}else{$null}
  $targetSchema=Join-Path $TargetRoot ".workflow/schemas/$schemaName/schema.json";$sourceSchema=Join-Path $SourceRoot ".workflow/schemas/$schemaName/schema.json";$schemaPath=if($projectConfig -and $projectConfig.Schema){$targetSchema}else{$sourceSchema}
  if(-not(Test-Path -LiteralPath $schemaPath -PathType Leaf)){throw "selected workflow schema missing: $schemaName"};$null=Test-WorkflowSchemaDefinition -Path $schemaPath -ExpectedName $schemaName
  foreach($pair in @(@('.cursor/rules','.workflow-managed.json'),@('.agents/rules','.workflow-managed.json'))){$root=Join-Path $TargetRoot $pair[0];Test-WorkflowManagedIndex -Root $root -IndexPath (Join-Path $root $pair[1])}
  $plan=Get-WorkflowLegacyMigrationPlan $TargetRoot;if(@($plan.Blocked).Count){throw "workflow migration blocked: $(@($plan.Blocked)-join ', ')"}
}

function New-WorkflowTargetSnapshot {
  param([Parameter(Mandatory)][string]$TargetRoot,[Parameter(Mandatory)][string[]]$RelativePaths)
  $snapshotRoot=Join-Path ([IO.Path]::GetTempPath()) ('workflow-target-snapshot-'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Path $snapshotRoot|Out-Null
  $entries=New-Object System.Collections.Generic.List[object];$index=0
  foreach($rel in @($RelativePaths|Sort-Object -Unique)){$target=Join-Path $TargetRoot $rel;$backup=Join-Path $snapshotRoot "$index";$exists=Test-Path -LiteralPath $target;if($exists){Copy-Item -LiteralPath $target -Destination $backup -Recurse -Force};$entries.Add([pscustomobject]@{Relative=$rel;Target=$target;Backup=$backup;Existed=$exists});$index++}
  return [pscustomobject]@{Root=$snapshotRoot;TargetRoot=$TargetRoot;Entries=$entries.ToArray()}
}

function Restore-WorkflowTargetSnapshot {
  param([Parameter(Mandatory)]$Snapshot)
  $targetRoot=[IO.Path]::GetFullPath($Snapshot.TargetRoot).TrimEnd('\')+'\'
  foreach($entry in @($Snapshot.Entries)){$target=[IO.Path]::GetFullPath($entry.Target);if(-not $target.StartsWith($targetRoot,[StringComparison]::OrdinalIgnoreCase)){throw "snapshot target escapes project root: $target"};if(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target -Recurse -Force};if($entry.Existed){$parent=Split-Path -Parent $target;if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Force -Path $parent|Out-Null};Copy-Item -LiteralPath $entry.Backup -Destination $target -Recurse -Force}}
}

function Remove-WorkflowTargetSnapshot {
  param([Parameter(Mandatory)]$Snapshot)
  $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath());$path=[IO.Path]::GetFullPath($Snapshot.Root);if(-not $path.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $path) -notlike 'workflow-target-snapshot-*'){throw "unsafe snapshot cleanup path: $path"};if(Test-Path -LiteralPath $path){$item=Get-Item -LiteralPath $path -Force;if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0){throw "snapshot path is a reparse point: $path"};Remove-Item -LiteralPath $path -Recurse -Force}
}

function Remove-WorkflowCreatedTarget {
  param([Parameter(Mandatory)][string]$TargetRoot)
  if(-not(Test-Path -LiteralPath $TargetRoot)){return}
  $path=[IO.Path]::GetFullPath($TargetRoot);$root=[IO.Path]::GetPathRoot($path)
  if($path.TrimEnd('\') -eq $root.TrimEnd('\')){throw "refusing to remove a filesystem root: $path"}
  $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
  if(-not $item.PSIsContainer){throw "created target is not a directory: $path"}
  if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne 0){throw "created target is a reparse point: $path"}
  Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
}

function Remove-WorkflowPublishedLegacyScripts {
  param([Parameter(Mandatory)][string]$TargetRoot)
  $candidates=@(
    @{path='scripts/init.ps1';markers=@('Install the platform-neutral Workflow','Install-Workflow')},
    @{path='scripts/doctor.ps1';markers=@('Validate a platform-neutral Workflow install','Invoke-WorkflowDoctor')},
    @{path='scripts/lib/WorkflowDeploy.psm1';markers=@('WorkflowDeploy.psm1','WorkflowVersion','Install-Workflow')}
  )
  foreach($candidate in $candidates){
    $path=Join-Path $TargetRoot $candidate.path
    if(Test-Path -LiteralPath $path -PathType Leaf){
      $text=Read-WorkflowUtf8Text $path
      $owned=$true;foreach($marker in $candidate.markers){if($text -notmatch [regex]::Escape($marker)){$owned=$false;break}};if($owned){Remove-Item -LiteralPath $path -Force}
    }
  }
  $lib=Join-Path $TargetRoot 'scripts/lib'
  if((Test-Path -LiteralPath $lib -PathType Container) -and -not(Get-ChildItem -LiteralPath $lib -Force)){Remove-Item -LiteralPath $lib -Force}
}

function Move-WorkflowLegacyProjectData {
  param([Parameter(Mandatory)][string]$TargetRoot)
  $oldRoot=Join-Path $TargetRoot 'openspec';$newRoot=Join-Path $TargetRoot '.workflow'
  if(Test-Path -LiteralPath (Join-Path $newRoot 'changes') -PathType Container){Remove-WorkflowLegacyChangeMetadata -TargetRoot $TargetRoot -ChangesRoot (Join-Path $newRoot 'changes')}
  if(-not(Test-Path -LiteralPath $oldRoot -PathType Container)){return}
  New-Item -ItemType Directory -Force -Path $newRoot|Out-Null
  $oldChanges=Join-Path $oldRoot 'changes';if(Test-Path -LiteralPath $oldChanges -PathType Container){Remove-WorkflowLegacyChangeMetadata -TargetRoot $TargetRoot -ChangesRoot $oldChanges}
  $oldDesign=Join-Path $oldRoot 'design.md';$newDesign=Join-Path $newRoot 'design.md'
  if(Test-Path -LiteralPath $oldDesign -PathType Leaf){
    if(Test-Path -LiteralPath $newDesign){
      if(-not(Test-Path -LiteralPath $newDesign -PathType Leaf) -or (Get-WorkflowPortableContentHash $oldDesign) -ne (Get-WorkflowPortableContentHash $newDesign)){throw "workflow migration blocked: .workflow/design.md"}
      Remove-Item -LiteralPath $oldDesign -Force -ErrorAction Stop
    }else{Move-Item -LiteralPath $oldDesign -Destination $newDesign -ErrorAction Stop}
  }
  foreach($name in @('changes','specs')){
    $old=Join-Path $oldRoot $name;$new=Join-Path $newRoot $name
    if(Test-Path -LiteralPath $old -PathType Container){
      New-Item -ItemType Directory -Force -Path $new|Out-Null
      foreach($item in @(Get-ChildItem -LiteralPath $old -Force)){
        $dest=Join-Path $new $item.Name;if(Test-Path -LiteralPath $dest){throw "workflow migration collision: $dest"};Move-Item -LiteralPath $item.FullName -Destination $dest -ErrorAction Stop
      }
      Remove-Item -LiteralPath $old -Force -ErrorAction Stop
    }
  }
  foreach($name in @('config.project.yaml','config.workflow.yaml','config.yaml')){$path=Join-Path $oldRoot $name;if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force -ErrorAction Stop}}
  $schemas=Join-Path $oldRoot 'schemas';if(Test-Path -LiteralPath $schemas -PathType Container){Remove-Item -LiteralPath $schemas -Recurse -Force -ErrorAction Stop}
  $remaining=@(Get-ChildItem -LiteralPath $oldRoot -Force);if($remaining.Count){throw "unsupported legacy workflow content remains: $(@($remaining.Name)-join ', ')"}
  Remove-Item -LiteralPath $oldRoot -Force -ErrorAction Stop
  if(Test-Path -LiteralPath (Join-Path $newRoot 'changes') -PathType Container){Remove-WorkflowLegacyChangeMetadata -TargetRoot $TargetRoot -ChangesRoot (Join-Path $newRoot 'changes')}
}

function Publish-WorkflowCodexArtifact {
  param(
    [Parameter(Mandatory)][string]$SourceRoot,
    [Parameter(Mandatory)][string]$TargetRoot
  )
  $SourceRoot=Resolve-WorkflowPath $SourceRoot;$TargetRoot=Resolve-WorkflowPath $TargetRoot
  $targetExisted=Test-Path -LiteralPath $TargetRoot
  if($targetExisted -and -not(Test-Path -LiteralPath $TargetRoot -PathType Container)){throw "Target root is not a directory: $TargetRoot"}
  Test-WorkflowMutationPreflight -SourceRoot $SourceRoot -TargetRoot $TargetRoot -Clients codex
  $report=Get-WorkflowLegacyMigrationPlan $TargetRoot
  $targetCreated=$false
  $snapshotPaths=@('.workflow','openspec','AGENTS.md','.agents/skills/workflow','.agents/skills/openspec-workflow','.agents/rules','.codex/config.toml','scripts/init.ps1','scripts/doctor.ps1','scripts/lib/WorkflowDeploy.psm1','.cursor/workflow','.cursor/rules/workflow-router.mdc')+@($script:WorkflowLegacyOpsxCommands|ForEach-Object{".cursor/commands/$_"})
  $snapshot=New-WorkflowTargetSnapshot -TargetRoot $TargetRoot -RelativePaths $snapshotPaths
  try{
    if(-not $targetExisted){New-Item -ItemType Directory -Force -Path $TargetRoot -ErrorAction Stop|Out-Null;$targetCreated=$true}
    $sourceSkill=Join-Path $SourceRoot '.agents/skills/workflow';Move-WorkflowLegacyProjectData $TargetRoot;Remove-WorkflowLegacyCursorRuntime $TargetRoot
    if($env:WORKFLOW_DEPLOY_TEST_FAILPOINT -eq 'after-legacy-cleanup'){throw 'workflow publication test failpoint: after-legacy-cleanup'}
    Remove-WorkflowLegacyCodexRuntime $TargetRoot
    Copy-WorkflowTree $sourceSkill (Join-Path $TargetRoot '.agents/skills/workflow')
    Install-WorkflowSelectedSchema -SourceRoot $SourceRoot -TargetRoot $TargetRoot
    Install-WorkflowConfigs -SourceRoot $SourceRoot -TargetRoot $TargetRoot
    $null=Sync-WorkflowConfig -ProjectRoot $TargetRoot
    $rules=if(Test-Path -LiteralPath (Join-Path $TargetRoot '.workflow/rules.json') -PathType Leaf){@(Get-WorkflowRuleEntries $TargetRoot)}else{@()}
    Install-WorkflowAgentsGuidance -ProjectRoot $TargetRoot -RuleEntries $rules
    $servers=if(Test-Path -LiteralPath (Join-Path $TargetRoot '.workflow/mcp.json') -PathType Leaf){Get-WorkflowMcpServers $TargetRoot}else{[pscustomobject]@{}};$block=ConvertTo-WorkflowCodexMcpBlock $servers
    Set-WorkflowManagedBlock (Join-Path $TargetRoot '.codex/config.toml') $script:WorkflowCodexConfigStart $script:WorkflowCodexConfigEnd $block
    $agentRules=Join-Path $TargetRoot '.agents/rules';$agentIndex=Join-Path $agentRules '.workflow-managed.json'
    if(Test-Path -LiteralPath $agentIndex -PathType Leaf){Remove-WorkflowIndexedFiles $agentRules $agentIndex;Remove-Item -LiteralPath $agentIndex -Force}
    if(@($rules).Count){New-Item -ItemType Directory -Force -Path $agentRules|Out-Null;foreach($rule in @($rules)){Write-WorkflowUtf8Text (Join-Path $agentRules $rule.Name) ($rule.Body.TrimEnd()+"`n")};Write-WorkflowUtf8Text $agentIndex (ConvertTo-WorkflowCanonicalJson @{files=@($rules|ForEach-Object{$_.Name})})}
    foreach($sourceOnly in @('.workflow/pack','.workflow/cli','.workflow/version.json','.workflow/manifest.json')){$path=Join-Path $TargetRoot $sourceOnly;if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Recurse -Force}}
    Remove-WorkflowPublishedLegacyScripts $TargetRoot
  }catch{$original=$_.Exception;try{Restore-WorkflowTargetSnapshot $snapshot;if($targetCreated){Remove-WorkflowCreatedTarget $TargetRoot}}catch{throw "workflow publication failed: $($original.Message); rollback failed: $($_.Exception.Message)"};throw $original}finally{Remove-WorkflowTargetSnapshot $snapshot}
  return $report
}

function Invoke-WorkflowArtifactDoctor {
  param(
    [Parameter(Mandatory)][string]$ProjectRoot,
    [string]$SourceRoot=''
  )
  $ProjectRoot=Resolve-WorkflowPath $ProjectRoot
  $errors=New-Object System.Collections.Generic.List[string]
  foreach($sourceOnly in @('.workflow/pack','.workflow/cli')){if(Test-Path -LiteralPath (Join-Path $ProjectRoot $sourceOnly)){$errors.Add("downstream source layout present: $sourceOnly")}}
  foreach($e in @(Get-WorkflowLegacyResidueErrors $ProjectRoot)){$errors.Add($e)}
  $skill=Join-Path $ProjectRoot '.agents/skills/workflow'
  try{Test-WorkflowCodexArtifact $skill}catch{$errors.Add($_.Exception.Message)}
  try{
    $normalize={param($text)(($text-replace "`r`n","`n").TrimEnd()+"`n")}
    $rules=if(Test-Path -LiteralPath (Join-Path $ProjectRoot '.workflow/rules.json') -PathType Leaf){@(Get-WorkflowRuleEntries $ProjectRoot)}else{@()}
    $ruleIndex=Join-Path $ProjectRoot '.agents/rules/.workflow-managed.json'
    if(@($rules).Count){
      foreach($rule in @($rules)){$path=Join-Path $ProjectRoot ('.agents/rules/'+$rule.Name);if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$errors.Add("missing generated project rule: .agents/rules/$($rule.Name)")}elseif((&$normalize(Read-WorkflowUtf8Text $path))-ne(&$normalize $rule.Body)){$errors.Add("generated project rule drift: .agents/rules/$($rule.Name)")}}
      $expectedIndex=ConvertTo-WorkflowCanonicalJson @{files=@($rules|ForEach-Object{$_.Name})};if(-not(Test-Path -LiteralPath $ruleIndex -PathType Leaf)){$errors.Add('missing generated project rule index: .agents/rules/.workflow-managed.json')}elseif((&$normalize(Read-WorkflowUtf8Text $ruleIndex))-ne(&$normalize $expectedIndex)){$errors.Add('generated project rule index drift: .agents/rules/.workflow-managed.json')}
    }elseif(Test-Path -LiteralPath $ruleIndex){$errors.Add('stale generated project rule index: .agents/rules/.workflow-managed.json')}
    $agentsPath=Join-Path $ProjectRoot 'AGENTS.md';$expectedAgents=Get-WorkflowAgentsBlock $rules
    if(-not(Test-Path -LiteralPath $agentsPath -PathType Leaf)){$errors.Add('missing: AGENTS.md')}else{$raw=Read-WorkflowUtf8Text $agentsPath;$pattern='(?ms)'+[regex]::Escape($script:WorkflowAgentsStart)+'.*?'+[regex]::Escape($script:WorkflowAgentsEnd);if($raw -notmatch $pattern){$errors.Add('AGENTS.md missing workflow managed block')}elseif((&$normalize $Matches[0])-ne(&$normalize $expectedAgents)){$errors.Add('generated content drift: AGENTS.md managed block')}}
    $servers=if(Test-Path -LiteralPath (Join-Path $ProjectRoot '.workflow/mcp.json') -PathType Leaf){Get-WorkflowMcpServers $ProjectRoot}else{[pscustomobject]@{}};$expectedBlock=ConvertTo-WorkflowCodexMcpBlock $servers;$codexPath=Join-Path $ProjectRoot '.codex/config.toml'
    if(-not(Test-Path -LiteralPath $codexPath -PathType Leaf)){$errors.Add('missing: .codex/config.toml')}else{$raw=Read-WorkflowUtf8Text $codexPath;$pattern='(?ms)'+[regex]::Escape($script:WorkflowCodexConfigStart)+'.*?'+[regex]::Escape($script:WorkflowCodexConfigEnd);if($raw -notmatch $pattern){$errors.Add('.codex/config.toml missing workflow managed MCP block')}elseif((&$normalize $Matches[0])-ne(&$normalize $expectedBlock)){$errors.Add('generated content drift: .codex/config.toml managed MCP block')}}
  }catch{$errors.Add("invalid project integration source: $($_.Exception.Message)")}
  foreach($candidate in @(
    @{path='scripts/init.ps1';markers=@('Install the platform-neutral Workflow','Install-Workflow')},
    @{path='scripts/doctor.ps1';markers=@('Validate a platform-neutral Workflow install','Invoke-WorkflowDoctor')},
    @{path='scripts/lib/WorkflowDeploy.psm1';markers=@('WorkflowDeploy.psm1','WorkflowVersion','Install-Workflow')}
  )){
    $path=Join-Path $ProjectRoot $candidate.path
    if(Test-Path -LiteralPath $path -PathType Leaf){$text=Read-WorkflowUtf8Text $path;$owned=$true;foreach($marker in $candidate.markers){if($text -notmatch [regex]::Escape($marker)){$owned=$false;break}};if($owned){$errors.Add("deployment engine present downstream: $($candidate.path)")}}
  }
  foreach($e in @(Get-WorkflowPublishedLocalDoctorErrors -ProjectRoot $ProjectRoot)){$errors.Add($e)}
  if($SourceRoot){
    $SourceRoot=Resolve-WorkflowPath $SourceRoot;$sourceSkill=Join-Path $SourceRoot '.agents/skills/workflow'
    try{Test-WorkflowCodexArtifact $sourceSkill}catch{$errors.Add("source artifact invalid: $($_.Exception.Message)")}
    if(Test-Path -LiteralPath $sourceSkill){
      $sourceFiles=@(Get-ChildItem -LiteralPath $sourceSkill -Recurse -File|%{$_.FullName.Substring($sourceSkill.Length+1).Replace('\','/')})
      $targetFiles=@(Get-ChildItem -LiteralPath $skill -Recurse -File -ErrorAction SilentlyContinue|%{$_.FullName.Substring($skill.Length+1).Replace('\','/')})
      foreach($rel in @($sourceFiles+$targetFiles|Sort-Object -Unique)){
        $s=Join-Path $sourceSkill $rel;$t=Join-Path $skill $rel
        if(-not(Test-Path -LiteralPath $s) -or -not(Test-Path -LiteralPath $t)){$errors.Add("published artifact file set drift: $rel")}
        elseif((Get-WorkflowPortableContentHash $s) -ne (Get-WorkflowPortableContentHash $t)){$errors.Add("published artifact content drift: $rel")}
      }
    }
  }
  foreach($e in (Get-WorkflowSpecPairErrors $ProjectRoot)){$errors.Add($e)}
  return [pscustomobject]@{ExitCode=if($errors.Count){1}else{0};Errors=$errors.ToArray()}
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
  'Merge-WorkflowConfig',
  'Install-WorkflowConfigs',
  'Sync-WorkflowConfig',
  'Install-Workflow',
  'Invoke-WorkflowDoctor',
  'Get-WorkflowSpecPairErrors'
)
