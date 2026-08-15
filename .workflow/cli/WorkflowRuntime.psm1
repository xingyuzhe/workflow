Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepositoryWorkflowRoot {
  param([Parameter(Mandatory)][string]$Path)
  $current = [System.IO.Path]::GetFullPath($Path)
  if (Test-Path -LiteralPath $current -PathType Leaf) { $current = Split-Path -Parent $current }
  while ($current) {
    if (Test-Path -LiteralPath (Join-Path $current '.workflow/config.workflow.json') -PathType Leaf) { return $current }
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

function ConvertTo-WorkflowJson {
  param([Parameter(Mandatory)]$Value)
  return (($Value | ConvertTo-Json -Depth 20 -Compress) + "`n")
}

function Assert-WorkflowObjectProperties {
  param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string[]]$Allowed,[Parameter(Mandatory)][string]$Context)
  if($null -eq $Object -or $Object -is [string] -or $Object -is [array]){throw "$Context must be an object"}
  foreach($property in $Object.PSObject.Properties.Name){if($property -notin $Allowed){throw "$Context contains unsupported field '$property'"}}
}

function Write-WorkflowDurableText {
  param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Text)
  $parent=Split-Path -Parent $Path
  if(-not(Test-Path -LiteralPath $parent -PathType Container)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
  $temporary=Join-Path $parent ('.workflow-write-'+[guid]::NewGuid().ToString('N')+'.tmp')
  $backup=Join-Path $parent ('.workflow-write-'+[guid]::NewGuid().ToString('N')+'.bak')
  try{
    $bytes=([Text.UTF8Encoding]::new($false)).GetBytes($Text)
    $stream=[IO.FileStream]::new($temporary,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,4096,[IO.FileOptions]::WriteThrough)
    try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
    if(Test-Path -LiteralPath $Path -PathType Leaf){[IO.File]::Replace($temporary,$Path,$backup);Remove-Item -LiteralPath $backup -Force}else{[IO.File]::Move($temporary,$Path)}
  }finally{
    if(Test-Path -LiteralPath $temporary -PathType Leaf){Remove-Item -LiteralPath $temporary -Force}
    if(Test-Path -LiteralPath $backup -PathType Leaf){Remove-Item -LiteralPath $backup -Force}
  }
}

