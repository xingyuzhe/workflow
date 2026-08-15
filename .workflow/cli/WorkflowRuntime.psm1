Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepositoryWorkflowRoot {
  param([Parameter(Mandatory)][string]$Path)
  $current = [System.IO.Path]::GetFullPath($Path)
  if (Test-Path -LiteralPath $current -PathType Leaf) { $current = Split-Path -Parent $current }
  while ($current) {
    if (Test-Path -LiteralPath (Join-Path $current '.workflow/config.workflow.yaml') -PathType Leaf) { return $current }
    $parent = Split-Path -Parent $current
    if (-not $parent -or $parent -eq $current) { break }
    $current = $parent
  }
  throw "workflow root not found from: $Path"
}

function Read-WorkflowText {
  param([Parameter(Mandatory)][string]$Path)
  [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
}

function Write-WorkflowText {
  param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Text)
  $parent = Split-Path -Parent $Path
  if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Get-WorkflowOption {
  param([string[]]$Arguments,[Parameter(Mandatory)][string]$Name)
  for ($i=0; $i -lt $Arguments.Count; $i++) {
    if ($Arguments[$i] -eq $Name) {
      if (($i+1) -ge $Arguments.Count -or $Arguments[$i+1].StartsWith('--')) { throw "missing value for $Name" }
      return $Arguments[$i+1]
    }
  }
  return $null
}

function Test-WorkflowSwitch {
  param([string[]]$Arguments,[Parameter(Mandatory)][string]$Name)
  return @($Arguments) -contains $Name
}

function Get-WorkflowPositionals {
  param([string[]]$Arguments)
  $result = New-Object System.Collections.Generic.List[string]
  for ($i=0; $i -lt $Arguments.Count; $i++) {
    if ($Arguments[$i].StartsWith('--')) {
      if ($Arguments[$i] -notin @('--json','--yes') -and ($i+1) -lt $Arguments.Count) { $i++ }
      continue
    }
    $result.Add($Arguments[$i])
  }
  return $result.ToArray()
}

function Get-WorkflowConfig {
  param([Parameter(Mandatory)][string]$Root)
  $path = Join-Path $Root '.workflow/config.yaml'
  if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $Root '.workflow/config.workflow.yaml' }
  if (-not (Test-Path -LiteralPath $path)) { throw "missing workflow config: $path" }
  $raw = Read-WorkflowText $path
  $match = [regex]::Match($raw, '(?m)^schema:\s*([A-Za-z0-9._-]+)\s*$')
  if (-not $match.Success) { throw "workflow config missing schema: $path" }
  [pscustomobject]@{Path=$path;Schema=$match.Groups[1].Value}
}

function Get-WorkflowSchema {
  param([Parameter(Mandatory)][string]$Root)
  $config = Get-WorkflowConfig $Root
  $path = Join-Path $Root ".workflow/schemas/$($config.Schema)/schema.json"
  if (-not (Test-Path -LiteralPath $path)) { throw "missing workflow schema: $path" }
  $schema = Read-WorkflowText $path | ConvertFrom-Json
  [pscustomobject]@{Path=$path;Value=$schema}
}

function Get-WorkflowChangeRoot {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Change)
  if ($Change -notmatch '^[a-z0-9][a-z0-9-]*$') { throw "invalid change name: $Change" }
  $path = Join-Path $Root ".workflow/changes/$Change"
  if (-not (Test-Path -LiteralPath $path -PathType Container)) { throw "change not found: $Change" }
  return $path
}

function Get-WorkflowPairErrors {
  param([Parameter(Mandatory)][string]$SpecsRoot)
  $errors = New-Object System.Collections.Generic.List[string]
  if (-not (Test-Path -LiteralPath $SpecsRoot -PathType Container)) { return $errors.ToArray() }
  foreach ($dir in @(Get-ChildItem -LiteralPath $SpecsRoot -Directory -ErrorAction SilentlyContinue)) {
    $spec = Join-Path $dir.FullName 'spec.md'; $design = Join-Path $dir.FullName 'design.md'
    if ((Test-Path -LiteralPath $spec) -xor (Test-Path -LiteralPath $design)) {
      $missing = if (Test-Path -LiteralPath $spec) { $design } else { $spec }
      $errors.Add("missing capability companion: $missing")
    }
  }
  return $errors.ToArray()
}

