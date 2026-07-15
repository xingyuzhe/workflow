# WorkflowDeploy.psm1 — shared init/doctor logic for Workflow v2

$script:WorkflowVersion = '2.0.0'

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
    'openspec/schemas/workflow-spec/schema.yaml',
    'openspec/config.yaml',
    '.cursor/workflow/version.json',
    '.cursor/workflow/manifest.json'
  )
}

function Write-WorkflowMetadata {
  param([Parameter(Mandatory)][string]$ProjectRoot)
  $wf = Join-Path $ProjectRoot '.cursor/workflow'
  New-Item -ItemType Directory -Force -Path $wf | Out-Null
  $versionPath = Join-Path $wf 'version.json'
  $manifestPath = Join-Path $wf 'manifest.json'
  @{
    version = $script:WorkflowVersion
    schema  = 'workflow-spec'
    engine  = 'powershell'
  } | ConvertTo-Json | Set-Content -Encoding utf8 $versionPath
  @{
    version = $script:WorkflowVersion
    files   = Get-WorkflowManifestFiles
  } | ConvertTo-Json | Set-Content -Encoding utf8 $manifestPath
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

    $cfgSrc = Join-Path $SourceRoot 'openspec/config.yaml'
    $cfgDstDir = Join-Path $TargetRoot 'openspec'
    New-Item -ItemType Directory -Force -Path $cfgDstDir | Out-Null
    Copy-Item -LiteralPath $cfgSrc -Destination (Join-Path $cfgDstDir 'config.yaml') -Force

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

  foreach ($rel in (Get-WorkflowManifestFiles)) {
    # version/manifest written together; still check core files
    if ($rel -in @('.cursor/workflow/version.json', '.cursor/workflow/manifest.json')) { continue }
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
  $wf = Join-Path $ProjectRoot '.cursor/workflow'
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
  ($obj | ConvertTo-Json) | Set-Content -Encoding utf8 $path
  return $path
}

Export-ModuleMember -Function @(
  'Resolve-WorkflowPath',
  'Get-WorkflowNamespaceSkillDirs',
  'Remove-WorkflowNamespaceSkills',
  'Remove-WorkflowOwnedEntries',
  'Copy-WorkflowTree',
  'Get-WorkflowManifestFiles',
  'Write-WorkflowMetadata',
  'Install-WorkflowV2',
  'Invoke-WorkflowDoctor',
  'Get-WorkflowSpecPairErrors',
  'Write-WorkflowState'
)