function Assert-WorkflowNoReparsePath {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Context)
  $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd([char[]]@('\','/'))
  $pathFull=[IO.Path]::GetFullPath($Path)
  $prefix=$rootFull+[IO.Path]::DirectorySeparatorChar
  if(-not $pathFull.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "$Context escapes its root: $Path"}
  $current=$rootFull
  foreach($part in $pathFull.Substring($prefix.Length).Split([char[]]@('\','/'),[StringSplitOptions]::RemoveEmptyEntries)){
    $current=Join-Path $current $part
    if(-not(Test-Path -LiteralPath $current)){break}
    $item=Get-Item -LiteralPath $current -Force
    if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "$Context contains a reparse point: $current"}
  }
}

function Copy-WorkflowPath {
  param([Parameter(Mandatory)][string]$Source,[Parameter(Mandatory)][string]$Destination)
  $item=Get-Item -LiteralPath $Source -Force -ErrorAction Stop
  if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "transaction path contains a reparse point: $Source"}
  if($item.PSIsContainer){
    if(Test-Path -LiteralPath $Destination){throw "transaction copy destination already exists: $Destination"}
    New-Item -ItemType Directory -Path $Destination|Out-Null
    foreach($child in @(Get-ChildItem -LiteralPath $Source -Force)){Copy-WorkflowPath -Source $child.FullName -Destination (Join-Path $Destination $child.Name)}
  }else{
    $parent=Split-Path -Parent $Destination;if(-not(Test-Path -LiteralPath $parent -PathType Container)){New-Item -ItemType Directory -Force -Path $parent|Out-Null}
    $input=[IO.FileStream]::new($Source,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{
      $output=[IO.FileStream]::new($Destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,4096,[IO.FileOptions]::WriteThrough)
      try{$input.CopyTo($output);$output.Flush($true)}finally{$output.Dispose()}
    }finally{$input.Dispose()}
  }
}

function Remove-WorkflowPath {
  param([Parameter(Mandatory)][string]$Path)
  if(-not(Test-Path -LiteralPath $Path)){return}
  $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
  if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "refusing to remove reparse point: $Path"}
  if($item.PSIsContainer){foreach($child in @(Get-ChildItem -LiteralPath $Path -Force)){Remove-WorkflowPath $child.FullName};Remove-Item -LiteralPath $Path -Force}
  else{Remove-Item -LiteralPath $Path -Force}
}

function Resolve-WorkflowTransactionTarget {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Relative,[Parameter(Mandatory)][string]$Context)
  if(-not $Relative -or [IO.Path]::IsPathRooted($Relative)){throw "$Context has an unsafe target: $Relative"}
  $portable=$Relative.Replace('\','/').Trim('/')
  if(-not $portable -or $portable -match '[:*?"<>|]' -or $portable -match '(^|/)\.\.?(/|$)' -or $portable -match '(^|/)(?:\.workflow/\.transactions|\.workflow/\.mutation\.lock)(?:/|$)'){throw "$Context has an unsafe target: $Relative"}
  $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd([char[]]@('\','/'))
  $full=[IO.Path]::GetFullPath((Join-Path $rootFull $portable.Replace('/',[IO.Path]::DirectorySeparatorChar)))
  if(-not $full.StartsWith($rootFull+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw "$Context target escapes repository: $Relative"}
  Assert-WorkflowNoReparsePath -Root $rootFull -Path $full -Context $Context
  return [pscustomobject]@{Relative=$portable;Full=$full}
}

function Get-WorkflowTransactionRelativeTarget {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Path)
  $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd([char[]]@('\','/'));$full=[IO.Path]::GetFullPath($Path)
  $prefix=$rootFull+[IO.Path]::DirectorySeparatorChar
  if(-not $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "transaction target is outside repository: $Path"}
  return $full.Substring($prefix.Length).Replace('\','/')
}

function Invoke-WorkflowTestFailpoint {
  param([Parameter(Mandatory)][string]$Name)
  if($env:WORKFLOW_ENABLE_TEST_HOOKS -ne '1' -or $env:WORKFLOW_TEST_FAILPOINT -ne $Name){return}
  if($Name.StartsWith('crash-')){[Environment]::Exit(86)}
  throw "workflow test failpoint: $Name"
}

function Enter-WorkflowMutationLock {
  param([Parameter(Mandatory)][string]$Root)
  $path=Join-Path $Root '.workflow/.mutation.lock';$parent=Split-Path -Parent $path
  if(-not(Test-Path -LiteralPath $parent -PathType Container)){throw "missing workflow data root: $parent"}
  $stream=$null
  for($attempt=0;$attempt -lt 3 -and $null -eq $stream;$attempt++){
    try{$stream=[IO.FileStream]::new($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::Delete,4096,[IO.FileOptions]::WriteThrough)}
    catch [IO.IOException]{
      if(Test-Path -LiteralPath $path){$lockItem=Get-Item -LiteralPath $path -Force;if(($lockItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "invalid lifecycle mutation lock reparse point: $path"}}
      try{$stream=[IO.FileStream]::new($path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::Delete,4096,[IO.FileOptions]::WriteThrough)}
      catch [IO.FileNotFoundException]{continue}
      catch [IO.IOException]{throw "lifecycle mutation lock is owned by another writer: $path"}
    }
  }
  if($null -eq $stream){throw "unable to acquire lifecycle mutation lock: $path"}
  try{
    $token=([ordered]@{id=[guid]::NewGuid().ToString('N');pid=$PID;acquiredAt=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json -Compress)+"`n"
    $bytes=([Text.UTF8Encoding]::new($false)).GetBytes($token);$stream.SetLength(0);$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)
    return [pscustomobject]@{Path=$path;Stream=$stream}
  }catch{$stream.Dispose();throw}
}

function Exit-WorkflowMutationLock {
  param([Parameter(Mandatory)]$Lock)
  try{if(Test-Path -LiteralPath $Lock.Path -PathType Leaf){[IO.File]::Delete($Lock.Path)}}finally{$Lock.Stream.Dispose()}
}

function Read-WorkflowTransaction {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$TransactionPath)
  $directory=Get-Item -LiteralPath $TransactionPath -Force -ErrorAction Stop
  if(-not $directory.PSIsContainer -or ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "invalid lifecycle transaction directory: $TransactionPath"}
  $id=$directory.Name;if($id -notmatch '^[a-f0-9]{32}$'){throw "invalid lifecycle transaction id: $id"}
  $journalPath=Join-Path $TransactionPath 'journal.json';if(-not(Test-Path -LiteralPath $journalPath -PathType Leaf)){throw "missing lifecycle transaction journal: $journalPath"}
  $journalItem=Get-Item -LiteralPath $journalPath -Force;if(($journalItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "invalid lifecycle transaction journal reparse point: $journalPath"}
  try{$journal=Read-WorkflowText $journalPath|ConvertFrom-Json}catch{throw "invalid lifecycle transaction journal: $journalPath - $($_.Exception.Message)"}
  Assert-WorkflowObjectProperties $journal @('schemaVersion','id','phase','operation','createdAt','targets') "lifecycle transaction journal: $journalPath"
  if($null -eq $journal.schemaVersion -or $journal.schemaVersion.GetType().FullName -notmatch '^System\.(?:S?Byte|U?Int(?:16|32|64))$' -or [int64]$journal.schemaVersion -ne 1){throw "lifecycle transaction schemaVersion must be the integer 1: $journalPath"}
  if($journal.id -isnot [string] -or $journal.id -ne $id){throw "lifecycle transaction id mismatch: $journalPath"}
  if($journal.phase -isnot [string] -or $journal.phase -notin @('prepared','committing','committed')){throw "invalid lifecycle transaction phase: $journalPath"}
  if($journal.operation -isnot [string] -or $journal.operation -notin @('sync','archive')){throw "invalid lifecycle transaction operation: $journalPath"}
  $created=[DateTimeOffset]::MinValue
  if($journal.createdAt -is [datetime]){$created=[DateTimeOffset]$journal.createdAt}
  elseif($journal.createdAt -is [DateTimeOffset]){$created=$journal.createdAt}
  elseif($journal.createdAt -isnot [string] -or -not [DateTimeOffset]::TryParse($journal.createdAt,[ref]$created)){throw "invalid lifecycle transaction createdAt: $journalPath"}
  if($null -eq $journal.targets -or $journal.targets -is [string] -or $journal.targets -isnot [array] -or @($journal.targets).Count -eq 0){throw "lifecycle transaction targets must be a non-empty array: $journalPath"}
  $targets=New-Object System.Collections.Generic.List[object];$seen=New-Object System.Collections.Generic.List[string]
  for($index=0;$index -lt @($journal.targets).Count;$index++){
    $target=$journal.targets[$index];Assert-WorkflowObjectProperties $target @('target','operation','existed','original','prepared','role') "lifecycle transaction target ${index}: $journalPath"
    if($target.target -isnot [string]){throw "lifecycle transaction target path must be a string: $journalPath"}
    $resolved=Resolve-WorkflowTransactionTarget -Root $Root -Relative $target.target -Context "lifecycle transaction target ${index}"
    foreach($other in $seen){if($resolved.Relative -eq $other -or $resolved.Relative.StartsWith($other+'/',[StringComparison]::OrdinalIgnoreCase) -or $other.StartsWith($resolved.Relative+'/',[StringComparison]::OrdinalIgnoreCase)){throw "overlapping lifecycle transaction targets: $other and $($resolved.Relative)"}}
    $seen.Add($resolved.Relative)
    if($target.operation -isnot [string] -or $target.operation -notin @('replace','delete')){throw "invalid lifecycle transaction target operation: $journalPath"}
    if($target.existed -isnot [bool]){throw "lifecycle transaction target existed must be boolean: $journalPath"}
    if($target.original -isnot [string] -or $target.prepared -isnot [string] -or $target.role -isnot [string] -or $target.role -notin @('capability','receipt','archive','active-change')){throw "invalid lifecycle transaction target metadata: $journalPath"}
    $expectedOriginal=if($target.existed){"original/$index"}else{''};$expectedPrepared=if($target.operation -eq 'replace'){"prepared/$index"}else{''}
    if($target.original -ne $expectedOriginal -or $target.prepared -ne $expectedPrepared){throw "invalid lifecycle transaction storage path: $journalPath target $index"}
    $originalPath=if($target.original){Join-Path $TransactionPath $target.original}else{$null};$preparedPath=if($target.prepared){Join-Path $TransactionPath $target.prepared}else{$null}
    if($originalPath){Assert-WorkflowNoReparsePath -Root $TransactionPath -Path $originalPath -Context "transaction original $index"}
    if($preparedPath){Assert-WorkflowNoReparsePath -Root $TransactionPath -Path $preparedPath -Context "transaction prepared $index"}
    $targets.Add([pscustomobject]@{Entry=$target;FullTarget=$resolved.Full;OriginalPath=$originalPath;PreparedPath=$preparedPath;Index=$index})
  }
  return [pscustomobject]@{Path=$TransactionPath;JournalPath=$journalPath;Journal=$journal;Targets=$targets.ToArray()}
}

function Assert-WorkflowTransactionCanRestore {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)]$Transaction)
  foreach($target in @($Transaction.Targets)){
    Assert-WorkflowNoReparsePath -Root $Root -Path $target.FullTarget -Context 'transaction rollback target'
    if($target.Entry.existed){if(-not(Test-Path -LiteralPath $target.OriginalPath)){throw "missing lifecycle transaction original: $($target.OriginalPath)"};Assert-WorkflowNoReparsePath -Root $Transaction.Path -Path $target.OriginalPath -Context 'transaction original'}
  }
}

function Restore-WorkflowTransaction {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)]$Transaction)
  Assert-WorkflowTransactionCanRestore -Root $Root -Transaction $Transaction
  foreach($target in @($Transaction.Targets|Sort-Object Index -Descending)){
    Remove-WorkflowPath $target.FullTarget
    if($target.Entry.existed){Copy-WorkflowPath -Source $target.OriginalPath -Destination $target.FullTarget}
  }
}

function Remove-WorkflowTransaction {
  param([Parameter(Mandatory)]$Transaction)
  Remove-WorkflowPath $Transaction.Path
}

function Get-WorkflowIncompleteTransactions {
  param([Parameter(Mandatory)][string]$Root)
  $transactionsRoot=Join-Path $Root '.workflow/.transactions'
  if(-not(Test-Path -LiteralPath $transactionsRoot)){return @()}
  $rootItem=Get-Item -LiteralPath $transactionsRoot -Force
  if(-not $rootItem.PSIsContainer -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "invalid lifecycle transactions root: $transactionsRoot"}
  $transactions=New-Object System.Collections.Generic.List[object]
  foreach($entry in @(Get-ChildItem -LiteralPath $transactionsRoot -Force|Sort-Object Name)){
    if(-not $entry.PSIsContainer){throw "unexpected lifecycle transaction entry: $($entry.FullName)"}
    $transaction=Read-WorkflowTransaction -Root $Root -TransactionPath $entry.FullName
    if($transaction.Journal.phase -eq 'committing'){Assert-WorkflowTransactionCanRestore -Root $Root -Transaction $transaction}
    $transactions.Add($transaction)
  }
  return $transactions.ToArray()
}

function Repair-WorkflowIncompleteTransactions {
  param([Parameter(Mandatory)][string]$Root)
  $transactions=@(Get-WorkflowIncompleteTransactions $Root)
  foreach($transaction in $transactions){
    if($transaction.Journal.phase -eq 'committing'){Restore-WorkflowTransaction -Root $Root -Transaction $transaction}
    Remove-WorkflowTransaction $transaction
  }
}

function Get-WorkflowTransactionDiagnosticErrors {
  param([Parameter(Mandatory)][string]$Root)
  $errors=New-Object System.Collections.Generic.List[string];$lockPath=Join-Path $Root '.workflow/.mutation.lock'
  if(Test-Path -LiteralPath $lockPath){$errors.Add("lifecycle mutation lock residue: $lockPath")}
  $transactionsRoot=Join-Path $Root '.workflow/.transactions'
  if(Test-Path -LiteralPath $transactionsRoot){
    try{
      foreach($transaction in @(Get-WorkflowIncompleteTransactions $Root)){$errors.Add("incomplete lifecycle transaction: $($transaction.Journal.id) ($($transaction.Journal.phase))")}
    }catch{$errors.Add($_.Exception.Message)}
  }
  return $errors.ToArray()
}

function New-WorkflowTransaction {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][ValidateSet('sync','archive')][string]$Operation,[Parameter(Mandatory)][object[]]$Items)
  if($Items.Count -eq 0){throw 'lifecycle transaction requires at least one target'}
  $id=[guid]::NewGuid().ToString('N');$transactionsRoot=Join-Path $Root '.workflow/.transactions';$path=Join-Path $transactionsRoot $id
  New-Item -ItemType Directory -Force -Path $transactionsRoot|Out-Null;New-Item -ItemType Directory -Path $path|Out-Null
  try{
    $entries=New-Object System.Collections.Generic.List[object]
    for($index=0;$index -lt $Items.Count;$index++){
      $item=$Items[$index]
      foreach($required in @('Target','Operation','Role')){if($item.PSObject.Properties.Name -notcontains $required){throw "transaction item missing $required"}}
      if("$($item.Operation)" -notin @('replace','delete')){throw "invalid transaction item operation: $($item.Operation)"}
      $relative=Get-WorkflowTransactionRelativeTarget -Root $Root -Path "$($item.Target)";$resolved=Resolve-WorkflowTransactionTarget -Root $Root -Relative $relative -Context "transaction item $index"
      $existed=Test-Path -LiteralPath $resolved.Full;$original=if($existed){"original/$index"}else{''};$prepared=if("$($item.Operation)" -eq 'replace'){"prepared/$index"}else{''}
      if($existed){Copy-WorkflowPath -Source $resolved.Full -Destination (Join-Path $path $original)}
      if($prepared){
        $hasText=$item.PSObject.Properties.Name -contains 'Text';$hasSource=$item.PSObject.Properties.Name -contains 'Source';$hasFiles=$item.PSObject.Properties.Name -contains 'Files';$kindCount=0
        if($hasText){$kindCount++};if($hasSource){$kindCount++};if($hasFiles){$kindCount++}
        if($kindCount -ne 1){throw "replace transaction item must provide exactly one of Text, Source, or Files: $relative"}
        $preparedPath=Join-Path $path $prepared
        if($hasText){if($item.Text -isnot [string]){throw "transaction item Text must be a string: $relative"};Write-WorkflowText -Path $preparedPath -Text $item.Text}
        elseif($hasSource){if(-not(Test-Path -LiteralPath "$($item.Source)")){throw "transaction item source missing: $($item.Source)"};Copy-WorkflowPath -Source "$($item.Source)" -Destination $preparedPath}
        else{
          if($item.Files -is [string] -or $item.Files -isnot [array] -or @($item.Files).Count -eq 0){throw "transaction item Files must be a non-empty array: $relative"}
          if($existed){$existing=Get-Item -LiteralPath $resolved.Full -Force;if(-not $existing.PSIsContainer){throw "transaction file set target is not a directory: $relative"};Copy-WorkflowPath -Source $resolved.Full -Destination $preparedPath}else{New-Item -ItemType Directory -Path $preparedPath|Out-Null}
          $fileNames=@{}
          foreach($file in @($item.Files)){
            foreach($requiredFileProperty in @('Relative')){if($file.PSObject.Properties.Name -notcontains $requiredFileProperty){throw "transaction file item missing ${requiredFileProperty}: $relative"}}
            $fileRelative="$($file.Relative)".Replace('\','/').Trim('/');if(-not $fileRelative -or [IO.Path]::IsPathRooted("$($file.Relative)") -or $fileRelative -match '[:*?"<>|]' -or $fileRelative -match '(^|/)\.\.?(/|$)'){throw "unsafe transaction file path: $($file.Relative)"}
            if($fileNames.ContainsKey($fileRelative)){throw "duplicate transaction file path: $fileRelative"};$fileNames[$fileRelative]=$true
            $fileTarget=[IO.Path]::GetFullPath((Join-Path $preparedPath $fileRelative.Replace('/',[IO.Path]::DirectorySeparatorChar)))
            Assert-WorkflowNoReparsePath -Root $preparedPath -Path $fileTarget -Context 'transaction prepared file'
            if(Test-Path -LiteralPath $fileTarget){Remove-WorkflowPath $fileTarget}
            $fileHasText=$file.PSObject.Properties.Name -contains 'Text';$fileHasSource=$file.PSObject.Properties.Name -contains 'Source'
            if($fileHasText -eq $fileHasSource){throw "transaction file must provide exactly one of Text or Source: $fileRelative"}
            if($fileHasText){if($file.Text -isnot [string]){throw "transaction file Text must be a string: $fileRelative"};Write-WorkflowText -Path $fileTarget -Text $file.Text}
            else{if(-not(Test-Path -LiteralPath "$($file.Source)")){throw "transaction file source missing: $($file.Source)"};Copy-WorkflowPath -Source "$($file.Source)" -Destination $fileTarget}
          }
        }
      }
      $entries.Add([ordered]@{target=$resolved.Relative;operation="$($item.Operation)";existed=[bool]$existed;original=$original;prepared=$prepared;role="$($item.Role)"})
    }
    $journal=[ordered]@{schemaVersion=1;id=$id;phase='prepared';operation=$Operation;createdAt=[DateTimeOffset]::UtcNow.ToString('o');targets=$entries.ToArray()}
    Write-WorkflowDurableText -Path (Join-Path $path 'journal.json') -Text (ConvertTo-WorkflowJson $journal)
    return Read-WorkflowTransaction -Root $Root -TransactionPath $path
  }catch{if(Test-Path -LiteralPath $path){Remove-WorkflowPath $path};throw}
}

function Set-WorkflowTransactionPhase {
  param([Parameter(Mandatory)]$Transaction,[Parameter(Mandatory)][ValidateSet('prepared','committing','committed')][string]$Phase)
  $Transaction.Journal.phase=$Phase;Write-WorkflowDurableText -Path $Transaction.JournalPath -Text (ConvertTo-WorkflowJson $Transaction.Journal)
}

function Invoke-WorkflowTransaction {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)]$Transaction)
  foreach($target in @($Transaction.Targets)){
    Assert-WorkflowNoReparsePath -Root $Root -Path $target.FullTarget -Context 'transaction commit target'
    if($target.Entry.operation -eq 'replace' -and -not(Test-Path -LiteralPath $target.PreparedPath)){throw "missing lifecycle transaction prepared value: $($target.PreparedPath)"}
  }
  $isCommitting=$false
  try{
    Set-WorkflowTransactionPhase -Transaction $Transaction -Phase committing;$isCommitting=$true;$applied=0
    foreach($target in @($Transaction.Targets)){
      Invoke-WorkflowTestFailpoint "before-$($target.Entry.role)-target"
      Remove-WorkflowPath $target.FullTarget
      if($target.Entry.operation -eq 'replace'){Copy-WorkflowPath -Source $target.PreparedPath -Destination $target.FullTarget}
      $applied++;Invoke-WorkflowTestFailpoint "after-$($target.Entry.role)-target"
      if($applied -eq 1){Invoke-WorkflowTestFailpoint 'after-first-target';Invoke-WorkflowTestFailpoint 'crash-after-first-target'}
    }
    Set-WorkflowTransactionPhase -Transaction $Transaction -Phase committed;$isCommitting=$false
    Invoke-WorkflowTestFailpoint 'crash-after-committed'
    Remove-WorkflowTransaction $Transaction
  }catch{
    $failure=$_
    if($isCommitting){
      try{Restore-WorkflowTransaction -Root $Root -Transaction $Transaction;Remove-WorkflowTransaction $Transaction}
      catch{throw "lifecycle transaction failed and rollback could not complete: $($failure.Exception.Message); rollback: $($_.Exception.Message)"}
    }
    throw $failure
  }
}