function Test-WorkflowSpecText {
  param([Parameter(Mandatory)][string]$Path,[switch]$Delta)
  $errors = New-Object System.Collections.Generic.List[string]
  $text = Read-WorkflowText $Path
  if ($Delta -and $text -notmatch '(?m)^## (ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*$') { $errors.Add("missing delta section: $Path") }
  foreach ($match in [regex]::Matches($text, '(?ms)^### Requirement: (?<name>[^\r\n]+)\r?\n(?<body>.*?)(?=^### Requirement: |^## (?:ADDED|MODIFIED|REMOVED|RENAMED) Requirements|\z)')) {
    $body = $match.Groups['body'].Value
    if ($body -notmatch '\b(SHALL|MUST)\b' -and $text.Substring(0,$match.Index) -notmatch '(?s)## (REMOVED|RENAMED) Requirements[^#]*$') { $errors.Add("requirement lacks SHALL/MUST: $Path :: $($match.Groups['name'].Value)") }
    if ($body -notmatch '(?m)^#### Scenario: ' -and $text.Substring(0,$match.Index) -notmatch '(?s)## (REMOVED|RENAMED) Requirements[^#]*$') { $errors.Add("requirement lacks scenario: $Path :: $($match.Groups['name'].Value)") }
    if ($body -match '(?m)^#### Scenario: ' -and ($body -notmatch '(?m)^- \*\*WHEN\*\* ' -or $body -notmatch '(?m)^- \*\*THEN\*\* ')) { $errors.Add("scenario lacks WHEN/THEN: $Path :: $($match.Groups['name'].Value)") }
  }
  return $errors.ToArray()
}

function Test-WorkflowChange {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Change,[switch]$RequireCompletedTasks)
  $changeRoot = Get-WorkflowChangeRoot $Root $Change
  $errors = New-Object System.Collections.Generic.List[string]
  foreach ($name in @('proposal.md','design.md','tasks.md')) { if (-not (Test-Path -LiteralPath (Join-Path $changeRoot $name))) { $errors.Add("missing change artifact: $Change/$name") } }
  foreach ($error in @(Get-WorkflowPairErrors (Join-Path $changeRoot 'specs'))) { $errors.Add($error) }
  foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $changeRoot 'specs') -Filter 'spec.md' -Recurse -File -ErrorAction SilentlyContinue)) {
    foreach ($error in @(Test-WorkflowSpecText $file.FullName -Delta)) { $errors.Add($error) }
  }
  $tasksPath = Join-Path $changeRoot 'tasks.md'
  if (Test-Path -LiteralPath $tasksPath) {
    $tasks = Read-WorkflowText $tasksPath
    foreach ($line in @($tasks -split "`r?`n" | Where-Object { $_ -match '^- \[[ xX]\]' })) {
      if ($line -notmatch '^- \[[ xX]\] \d+\.\d+ .+') { $errors.Add("invalid task line: $line") }
    }
    if ($RequireCompletedTasks -and $tasks -match '(?m)^- \[ \] ') { $errors.Add("change has incomplete tasks: $Change") }
  }
  [pscustomobject]@{Valid=($errors.Count -eq 0);Errors=$errors.ToArray();Path=$changeRoot}
}

function Get-WorkflowStatus {
  param([Parameter(Mandatory)][string]$Root,[string]$Change)
  $changesRoot = Join-Path $Root '.workflow/changes'
  if (-not $Change) {
    $active = @(Get-ChildItem -LiteralPath $changesRoot -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'archive' })
    if ($active.Count -eq 0) { return [pscustomobject]@{changes=@();message='No active changes.';root=$Root} }
    if ($active.Count -gt 1) { return [pscustomobject]@{changes=@($active.Name|Sort-Object);message='Multiple active changes; pass --change.';root=$Root} }
    $Change = $active[0].Name
  }
  $changeRoot = Get-WorkflowChangeRoot $Root $Change
  $schema = (Get-WorkflowSchema $Root).Value
  $artifacts = New-Object System.Collections.Generic.List[object]
  foreach ($artifact in @($schema.artifacts)) {
    $done = $false
    if ($artifact.id -eq 'specs') {
      $specRoot = Join-Path $changeRoot 'specs'
      $pairs = @(Get-ChildItem -LiteralPath $specRoot -Directory -ErrorAction SilentlyContinue)
      $done = $pairs.Count -gt 0 -and @(Get-WorkflowPairErrors $specRoot).Count -eq 0
    } else { $done = Test-Path -LiteralPath (Join-Path $changeRoot $artifact.path) -PathType Leaf }
    $status = if ($done) { 'done' } elseif ($artifact.required) { 'ready' } else { 'optional' }
    $artifacts.Add([pscustomobject]@{id=$artifact.id;path=$artifact.path;status=$status;required=[bool]$artifact.required})
  }
  $validation = Test-WorkflowChange $Root $Change
  [pscustomobject]@{change=$Change;isComplete=$validation.Valid;applyReady=$validation.Valid;artifacts=$artifacts.ToArray();errors=$validation.Errors;root=$Root}
}