function Get-WorkflowPortableContentHash {
  param([Parameter(Mandatory)][string]$Path)
  $bytes=[IO.File]::ReadAllBytes($Path)
  $canonical=New-Object IO.MemoryStream
  try {
    for($i=0;$i -lt $bytes.Length;$i++){
      if($bytes[$i]-eq 13){if(($i+1)-lt $bytes.Length -and $bytes[$i+1]-eq 10){$i++};$canonical.WriteByte(10)}else{$canonical.WriteByte($bytes[$i])}
    }
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($canonical.ToArray()))).Replace('-','')}finally{$sha.Dispose()}
  } finally {$canonical.Dispose()}
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
  $path = Join-Path $Root '.workflow/config.json'
  if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $Root '.workflow/config.workflow.json' }
  if (-not (Test-Path -LiteralPath $path)) { throw "missing workflow config: $path" }
  try{$value=Read-WorkflowText $path|ConvertFrom-Json}catch{throw "invalid workflow config JSON: $path - $($_.Exception.Message)"}
  Assert-WorkflowObjectProperties $value @('schema','rules') "workflow config: $path"
  if($value.schema -isnot [string] -or "$($value.schema)" -notmatch '^[A-Za-z0-9._-]+$'){throw "workflow config missing valid schema: $path"}
  if($null -ne $value.rules){
    if($value.rules -is [string] -or $value.rules -is [array] -or $value.rules -is [ValueType]){throw "workflow config rules must be an object: $path"}
    foreach($property in $value.rules.PSObject.Properties){
      if($property.Name -notmatch '^[A-Za-z0-9_-]+$'){throw "workflow config invalid rule key '$($property.Name)': $path"}
      if($property.Value -is [string] -or $property.Value -isnot [array]){throw "workflow config rule '$($property.Name)' must be an array: $path"}
      foreach($item in @($property.Value)){if($item -isnot [string] -or -not $item.Trim()){throw "workflow config rule '$($property.Name)' must contain non-empty strings: $path"}}
    }
  }
  [pscustomobject]@{Path=$path;Schema="$($value.schema)";Value=$value}
}

function Get-WorkflowTextContentHash {
  param([Parameter(Mandatory)][string]$Text)
  $canonical=$Text -replace "`r`n","`n" -replace "`r","`n"
  $sha=[Security.Cryptography.SHA256]::Create()
  try{return ([BitConverter]::ToString($sha.ComputeHash(([Text.UTF8Encoding]::new($false)).GetBytes($canonical)))).Replace('-','')}finally{$sha.Dispose()}
}

function Get-WorkflowSchema {
  param([Parameter(Mandatory)][string]$Root)
  $config = Get-WorkflowConfig $Root
  $path = Join-Path $Root ".workflow/schemas/$($config.Schema)/schema.json"
  if (-not (Test-Path -LiteralPath $path)) { throw "missing workflow schema: $path" }
  try{$schema=Read-WorkflowText $path|ConvertFrom-Json}catch{throw "invalid workflow schema JSON: $path - $($_.Exception.Message)"}
  Assert-WorkflowObjectProperties $schema @('name','version','artifacts') "workflow schema: $path"
  if(-not $schema.name -or $schema.name -ne $config.Schema){throw "workflow schema name mismatch: $path"}
  $schemaVersion=0;if(-not [int]::TryParse("$($schema.version)",[ref]$schemaVersion) -or $schemaVersion -lt 1){throw "workflow schema version must be a positive integer: $path"}
  if($schema.artifacts -is [string] -or $null -eq $schema.artifacts -or @($schema.artifacts).Count -eq 0){throw "workflow schema artifacts must be a non-empty array: $path"}
  $ids=@{}
  foreach($artifact in @($schema.artifacts)){
    Assert-WorkflowObjectProperties $artifact @('id','kind','path','publishPath','required','requires','template','instruction') "workflow schema artifact: $path"
    if(-not $artifact.id -or -not $artifact.kind -or -not $artifact.path -or -not $artifact.template){throw "workflow schema artifact is incomplete: $path"}
    $publishPath=if($artifact.PSObject.Properties.Name -contains 'publishPath'){"$($artifact.publishPath)"}else{''}
    if("$($artifact.id)" -notmatch '^[A-Za-z0-9._-]+$'){throw "invalid workflow artifact id '$($artifact.id)': $path"}
    if($artifact.required -isnot [bool]){throw "workflow artifact required must be boolean: $($artifact.id)"}
    if($artifact.requires -is [string] -or $null -eq $artifact.requires -or $artifact.requires -isnot [array]){throw "workflow artifact requires must be an array: $($artifact.id)"}
    if($artifact.instruction -isnot [string] -or -not $artifact.instruction.Trim()){throw "workflow artifact instruction must be a non-empty string: $($artifact.id)"}
    if("$($artifact.kind)" -notin @('document','task-list','capability-deltas')){throw "unknown workflow artifact kind '$($artifact.kind)': $($artifact.id)"}
    if("$($artifact.kind)" -eq 'capability-deltas' -and -not $publishPath){throw "capability-deltas artifact missing publishPath: $($artifact.id)"}
    if("$($artifact.kind)" -ne 'capability-deltas' -and $publishPath){throw "publishPath is only valid for capability-deltas: $($artifact.id)"}
    if($ids.ContainsKey("$($artifact.id)")){throw "duplicate workflow artifact id: $($artifact.id)"};$ids["$($artifact.id)"]=$true
    foreach($relative in @("$($artifact.path)","$($artifact.template)",$publishPath)|Where-Object{$_}){
      $safe=$relative.Replace('\','/');if([IO.Path]::IsPathRooted($relative) -or $safe.StartsWith('/') -or $safe -match '(^|/)\.\.(/|$)'){throw "unsafe workflow schema path: $relative"}
    }
  }
  foreach($artifact in @($schema.artifacts)){foreach($dependency in @($artifact.requires)){if($dependency -isnot [string] -or -not $ids.ContainsKey("$dependency")){throw "unknown artifact dependency '$dependency' for $($artifact.id)"};if("$dependency" -eq "$($artifact.id)"){throw "workflow artifact cannot depend on itself: $($artifact.id)"}}}
  [pscustomobject]@{Path=$path;Value=$schema}
}

function Get-WorkflowArtifactTemplatePath {
  param([Parameter(Mandatory)]$Schema,[Parameter(Mandatory)]$Artifact)
  return Join-Path (Split-Path -Parent $Schema.Path) "$($Artifact.template)"
}

function Get-WorkflowArtifactErrors {
  param([Parameter(Mandatory)][string]$ChangeRoot,[Parameter(Mandatory)]$Schema,[Parameter(Mandatory)]$Artifact)
  $errors=New-Object System.Collections.Generic.List[string]
  $path=Join-Path $ChangeRoot "$($Artifact.path)"
  if("$($Artifact.kind)" -eq 'capability-deltas'){
    $pairs=@(Get-ChildItem -LiteralPath $path -Directory -ErrorAction SilentlyContinue)
    foreach($error in @(Get-WorkflowPairErrors $path)){$errors.Add($error)}
    foreach($file in @(Get-ChildItem -LiteralPath $path -Filter 'spec.md' -Recurse -File -ErrorAction SilentlyContinue)){foreach($error in @(Test-WorkflowSpecText $file.FullName -Delta)){$errors.Add($error)}}
    if([bool]$Artifact.required -and $pairs.Count -eq 0){$errors.Add("required artifact has no capability pairs: $($Artifact.id)")}
    return $errors.ToArray()
  }
  if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$errors.Add("missing change artifact: $(Split-Path -Leaf $ChangeRoot)/$($Artifact.path)");return $errors.ToArray()}
  $text=Read-WorkflowText $path
  if([string]::IsNullOrWhiteSpace($text)){$errors.Add("empty change artifact: $path");return $errors.ToArray()}
  $templatePath=Get-WorkflowArtifactTemplatePath $Schema $Artifact
  if(-not(Test-Path -LiteralPath $templatePath -PathType Leaf)){$errors.Add("missing artifact template: $templatePath");return $errors.ToArray()}
  $template=Read-WorkflowText $templatePath
  foreach($heading in @([regex]::Matches($template,'(?m)^#{1,6}\s+(?<title>.+?)\s*$')|ForEach-Object{$_.Groups['title'].Value.Trim()}|Where-Object{$_ -notmatch '<!--'})){
    $title=[regex]::Escape($heading);if($text -notmatch "(?m)^#{1,6}\s+$title\s*$"){$errors.Add("artifact missing template section '$heading': $path")}
  }
  if($text -match '<!--[^>]*(?:description|motivation|background|goal|decision|risk|condition|expected|requirement|task|capabilit)[^>]*-->' -or $text -match '<(?:name|existing-name|brief description|task description|requirement text|condition|expected outcome)>'){$errors.Add("artifact contains unresolved template placeholder: $path")}
  if("$($Artifact.kind)" -eq 'task-list'){
    $taskLines=@($text -split "`r?`n"|Where-Object{$_ -match '^- \[[ xX]\]'})
    if($taskLines.Count -eq 0){$errors.Add("tasks artifact contains no checklist tasks: $path")}
    foreach($line in $taskLines){if($line -notmatch '^- \[[ xX]\] \d+\.\d+ .+'){$errors.Add("invalid task line: $line")}}
  }
  return $errors.ToArray()
}