function Get-WorkflowRequirementBlocks {
  param([Parameter(Mandatory)][string]$Text)
  $blocks = New-Object System.Collections.Generic.List[object]
  foreach ($match in [regex]::Matches($Text, '(?ms)^### Requirement: (?<name>[^\r\n]+)\r?\n.*?(?=^### Requirement: |\z)')) {
    $blocks.Add([pscustomobject]@{Name=$match.Groups['name'].Value.Trim();Text=$match.Value.TrimEnd()})
  }
  return $blocks.ToArray()
}

function Merge-WorkflowDeltaSpec {
  param([Parameter(Mandatory)][string]$DeltaPath,[Parameter(Mandatory)][string]$MainPath,[Parameter(Mandatory)][string]$Capability)
  $delta = Read-WorkflowText $DeltaPath
  $main = if (Test-Path -LiteralPath $MainPath) { Read-WorkflowText $MainPath } else { "# $Capability Specification`n`n## Purpose`n`nDefine the accepted $Capability behavior.`n" }
  $introMatch = [regex]::Match($main, '(?s)\A.*?(?=^### Requirement: |\z)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
  $intro = $introMatch.Value.TrimEnd()
  $order = New-Object System.Collections.Generic.List[string]
  $map = @{}
  foreach ($block in @(Get-WorkflowRequirementBlocks $main)) { $order.Add($block.Name); $map[$block.Name]=$block.Text }
  foreach ($section in [regex]::Matches($delta, '(?ms)^## (?<op>ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*(?<body>.*?)(?=^## (?:ADDED|MODIFIED|REMOVED|RENAMED) Requirements|\z)')) {
    $op=$section.Groups['op'].Value; $body=$section.Groups['body'].Value
    if ($op -eq 'RENAMED') {
      $from=[regex]::Match($body,'(?m)^FROM:\s*(.+)$');$to=[regex]::Match($body,'(?m)^TO:\s*(.+)$')
      if(-not $from.Success -or -not $to.Success){throw "invalid RENAMED section: $DeltaPath"}
      $old=$from.Groups[1].Value.Trim();$new=$to.Groups[1].Value.Trim();if(-not $map.ContainsKey($old)){if($map.ContainsKey($new)){continue};throw "rename source missing: $old"}
      $map[$new]=[regex]::Replace($map[$old],'^### Requirement: .+$',"### Requirement: $new",[System.Text.RegularExpressions.RegexOptions]::Multiline);$map.Remove($old)
      $index=$order.IndexOf($old);$order[$index]=$new;continue
    }
    foreach($block in @(Get-WorkflowRequirementBlocks $body)){
      if($op -eq 'ADDED') { if(-not $map.ContainsKey($block.Name)){$order.Add($block.Name)};$map[$block.Name]=$block.Text }
      elseif($op -eq 'MODIFIED') { if(-not $map.ContainsKey($block.Name)){throw "modified requirement missing: $($block.Name)"};$map[$block.Name]=$block.Text }
      elseif($op -eq 'REMOVED') { if($map.ContainsKey($block.Name)){$map.Remove($block.Name);$order.Remove($block.Name)|Out-Null} }
    }
  }
  $parts=New-Object System.Collections.Generic.List[string];$parts.Add($intro);foreach($name in $order){if($map.ContainsKey($name)){$parts.Add($map[$name])}}
  Write-WorkflowText $MainPath (($parts -join "`n`n").TrimEnd()+"`n")
}

function Sync-WorkflowChange {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Change)
  $validation=Test-WorkflowChange $Root $Change;if(-not $validation.Valid){throw ($validation.Errors -join "`n")}
  $changeSpecs=Join-Path $validation.Path 'specs';$mainSpecs=Join-Path $Root '.workflow/specs';$updated=New-Object System.Collections.Generic.List[string]
  foreach($cap in @(Get-ChildItem -LiteralPath $changeSpecs -Directory -ErrorAction SilentlyContinue)){
    $dest=Join-Path $mainSpecs $cap.Name;New-Item -ItemType Directory -Force -Path $dest|Out-Null
    Merge-WorkflowDeltaSpec (Join-Path $cap.FullName 'spec.md') (Join-Path $dest 'spec.md') $cap.Name
    Copy-Item -LiteralPath (Join-Path $cap.FullName 'design.md') -Destination (Join-Path $dest 'design.md') -Force
    $updated.Add($cap.Name)
  }
  return $updated.ToArray()
}