function Test-WorkflowArtifactPresent {
  param([Parameter(Mandatory)][string]$ChangeRoot,[Parameter(Mandatory)]$Artifact)
  $path=Join-Path $ChangeRoot "$($Artifact.path)"
  if("$($Artifact.kind)" -eq 'capability-deltas'){return (Test-Path -LiteralPath $path -PathType Container)}
  return (Test-Path -LiteralPath $path -PathType Leaf)
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

function Test-WorkflowSpecContent {
  param([Parameter(Mandatory)][string]$Text,[Parameter(Mandatory)][string]$Label,[switch]$Delta)
  $errors = New-Object System.Collections.Generic.List[string]
  if($Delta){
    $sections=@([regex]::Matches($Text,'(?ms)^## (?<op>ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*(?<body>.*?)(?=^## (?:ADDED|MODIFIED|REMOVED|RENAMED) Requirements|\z)'))
    if($sections.Count -eq 0){$errors.Add("missing delta section: $Label");return $errors.ToArray()}
    $touched=@{}
    foreach($section in $sections){
      $op=$section.Groups['op'].Value;$body=$section.Groups['body'].Value
      if($op -eq 'RENAMED'){
        $from=@([regex]::Matches($body,'(?m)^FROM:\s*(.+)$'));$to=@([regex]::Matches($body,'(?m)^TO:\s*(.+)$'))
        if($from.Count -ne 1 -or $to.Count -ne 1){$errors.Add("invalid RENAMED section: $Label");continue}
        foreach($name in @($from[0].Groups[1].Value.Trim(),$to[0].Groups[1].Value.Trim())){if($touched.ContainsKey($name)){$errors.Add("requirement has conflicting delta operations: $Label :: $name")}else{$touched[$name]='RENAMED'}}
        continue
      }
      $blocks=@(Get-WorkflowRequirementBlocks $body)
      if($blocks.Count -eq 0){$errors.Add("empty $op requirements section: $Label");continue}
      foreach($block in $blocks){
        if($touched.ContainsKey($block.Name)){$errors.Add("requirement has conflicting delta operations: $Label :: $($block.Name)")}else{$touched[$block.Name]=$op}
        if($op -eq 'REMOVED'){continue}
        $requirementBody=$block.Text.Substring($block.Text.IndexOf("`n")+1)
        if($requirementBody -notmatch '\b(SHALL|MUST)\b'){$errors.Add("requirement lacks SHALL/MUST: $Label :: $($block.Name)")}
        if($requirementBody -notmatch '(?m)^#### Scenario: '){$errors.Add("requirement lacks scenario: $Label :: $($block.Name)")}
        elseif($requirementBody -notmatch '(?m)^- \*\*WHEN\*\* ' -or $requirementBody -notmatch '(?m)^- \*\*THEN\*\* '){$errors.Add("scenario lacks WHEN/THEN: $Label :: $($block.Name)")}
      }
    }
  } else {
    $blocks=@(Get-WorkflowRequirementBlocks $Text)
    if($blocks.Count -eq 0){$errors.Add("spec contains no requirements: $Label");return $errors.ToArray()}
    $seen=@{}
    foreach($block in $blocks){
      if($seen.ContainsKey($block.Name)){$errors.Add("duplicate requirement name: $Label :: $($block.Name)")}else{$seen[$block.Name]=$true}
      $requirementBody=$block.Text.Substring($block.Text.IndexOf("`n")+1)
      if($requirementBody -notmatch '\b(SHALL|MUST)\b'){$errors.Add("requirement lacks SHALL/MUST: $Label :: $($block.Name)")}
      if($requirementBody -notmatch '(?m)^#### Scenario: '){$errors.Add("requirement lacks scenario: $Label :: $($block.Name)")}
      elseif($requirementBody -notmatch '(?m)^- \*\*WHEN\*\* ' -or $requirementBody -notmatch '(?m)^- \*\*THEN\*\* '){$errors.Add("scenario lacks WHEN/THEN: $Label :: $($block.Name)")}
    }
  }
  return $errors.ToArray()
}

function Test-WorkflowSpecText {
  param([Parameter(Mandatory)][string]$Path,[switch]$Delta)
  return @(Test-WorkflowSpecContent -Text (Read-WorkflowText $Path) -Label $Path -Delta:$Delta)
}

function Test-WorkflowChange {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Change,[switch]$RequireCompletedTasks)
  $changeRoot = Get-WorkflowChangeRoot $Root $Change
  $errors = New-Object System.Collections.Generic.List[string]
  $schema=Get-WorkflowSchema $Root
  foreach($artifact in @($schema.Value.artifacts)){
    $present=Test-WorkflowArtifactPresent -ChangeRoot $changeRoot -Artifact $artifact
    if([bool]$artifact.required -or $present){foreach($error in @(Get-WorkflowArtifactErrors -ChangeRoot $changeRoot -Schema $schema -Artifact $artifact)){$errors.Add($error)}}
  }
  if($RequireCompletedTasks){
    $tasksArtifact=@($schema.Value.artifacts|Where-Object{$_.kind -eq 'task-list'}|Select-Object -First 1)
    if($tasksArtifact.Count -eq 0){$errors.Add("schema has no task-list artifact: $($schema.Value.name)")}
    else{
      $tasksPath=Join-Path $changeRoot "$($tasksArtifact[0].path)"
      if(Test-Path -LiteralPath $tasksPath -PathType Leaf){$tasks=Read-WorkflowText $tasksPath;if($tasks -match '(?m)^- \[ \] '){$errors.Add("change has incomplete tasks: $Change")}}
    }
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
  $schemaResult=Get-WorkflowSchema $Root;$schema=$schemaResult.Value
  $complete=@{}
  foreach($artifact in @($schema.artifacts)){
    $present=Test-WorkflowArtifactPresent -ChangeRoot $changeRoot -Artifact $artifact
    $complete["$($artifact.id)"]=$present -and @(Get-WorkflowArtifactErrors -ChangeRoot $changeRoot -Schema $schemaResult -Artifact $artifact).Count -eq 0
  }
  $artifacts = New-Object System.Collections.Generic.List[object]
  foreach ($artifact in @($schema.artifacts)) {
    $id="$($artifact.id)";$missingDeps=@(@($artifact.requires)|Where-Object{-not $complete["$_"]})
    $status=if($complete[$id]){'done'}elseif($missingDeps.Count){'blocked'}elseif([bool]$artifact.required){'ready'}else{'optional'}
    $artifacts.Add([pscustomobject]@{id=$id;path=$artifact.path;status=$status;required=[bool]$artifact.required;missingDeps=$missingDeps})
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

function Get-WorkflowMergedDeltaSpecText {
  param([Parameter(Mandatory)][string]$DeltaPath,[Parameter(Mandatory)][string]$MainPath,[Parameter(Mandatory)][string]$Capability,[switch]$AllowRenameReplay)
  $delta = Read-WorkflowText $DeltaPath
  $main = if (Test-Path -LiteralPath $MainPath) { Read-WorkflowText $MainPath } else { "# $Capability Specification`n`n## Purpose`n`nDefine the accepted $Capability behavior.`n" }
  $introMatch = [regex]::Match($main, '(?s)\A.*?(?=^### Requirement: |\z)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
  $intro = $introMatch.Value.TrimEnd()
  $order = New-Object System.Collections.Generic.List[string]
  $map = @{}
  foreach ($block in @(Get-WorkflowRequirementBlocks $main)) {if($map.ContainsKey($block.Name)){throw "duplicate requirement name in accepted spec: $($block.Name)"};$order.Add($block.Name);$map[$block.Name]=$block.Text }
  foreach ($section in [regex]::Matches($delta, '(?ms)^## (?<op>ADDED|MODIFIED|REMOVED|RENAMED) Requirements\s*(?<body>.*?)(?=^## (?:ADDED|MODIFIED|REMOVED|RENAMED) Requirements|\z)')) {
    $op=$section.Groups['op'].Value; $body=$section.Groups['body'].Value
    if ($op -eq 'RENAMED') {
      $from=[regex]::Match($body,'(?m)^FROM:\s*(.+)$');$to=[regex]::Match($body,'(?m)^TO:\s*(.+)$')
      if(-not $from.Success -or -not $to.Success){throw "invalid RENAMED section: $DeltaPath"}
      $old=$from.Groups[1].Value.Trim();$new=$to.Groups[1].Value.Trim();if(-not $map.ContainsKey($old)){if($AllowRenameReplay -and $map.ContainsKey($new)){continue};throw "rename source missing or replay is not equivalent: $old"};if($map.ContainsKey($new)){throw "rename target already exists: $new"}
      $map[$new]=[regex]::Replace($map[$old],'^### Requirement: .+$',"### Requirement: $new",[System.Text.RegularExpressions.RegexOptions]::Multiline);$map.Remove($old)
      $index=$order.IndexOf($old);$order[$index]=$new;continue
    }
    foreach($block in @(Get-WorkflowRequirementBlocks $body)){
      if($op -eq 'ADDED') { if($map.ContainsKey($block.Name)){if((($map[$block.Name] -replace "`r`n","`n").Trim()) -eq (($block.Text -replace "`r`n","`n").Trim())){continue};throw "added requirement already exists: $($block.Name)"};$order.Add($block.Name);$map[$block.Name]=$block.Text }
      elseif($op -eq 'MODIFIED') { if(-not $map.ContainsKey($block.Name)){throw "modified requirement missing: $($block.Name)"};$map[$block.Name]=$block.Text }
      elseif($op -eq 'REMOVED') { if($map.ContainsKey($block.Name)){$map.Remove($block.Name);$order.Remove($block.Name)|Out-Null} }
    }
  }
  $parts=New-Object System.Collections.Generic.List[string];$parts.Add($intro);foreach($name in $order){if($map.ContainsKey($name)){$parts.Add($map[$name])}}
  return (($parts -join "`n`n").TrimEnd()+"`n")
}

function Get-WorkflowSyncPlan {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Change)
  $validation=Test-WorkflowChange $Root $Change;if(-not $validation.Valid){throw ($validation.Errors -join "`n")}
  $receiptPath=Join-Path $validation.Path '.sync.json';$receiptEntries=@{}
  if(Test-Path -LiteralPath $receiptPath -PathType Leaf){
    try{$receipt=Read-WorkflowText $receiptPath|ConvertFrom-Json;Assert-WorkflowObjectProperties $receipt @('schemaVersion','capabilities') 'sync receipt';if($receipt.schemaVersion -ne 1){throw 'sync receipt schemaVersion must be 1'};if($null -eq $receipt.capabilities -or $receipt.capabilities -is [string] -or $receipt.capabilities -is [array] -or $receipt.capabilities -is [ValueType]){throw 'sync receipt capabilities must be an object'};foreach($property in $receipt.capabilities.PSObject.Properties){Assert-WorkflowObjectProperties $property.Value @('specSha256') "sync receipt capability '$($property.Name)'";if("$($property.Value.specSha256)" -notmatch '^[A-Fa-f0-9]{64}$'){throw "sync receipt contains invalid hash: $($property.Name)"};$receiptEntries[$property.Name]="$($property.Value.specSha256)"}}catch{throw "invalid sync receipt: $($_.Exception.Message)"}
  }
  $schema=Get-WorkflowSchema $Root;$prepared=New-Object System.Collections.Generic.List[object];$items=New-Object System.Collections.Generic.List[object];$capabilities=@{}
  foreach($deltaArtifact in @($schema.Value.artifacts|Where-Object{$_.kind -eq 'capability-deltas'})){
    $changeSpecs=Join-Path $validation.Path "$($deltaArtifact.path)";$mainSpecs=Join-Path $Root "$($deltaArtifact.publishPath)"
    foreach($cap in @(Get-ChildItem -LiteralPath $changeSpecs -Directory -ErrorAction SilentlyContinue)){
      if($capabilities.ContainsKey($cap.Name)){throw "capability appears in multiple delta artifacts: $($cap.Name)"};$capabilities[$cap.Name]=$true
      $dest=Join-Path $mainSpecs $cap.Name;$specPath=Join-Path $dest 'spec.md';$designSource=Join-Path $cap.FullName 'design.md'
      $allowRenameReplay=$receiptEntries.ContainsKey($cap.Name) -and (Test-Path -LiteralPath $specPath -PathType Leaf) -and (Get-WorkflowPortableContentHash $specPath) -eq $receiptEntries[$cap.Name]
      $merged=Get-WorkflowMergedDeltaSpecText (Join-Path $cap.FullName 'spec.md') $specPath $cap.Name -AllowRenameReplay:$allowRenameReplay
      $specErrors=@(Test-WorkflowSpecContent -Text $merged -Label $specPath)
      if($specErrors.Count){throw ($specErrors -join "`n")}
      if(-not(Test-Path -LiteralPath $designSource -PathType Leaf)){throw "missing capability companion: $designSource"}
      $prepared.Add([pscustomobject]@{Name=$cap.Name;Destination=$dest;SpecPath=$specPath;SpecText=$merged;DesignSource=$designSource})
      $files=@(
        [pscustomobject]@{Relative='spec.md';Text=$merged},
        [pscustomobject]@{Relative='design.md';Source=$designSource}
      )
      $items.Add([pscustomobject]@{Target=$dest;Operation='replace';Role='capability';Files=$files})
    }
  }
  $receiptText=$null
  if($prepared.Count){
    $saved=[ordered]@{};foreach($item in $prepared){$saved[$item.Name]=[ordered]@{specSha256=(Get-WorkflowTextContentHash $item.SpecText)}}
    $receiptText=ConvertTo-WorkflowJson ([ordered]@{schemaVersion=1;capabilities=$saved})
    $items.Add([pscustomobject]@{Target=$receiptPath;Operation='replace';Role='receipt';Text=$receiptText})
  }
  return [pscustomobject]@{ChangeRoot=$validation.Path;Names=@($prepared.Name);Items=$items.ToArray();ReceiptPath=$receiptPath;ReceiptText=$receiptText}
}

function Sync-WorkflowChange {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Change)
  $lock=Enter-WorkflowMutationLock $Root
  try{
    Repair-WorkflowIncompleteTransactions $Root
    $plan=Get-WorkflowSyncPlan -Root $Root -Change $Change
    if(@($plan.Items).Count){$transaction=New-WorkflowTransaction -Root $Root -Operation sync -Items @($plan.Items);Invoke-WorkflowTransaction -Root $Root -Transaction $transaction}
    return @($plan.Names)
  }finally{Exit-WorkflowMutationLock $lock}
}

function Archive-WorkflowChange {
  param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Change)
  $lock=Enter-WorkflowMutationLock $Root
  try{
    Repair-WorkflowIncompleteTransactions $Root
    $validation=Test-WorkflowChange $Root $Change -RequireCompletedTasks;if(-not $validation.Valid){throw ($validation.Errors -join "`n")}
    $archiveRoot=Join-Path $Root '.workflow/changes/archive';$archiveName="$(Get-Date -Format 'yyyy-MM-dd')-$Change";$destination=Join-Path $archiveRoot $archiveName
    if(Test-Path -LiteralPath $destination){throw "archive already exists: $archiveName"}
    $plan=Get-WorkflowSyncPlan -Root $Root -Change $Change
    $temporary=Join-Path ([IO.Path]::GetTempPath()) ('workflow-archive-'+[guid]::NewGuid().ToString('N'))
    try{
      Copy-WorkflowPath -Source $validation.Path -Destination $temporary
      if($null -ne $plan.ReceiptText){Write-WorkflowText -Path (Join-Path $temporary '.sync.json') -Text $plan.ReceiptText}
      $items=New-Object System.Collections.Generic.List[object]
      foreach($item in @($plan.Items|Where-Object{$_.Role -ne 'receipt'})){$items.Add($item)}
      $items.Add([pscustomobject]@{Target=$destination;Operation='replace';Role='archive';Source=$temporary})
      $items.Add([pscustomobject]@{Target=$validation.Path;Operation='delete';Role='active-change'})
      $transaction=New-WorkflowTransaction -Root $Root -Operation archive -Items $items.ToArray()
      Invoke-WorkflowTransaction -Root $Root -Transaction $transaction
    }finally{if(Test-Path -LiteralPath $temporary){Remove-WorkflowPath $temporary}}
    return [pscustomobject]@{change=$Change;archived=$true;archivedAs=$archiveName;path=$destination;updated=@($plan.Names)}
  }finally{Exit-WorkflowMutationLock $lock}
}

function Get-WorkflowArtifactIntegrityErrors {
  param([Parameter(Mandatory)][string]$Root)
  $errors=New-Object System.Collections.Generic.List[string]
  $skill=Join-Path $Root '.agents/skills/workflow';$metaPath=Join-Path $skill 'artifact.json';$manifestPath=Join-Path $skill 'artifact-manifest.json'
  foreach($required in @($metaPath,$manifestPath, (Join-Path $skill 'bin/workflow.ps1'), (Join-Path $skill 'bin/WorkflowRuntime.psm1'))){if(-not(Test-Path -LiteralPath $required -PathType Leaf)){$errors.Add("missing published artifact file: $required")}}
  if($errors.Count){return $errors.ToArray()}
  try{$meta=Read-WorkflowText $metaPath|ConvertFrom-Json;Assert-WorkflowObjectProperties $meta @('schemaVersion','name','version','contracts','cli') 'artifact metadata'}catch{$errors.Add("invalid artifact metadata: $($_.Exception.Message)");return $errors.ToArray()}
  try{$manifest=Read-WorkflowText $manifestPath|ConvertFrom-Json;Assert-WorkflowObjectProperties $manifest @('schemaVersion','version','files') 'artifact manifest'}catch{$errors.Add("invalid artifact manifest: $($_.Exception.Message)");return $errors.ToArray()}
  if($meta.schemaVersion -ne 1){$errors.Add("artifact metadata schemaVersion drift: $($meta.schemaVersion)")}
  if($meta.name -ne 'workflow'){$errors.Add("artifact name drift: $($meta.name)")}
  if($meta.contracts -ne 'references'){$errors.Add("artifact contracts path drift: $($meta.contracts)")}
  if($meta.cli -ne 'bin/workflow.ps1'){$errors.Add("artifact CLI path drift: $($meta.cli)")}
  if($manifest.schemaVersion -ne 1){$errors.Add("artifact manifest schemaVersion drift: $($manifest.schemaVersion)")}
  if($meta.version -ne $manifest.version){$errors.Add("artifact metadata version mismatch: $($meta.version) != $($manifest.version)")}
  if($manifest.files -is [string] -or $null -eq $manifest.files -or @($manifest.files).Count -eq 0){$errors.Add('artifact manifest files must be a non-empty array');return $errors.ToArray()}
  $expected=@{};foreach($entry in @($manifest.files)){
    try{Assert-WorkflowObjectProperties $entry @('path','sha256') 'artifact manifest entry'}catch{$errors.Add($_.Exception.Message);continue}
    $rel="$($entry.path)".Replace('\','/');if(-not $rel -or [IO.Path]::IsPathRooted("$($entry.path)") -or $rel.StartsWith('/') -or $rel -match '(^|/)\.\.(/|$)'){$errors.Add("unsafe artifact manifest path: $rel");continue}
    if($expected.ContainsKey($rel)){$errors.Add("duplicate artifact manifest path: $rel");continue};if("$($entry.sha256)" -notmatch '^[A-Fa-f0-9]{64}$'){$errors.Add("invalid artifact manifest hash: $rel");continue};$expected[$rel]="$($entry.sha256)"
    $path=Join-Path $skill $rel;if(-not(Test-Path -LiteralPath $path -PathType Leaf)){$errors.Add("artifact file missing: $rel")}elseif((Get-WorkflowPortableContentHash $path)-ne $expected[$rel]){$errors.Add("artifact content drift: $rel")}
  }
  $actual=@(Get-ChildItem -LiteralPath $skill -Recurse -File|Where-Object{$_.Name -notin @('artifact.json','artifact-manifest.json')}|ForEach-Object{$_.FullName.Substring($skill.Length+1).Replace('\','/')})
  foreach($rel in $actual){if(-not $expected.ContainsKey($rel)){$errors.Add("unmanifested artifact file: $rel")}}
  return $errors.ToArray()
}

function Invoke-RepositoryWorkflow {
  param([Parameter(Mandatory)][string]$Command,[string[]]$Arguments=@(),[Parameter(Mandatory)][string]$ProjectRoot)
  $root=Resolve-RepositoryWorkflowRoot $ProjectRoot;$json=Test-WorkflowSwitch $Arguments '--json';$change=Get-WorkflowOption $Arguments '--change'
  switch($Command.ToLowerInvariant()){
    'new' {
      $positionals=@(Get-WorkflowPositionals $Arguments);if($positionals.Count -lt 1){throw 'usage: workflow.ps1 new <change> [--json]'};$name=$positionals[0]
      if($name -notmatch '^[a-z0-9][a-z0-9-]*$'){throw "invalid change name: $name"};$dir=Join-Path $root ".workflow/changes/$name";if(Test-Path $dir){throw "change already exists: $name"}
      $schema=Get-WorkflowSchema $root;$initial=@($schema.Value.artifacts|Where-Object{[bool]$_.required -and @($_.requires).Count -eq 0}|Select-Object -First 1);if($initial.Count -eq 0){throw "schema has no initial required artifact: $($schema.Value.name)"}
      $artifact=$initial[0];if("$($artifact.kind)" -eq 'capability-deltas' -or "$($artifact.path)" -match '[*?]' -or "$($artifact.path)".EndsWith('/')){throw "initial artifact must be a file artifact: $($artifact.path)"}
      $template=Get-WorkflowArtifactTemplatePath $schema $artifact;if(-not(Test-Path -LiteralPath $template -PathType Leaf)){throw "missing artifact template: $template"}
      $destination=Join-Path $dir "$($artifact.path)";New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination)|Out-Null;Copy-Item -LiteralPath $template -Destination $destination
      $value=[pscustomobject]@{change=$name;path=$dir;schema=$schema.Value.name;next=$artifact.id}
    }
    'status' { $value=Get-WorkflowStatus $root $change }
    'instructions' {
      $positionals=@(Get-WorkflowPositionals $Arguments);if($positionals.Count -lt 1){throw 'usage: workflow.ps1 instructions <artifact> --change <name> [--json]'};$artifactId=$positionals[0]
      if(-not $change){throw 'instructions requires --change'};$null=Get-WorkflowChangeRoot $root $change;$schema=Get-WorkflowSchema $root;$artifact=@($schema.Value.artifacts|Where-Object{$_.id -eq $artifactId})|Select-Object -First 1;if(-not $artifact){throw "unknown artifact: $artifactId"}
      $templatePath=Join-Path (Split-Path -Parent $schema.Path) $artifact.template;$value=[pscustomobject]@{change=$change;artifact=$artifactId;path=$artifact.path;requires=@($artifact.requires);instruction=$artifact.instruction;template=(Read-WorkflowText $templatePath)}
    }
    'validate' {
      if(-not $change){$positionals=@(Get-WorkflowPositionals $Arguments);if($positionals.Count){$change=$positionals[0]}}
      if($change){$value=Test-WorkflowChange $root $change}else{$specRoot=Join-Path $root '.workflow/specs';$errors=New-Object System.Collections.Generic.List[string];foreach($error in @(Get-WorkflowPairErrors $specRoot)){$errors.Add($error)};foreach($file in @(Get-ChildItem -LiteralPath $specRoot -Filter 'spec.md' -Recurse -File -ErrorAction SilentlyContinue)){foreach($error in @(Test-WorkflowSpecText $file.FullName)){$errors.Add($error)}};$value=[pscustomobject]@{Valid=($errors.Count -eq 0);Errors=$errors.ToArray();Path=$specRoot}}
      if(-not $value.Valid -and -not $json){throw ($value.Errors -join "`n")}
    }
    'sync' { if(-not $change){throw 'sync requires --change'};$value=[pscustomobject]@{change=$change;updated=@(Sync-WorkflowChange $root $change)} }
    'archive' {
      if(-not $change){$positionals=@(Get-WorkflowPositionals $Arguments);if($positionals.Count){$change=$positionals[0]}};if(-not $change){throw 'archive requires a change name'}
      $value=Archive-WorkflowChange $root $change
    }
    'doctor' {
      $errors=New-Object System.Collections.Generic.List[string];try{$null=Get-WorkflowSchema $root}catch{$errors.Add($_.Exception.Message)};foreach($e in @(Get-WorkflowPairErrors (Join-Path $root '.workflow/specs'))){$errors.Add($e)}
      foreach($file in @(Get-ChildItem -LiteralPath (Join-Path $root '.workflow/specs') -Filter 'spec.md' -Recurse -File -ErrorAction SilentlyContinue)){foreach($e in @(Test-WorkflowSpecText $file.FullName)){$errors.Add($e)}}
      foreach($e in @(Get-WorkflowArtifactIntegrityErrors $root)){$errors.Add($e)}
      foreach($e in @(Get-WorkflowTransactionDiagnosticErrors $root)){$errors.Add($e)}
      $value=[pscustomobject]@{Valid=($errors.Count -eq 0);Errors=$errors.ToArray();Root=$root};if(-not $value.Valid -and -not $json){throw ($value.Errors -join "`n")}
    }
    'help' { return 'workflow commands: new, status, instructions, validate, sync, archive, doctor' }
    default { throw "unknown workflow command: $Command" }
  }
  if($json){return (ConvertTo-WorkflowJson $value)}
  return $value
}

Export-ModuleMember -Function @('Invoke-RepositoryWorkflow','Resolve-RepositoryWorkflowRoot','Get-WorkflowStatus','Test-WorkflowChange','Sync-WorkflowChange')