function Invoke-RepositoryWorkflow {
  param([Parameter(Mandatory)][string]$Command,[string[]]$Arguments=@(),[Parameter(Mandatory)][string]$ProjectRoot)
  $root=Resolve-RepositoryWorkflowRoot $ProjectRoot;$json=Test-WorkflowSwitch $Arguments '--json';$change=Get-WorkflowOption $Arguments '--change'
  switch($Command.ToLowerInvariant()){
    'new' {
      $positionals=@(Get-WorkflowPositionals $Arguments);if($positionals.Count -lt 1){throw 'usage: workflow.ps1 new <change> [--json]'};$name=$positionals[0]
      if($name -notmatch '^[a-z0-9][a-z0-9-]*$'){throw "invalid change name: $name"};$dir=Join-Path $root ".workflow/changes/$name";if(Test-Path $dir){throw "change already exists: $name"}
      New-Item -ItemType Directory -Force -Path $dir|Out-Null;Copy-Item (Join-Path $root '.workflow/schemas/workflow-contract/templates/proposal.md') (Join-Path $dir 'proposal.md')
      $value=[pscustomobject]@{change=$name;path=$dir;next='proposal'}
    }
    'status' { $value=Get-WorkflowStatus $root $change }
    'instructions' {
      $positionals=@(Get-WorkflowPositionals $Arguments);if($positionals.Count -lt 1){throw 'usage: workflow.ps1 instructions <artifact> --change <name> [--json]'};$artifactId=$positionals[0]
      if(-not $change){throw 'instructions requires --change'};$null=Get-WorkflowChangeRoot $root $change;$schema=Get-WorkflowSchema $root;$artifact=@($schema.Value.artifacts|Where-Object{$_.id -eq $artifactId})|Select-Object -First 1;if(-not $artifact){throw "unknown artifact: $artifactId"}
      $templatePath=Join-Path (Split-Path -Parent $schema.Path) $artifact.template;$value=[pscustomobject]@{change=$change;artifact=$artifactId;path=$artifact.path;requires=@($artifact.requires);instruction=$artifact.instruction;template=(Read-WorkflowText $templatePath)}
    }
    'validate' {
      if($change){$value=Test-WorkflowChange $root $change}else{$errors=Get-WorkflowPairErrors (Join-Path $root '.workflow/specs');$value=[pscustomobject]@{Valid=(@($errors).Count -eq 0);Errors=@($errors);Path=(Join-Path $root '.workflow/specs')}}
      if(-not $value.Valid -and -not $json){throw ($value.Errors -join "`n")}
    }
    'sync' { if(-not $change){throw 'sync requires --change'};$value=[pscustomobject]@{change=$change;updated=@(Sync-WorkflowChange $root $change)} }
    'archive' {
      if(-not $change){$positionals=@(Get-WorkflowPositionals $Arguments);if($positionals.Count){$change=$positionals[0]}};if(-not $change){throw 'archive requires a change name'}
      $validation=Test-WorkflowChange $root $change -RequireCompletedTasks;if(-not $validation.Valid){throw ($validation.Errors -join "`n")};$updated=@(Sync-WorkflowChange $root $change)
      $archiveRoot=Join-Path $root '.workflow/changes/archive';New-Item -ItemType Directory -Force -Path $archiveRoot|Out-Null;$archiveName="$(Get-Date -Format 'yyyy-MM-dd')-$change";$dest=Join-Path $archiveRoot $archiveName;if(Test-Path $dest){throw "archive already exists: $archiveName"};Move-Item -LiteralPath $validation.Path -Destination $dest
      $value=[pscustomobject]@{change=$change;archived=$true;archivedAs=$archiveName;path=$dest;updated=$updated}
    }
    'doctor' {
      $errors=New-Object System.Collections.Generic.List[string];try{$null=Get-WorkflowSchema $root}catch{$errors.Add($_.Exception.Message)};foreach($e in @(Get-WorkflowPairErrors (Join-Path $root '.workflow/specs'))){$errors.Add($e)}
      $localCli=Join-Path $root '.agents/skills/workflow/bin/workflow.ps1';if(-not(Test-Path $localCli)){$errors.Add("missing published local CLI: $localCli")}
      $value=[pscustomobject]@{Valid=($errors.Count -eq 0);Errors=$errors.ToArray();Root=$root};if(-not $value.Valid -and -not $json){throw ($value.Errors -join "`n")}
    }
    'help' { return 'workflow commands: new, status, instructions, validate, sync, archive, doctor' }
    default { throw "unknown workflow command: $Command" }
  }
  if($json){return ($value|ConvertTo-Json -Depth 12)}
  return $value
}

Export-ModuleMember -Function @('Invoke-RepositoryWorkflow','Resolve-RepositoryWorkflowRoot','Get-WorkflowStatus','Test-WorkflowChange','Sync-WorkflowChange')
