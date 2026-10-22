#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not ('LmsUnpacker.ZipIntegrity' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'ZipIntegrity.cs') }

function Assert-PlainPath([string]$Path) {
    $cursor = [IO.Path]::GetFullPath($Path)
    $target = $cursor
    while ($cursor) {
        try {
            $attributes = [IO.File]::GetAttributes($cursor)
            if ($attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Links/junctions are not supported: $cursor" }
            if ($cursor -ne $target -and -not ($attributes -band [IO.FileAttributes]::Directory)) { throw "A file blocks a folder: $cursor" }
        } catch [IO.FileNotFoundException] { }
        catch [IO.DirectoryNotFoundException] { }
        $parent = [IO.Path]::GetDirectoryName($cursor)
        if ($parent -eq $cursor) { break }
        $cursor = $parent
    }
}

function Get-SafeRelativePath([string]$Name) {
    $normalized = $Name.Replace('\','/').TrimEnd('/')
    if (-not $normalized -or $normalized.StartsWith('/')) { throw "Unsafe archive/rule path: $Name" }
    foreach ($part in $normalized.Split('/')) {
        if (-not $part -or $part -in @('.','..') -or $part -match '[<>:"|?*\x00-\x1f]' -or
            $part -match '[. ]$' -or $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') {
            throw "Unsupported archive/rule path: $Name"
        }
    }
    return $normalized.Replace('/',[IO.Path]::DirectorySeparatorChar)
}

function Get-ContainedPath([string]$Root, [string]$Relative) {
    $safe = Get-SafeRelativePath $Relative
    $base = [IO.Path]::GetFullPath($Root).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $target = [IO.Path]::GetFullPath((Join-Path $base $safe))
    if (-not $target.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)) { throw "Path escapes destination: $Relative" }
    Assert-PlainPath $target
    return $target
}

function Read-LmsRules([string]$Path) {
    if (-not $Path) { return [pscustomobject]@{Version=1; Courses=@(); Rules=@(); RuleCache=@{}} }
    $config = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($config.Version -ne 1) { throw 'Rules Version must be 1.' }
    if (-not $config.PSObject.Properties['Courses']) { $config | Add-Member NoteProperty Courses @() }
    $codes = @{}
    $folders = @{}
    foreach ($course in $config.Courses) {
        if ($course.Code -notmatch '^[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*$') { throw 'Course codes may contain letters, numbers and hyphens.' }
        $safe = Get-SafeRelativePath $course.Folder
        if ($safe -match '[/\\]' -or $safe.StartsWith('.')) { throw 'Course Folder must be a single, visible folder name.' }
        if ($codes.ContainsKey($course.Code) -or $folders.ContainsKey($course.Folder)) { throw 'Course codes and folders must be unique.' }
        $codes[$course.Code] = $true
        $folders[$course.Folder] = $true
    }
    foreach ($rule in $config.Rules) {
        if (-not $rule.Course -or -not $rule.Pattern -or -not $rule.Folder) { throw 'Each rule needs Course, Pattern, and Folder.' }
        $null = Get-SafeRelativePath $rule.Folder
        if ($rule.PSObject.Properties['Topic'] -and $rule.Topic) {
            $topic = Get-SafeRelativePath $rule.Topic
            if ($topic -match '[/\\]') { throw 'A rule Topic must be a single folder name.' }
        }
        $rule | Add-Member NoteProperty Matcher ([Management.Automation.WildcardPattern]::new($rule.Pattern, 'IgnoreCase')) -Force
        $rule | Add-Member NoteProperty CourseMatcher ([Management.Automation.WildcardPattern]::new($rule.Course, 'IgnoreCase')) -Force
        # Support ordinary LMS space/underscore/hyphen variants without changing wildcard character classes.
        $normalized = if ($rule.Pattern -notmatch '\[') { [Management.Automation.WildcardPattern]::new(($rule.Pattern -replace '[_\s-]+',' '), 'IgnoreCase') } else { $null }
        $rule | Add-Member NoteProperty NormalizedMatcher $normalized -Force
    }
    $config.Courses = @($config.Courses | Sort-Object { $_.Code.Length } -Descending)
    $config | Add-Member NoteProperty RuleCache @{} -Force
    return $config
}

function Get-LmsCourse([string]$Text, [object[]]$Courses) {
    foreach ($course in $Courses) {
        if ($Text -eq $course.Folder -or $Text -match ('^(?i:' + [regex]::Escape($course.Code) + ')(?:[^a-zA-Z0-9]|$)')) { return $course }
    }
    return $null
}

function Get-LmsCategory([string]$Name) {
    $stem = [IO.Path]::GetFileNameWithoutExtension($Name).Replace('_',' ').Replace('-',' ')
    if ($stem -match '(?i)\b(submission|student copy|evidence)\b') { return $null }
    if ($stem -match '(?i)\b(course outline|syllab(us|i)|course schedule)\b') { return 'Course Info' }
    if ($stem -match '(?i)\b(assignment|homework)\b') { return 'Assignments' }
    if ($stem -match '(?i)\b(quiz|quizzes|exam|midterm|past paper)\b') { return 'Quizzes and Exams' }
    if ($stem -match '(?i)\b(book|textbook|edition|\d+(st|nd|rd|th) ed|\d+ed)\b') { return 'Books' }
    if ($stem -match '(?i)\blab(?:oratory)?\s*0*(\d+)\b') { return ('Labs/Lab {0:D2}' -f [int]$Matches[1]) }
    if ($stem -match '(?i)\b(practice|sample questions|problem sheet|exercises)\b') { return 'Practice' }
    if ($stem -match '(?i)\bweek\s*0*(\d+)\b') { return ('Lectures/Week {0:D2}' -f [int]$Matches[1]) }
    if ($stem -match '(?i)\b(lecture|lec)\s*\d*') { return 'Lectures' }
    return $null
}

function Get-FileDigest([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

function Get-LmsClassification([string]$Name, [string]$Course, $Profile, [string]$GroupBy, [string]$Context) {
    if (-not $Profile.RuleCache.ContainsKey($Course)) {
        $Profile.RuleCache[$Course] = @($Profile.Rules | Where-Object { $_.CourseMatcher.IsMatch($Course) })
    }
    $match = $null
    $normalizedName = $Name -replace '[_\s-]+',' '
    foreach ($rule in $Profile.RuleCache[$Course]) {
        if ($rule.Matcher.IsMatch($Name) -or ($rule.NormalizedMatcher -and $rule.NormalizedMatcher.IsMatch($normalizedName))) { $match = $rule; break }
    }
    $category = $null
    $topic = $null
    $reason = 'No matching filename or syllabus rule; unchanged.'
    if ($match) {
        $category = $match.Folder
        $reason = 'Profile rule: ' + $match.Pattern
        if ($match.PSObject.Properties['Reason'] -and $match.Reason) { $reason += ' - ' + $match.Reason }
        if ($match.PSObject.Properties['Topic']) { $topic = $match.Topic }
    } else {
        $category = Get-LmsCategory $Name
        if ($category) { $reason = 'Recognized from the filename.' }
    }
    # LMS section names can provide a week when the filename does not.
    $protected = -not $category -and $Name -match '(?i)(submission|student[ _-]+copy|evidence)'
    if (-not $protected -and ($null -eq $category -or $category -eq 'Lectures') -and
        $Context -match '(?i)(?:^|[/\\ ])week[ _-]*0*(\d{1,2})(?:\b|_)') {
        $category = 'Lectures/Week {0:D2}' -f [int]$Matches[1]
        $reason = 'Explicit week label in the filename or LMS folder.'
    }
    if ($category -match '^Lectures(?:[/\\]|$)') {
        if ($GroupBy -eq 'Category') { $category = 'Lectures' }
        elseif ($GroupBy -eq 'Topic') {
            if ($topic) { $category = 'Lectures/' + $topic }
            else { $category = 'Lectures/Unsorted topics'; $reason += ' No topic rule is available.' }
        } elseif ($category -eq 'Lectures') {
            $category = 'Lectures/Unscheduled'
            $reason += ' No reliable week is available.'
        }
    }
    return [pscustomobject]@{Folder=$category; Topic=$topic; Reason=$reason}
}

function Get-LmsTarget([string]$Target, [string]$Hash, [string]$Conflict, [hashtable]$Planned) {
    $candidate = $Target
    $number = 0
    while ($true) {
        Assert-PlainPath $candidate
        $exists = Test-Path -LiteralPath $candidate
        if ($exists -and -not (Test-Path -LiteralPath $candidate -PathType Leaf)) { throw "A folder blocks a file: $candidate" }
        if (-not $exists -and -not $Planned.ContainsKey($candidate)) {
            $Planned[$candidate] = $Hash
            return [pscustomobject]@{Path=$candidate; Action='Write'}
        }
        $existingHash = if ($Planned.ContainsKey($candidate)) { $Planned[$candidate] } else { Get-FileDigest $candidate }
        if ($existingHash.StartsWith('preview-source:')) {
            $existingHash = Get-FileDigest $existingHash.Substring(15)
            $Planned[$candidate] = $existingHash
        }
        if ($existingHash -eq $Hash) { return [pscustomobject]@{Path=$candidate; Action='Duplicate'} }
        if ($Conflict -eq 'Skip') { return [pscustomobject]@{Path=$candidate; Action='Skip'} }
        if ($Conflict -eq 'Overwrite') {
            $Planned[$candidate] = $Hash
            return [pscustomobject]@{Path=$candidate; Action='Overwrite'}
        }
        $number++
        $candidate = Join-Path ([IO.Path]::GetDirectoryName($Target)) ('{0}_{1}{2}' -f [IO.Path]::GetFileNameWithoutExtension($Target), $number, [IO.Path]::GetExtension($Target))
    }
}

function Copy-LmsEntry($Entry, [string]$OutputPath, [uint32]$Crc) {
    $inputStream = $Entry.Open()
    $outputStream = $null
    try {
        if ($OutputPath) { $outputStream = [IO.File]::Open($OutputPath, 'CreateNew', 'Write', 'None') }
        return [LmsUnpacker.ZipIntegrity]::CopyChecked($inputStream,$outputStream,$Entry.Length,$Crc)
    } finally {
        $inputStream.Dispose()
        if ($outputStream) { $outputStream.Dispose() }
    }
}

function Replace-LmsFile([string]$Source, [string]$Target) {
    # Indexers/virus scanners can briefly hold a destination without delete sharing.
    # Keep the staged source intact and retry only bounded I/O failures.
    for ($attempt = 0; $attempt -le 4; $attempt++) {
        Assert-PlainPath $Source
        Assert-PlainPath $Target
        try {
            [IO.File]::Replace($Source,$Target,[NullString]::Value)
            return
        } catch [IO.IOException] {
            if ($attempt -eq 4 -or -not [IO.File]::Exists($Source)) { throw }
            Start-Sleep -Milliseconds (100 * [math]::Pow(2,$attempt))
        }
    }
}

function Install-LmsFile([string]$Source, [string]$Target, [bool]$Replace) {
    Assert-PlainPath $Target
    $parent = [IO.Path]::GetDirectoryName($Target)
    $null = [IO.Directory]::CreateDirectory($parent)
    $temporary = Join-Path $parent ('.lms-write-' + [guid]::NewGuid().ToString('N'))
    try {
        [IO.File]::Copy($Source,$temporary,$false)
        if ($Replace -and [IO.File]::Exists($Target)) { Replace-LmsFile $temporary $Target }
        else { [IO.File]::Move($temporary,$Target) }
    } finally {
        if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) }
    }
}

function Invoke-LmsArchive($Zip, $Options, $Profile, [hashtable]$Planned) {
    $archive = $null
    $scratch = $null
    $items = New-Object 'Collections.Generic.List[object]'
    try {
        $courseRoot = $Zip.DirectoryName
        if ($Options.OutputPath) { $courseRoot = $Options.OutputPath }
        $courseName = $Zip.Directory.Name
        if ($Options.Mode -eq 'Organize') {
            $course = Get-LmsCourse $Zip.BaseName $Profile.Courses
            $parentCourse = Get-LmsCourse $Zip.Directory.Name $Profile.Courses
            if ($course) {
                if ($parentCourse -and $parentCourse.Code -ne $course.Code) { throw 'ZIP course code conflicts with its containing course folder.' }
                if ($Options.OutputPath) { $courseRoot = Get-ContainedPath $Options.OutputPath $course.Folder }
                elseif (-not $parentCourse) { $courseRoot = Get-ContainedPath $Options.Root $course.Folder }
                $courseName = $course.Code
            } elseif ($parentCourse) {
                $courseName = $parentCourse.Code
                if ($Options.OutputPath) { $courseRoot = Get-ContainedPath $Options.OutputPath $parentCourse.Folder }
            }
        }
        Assert-PlainPath $Zip.FullName
        $checksums = [LmsUnpacker.ZipIntegrity]::ReadChecksums($Zip.FullName,$Options.MaxEntries)
        $archive = [IO.Compression.ZipFile]::OpenRead($Zip.FullName)
        if ($checksums.Length -ne $archive.Entries.Count) { throw 'Archive entry count does not match its directory.' }
        if ($archive.Entries.Count -gt $Options.MaxEntries) { throw "Archive exceeds $($Options.MaxEntries) entries." }
        [long]$total = 0
        foreach ($entry in $archive.Entries) {
            $relative = Get-SafeRelativePath $entry.FullName
            $unixType = (($entry.ExternalAttributes -shr 16) -band 0xF000)
            if ($unixType -ne 0 -and $unixType -ne 0x8000 -and $unixType -ne 0x4000) { throw "Unsupported special entry: $relative" }
            $total += $entry.Length
            if ($total -gt $Options.MaxExpandedBytes) { throw 'Archive exceeds the expanded size limit.' }
        }
        if (-not $Options.Preview) {
            $scratch = Join-Path ([IO.Path]::GetTempPath()) ('lms-unpack-' + [guid]::NewGuid().ToString('N'))
            $null = [IO.Directory]::CreateDirectory($scratch)
        }
        $entryIndex = -1
        foreach ($entry in $archive.Entries) {
            $entryIndex++
            if ($Options.Control.CancelRequested) { throw [OperationCanceledException]::new('Cancelled before archive publication; ZIP retained.') }
            $Options.Control.Current = $entry.FullName
            $Options.Control.Completed = $entryIndex
            $Options.Control.Total = $archive.Entries.Count
            $Options.Control.Phase = 'Reading archive'
            $relative = Get-SafeRelativePath $entry.FullName
            $isDirectory = $entry.FullName.EndsWith('/') -or $entry.FullName.EndsWith('\')
            if ($isDirectory -and ($entry.Length -ne 0 -or $checksums[$entryIndex] -ne 0)) { throw 'Directory entry contains unexpected data.' }
            $root = $courseRoot
            $reason = 'Original archive structure.'
            if ($Options.Mode -eq 'Extract') {
                $root = Get-ContainedPath $root $Zip.BaseName
                $target = Get-ContainedPath $root $relative
            } else {
                if ($isDirectory) { continue }
                $name = [IO.Path]::GetFileName($relative)
                $reason = 'Flattened archive entry.'
                if ($Options.Mode -eq 'Organize') {
                    $classification = Get-LmsClassification $name $courseName $Profile $Options.GroupBy $relative
                    $reason = $classification.Reason
                    if ($classification.Folder) { $root = Get-ContainedPath $root $classification.Folder }
                    else { $reason = 'Unclassified archive entry; extracted beside the ZIP.' }
                }
                $target = Get-ContainedPath $root $name
            }
            if ($target -eq $Zip.FullName -or $Options.Sources.ContainsKey($target)) { throw "Output would replace an input archive: $target" }
            if ($isDirectory) {
                if (Test-Path -LiteralPath $target -PathType Leaf) { throw "A file blocks a folder: $target" }
                $items.Add([pscustomobject]@{Path=$target; Action='Directory'; Stage=$null; Source=$relative; Reason=$reason})
                continue
            }
            $stage = if ($scratch) { Join-Path $scratch ($items.Count.ToString() + '.data') } else { $null }
            $hash = Copy-LmsEntry $entry $stage $checksums[$entryIndex]
            $decision = Get-LmsTarget $target $hash $Options.Conflict $Planned
            $items.Add([pscustomobject]@{Path=$decision.Path; Action=$decision.Action; Stage=$stage; Source=$relative; Reason=$reason; Course=$courseName})
        }
        $filePaths = @{}
        foreach ($item in $items) { if ($item.Action -ne 'Directory') { $filePaths[$item.Path] = $true } }
        foreach ($item in $items) {
            $parent = if ($item.Action -eq 'Directory') { $item.Path } else { [IO.Path]::GetDirectoryName($item.Path) }
            while ($parent) {
                if ($filePaths.ContainsKey($parent) -or (Test-Path -LiteralPath $parent -PathType Leaf)) { throw "A file blocks a folder: $parent" }
                $parent = [IO.Path]::GetDirectoryName($parent)
            }
        }
        if ($Options.Control.CancelRequested) { throw [OperationCanceledException]::new('Cancelled before archive publication; ZIP retained.') }
        $Options.Control.Phase = 'Finishing archive safely'
        foreach ($item in $items) {
            Write-Host "  [$($item.Action)] $($item.Path)"
            if ($Options.Mode -eq 'Organize' -and $item.Action -ne 'Directory') { Write-Host "    Why: $($item.Reason)" }
            if (-not $Options.Preview) {
                if ($item.Action -eq 'Directory') { $null = [IO.Directory]::CreateDirectory($item.Path) }
                elseif ($item.Action -in @('Write','Overwrite')) { Install-LmsFile $item.Stage $item.Path ($item.Action -eq 'Overwrite') }
            }
        }
        $archive.Dispose()
        $archive = $null
        if (-not $Options.KeepZip) {
            if (-not $Options.Preview) { [IO.File]::Delete($Zip.FullName) }
            Write-Host "  [Delete ZIP] $($Zip.FullName)"
        } else { Write-Host "  [Keep ZIP] $($Zip.FullName)" }
        $Options.Control.Completed = $Options.Control.Total
        return [pscustomobject]@{
            Written=@($items | Where-Object { $_.Action -in @('Write','Overwrite') }).Count
            Skipped=@($items | Where-Object { $_.Action -in @('Skip','Duplicate') }).Count
            Unclassified=@($items | Where-Object { $_.Reason -like 'Unclassified archive entry*' }).Count
            Details=@($items | Select-Object Source, @{Name='Target';Expression={$_.Path}}, Action, Reason, Course)
        }
    } finally {
        if ($archive) { $archive.Dispose() }
        if ($scratch -and [IO.Directory]::Exists($scratch)) { [IO.Directory]::Delete($scratch,$true) }
    }
}

function Save-LmsJournal($Journal, [string]$Path) {
    $temporary = $Path + '.tmp'
    $json = $Journal | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($temporary,$json,[Text.UTF8Encoding]::new($false))
    if ([IO.File]::Exists($Path)) { Replace-LmsFile $temporary $Path }
    else { [IO.File]::Move($temporary,$Path) }
}

function Invoke-LmsOrganization($Files, [string]$Root, $Options, $Profile, [hashtable]$Planned) {
    $journal = [pscustomobject]@{Version=1; Root=$Root; Moves=@()}
    $journalPath = $null
    $moved = 0
    $details = New-Object 'Collections.Generic.List[object]'
    $unclassified = 0
    foreach ($file in $Files) {
        if ($Options.Control.CancelRequested) { break }
        $Options.Control.Current = $file.Name
        $Options.Control.Phase = 'Organizing documents'
        $Options.Control.Completed++
        $Options.Control.Total = @($Files).Count
        if ($file.Extension.ToLowerInvariant() -notin @('.pdf','.doc','.docx','.ppt','.pptx','.xls','.xlsx','.odt','.odp','.epub')) { continue }
        Assert-PlainPath $file.FullName
        $course = Get-LmsCourse $file.Directory.Name $Profile.Courses
        $courseName = if ($course) { $course.Code } else { $file.Directory.Name }
        $classification = Get-LmsClassification $file.Name $courseName $Profile $Options.GroupBy $file.Name
        if (-not $classification.Folder) {
            Write-Host "  [Unclassified; unchanged] $($file.FullName)"
            $unclassified++
            $details.Add([pscustomobject]@{Source=$file.FullName; Target=$null; Action='Unclassified'; Reason=$classification.Reason; Course=$courseName})
            continue
        }
        $target = Get-ContainedPath $file.DirectoryName ($classification.Folder + '/' + $file.Name)
        $hash = $null
        if ($Options.Preview -and $Options.ExistingOnly -and -not (Test-Path -LiteralPath $target) -and -not $Planned.ContainsKey($target)) {
            # Existing-only previews need no content read when there is nothing to compare.
            # A real move still hashes the source for the undo record.
            $Planned[$target] = 'preview-source:' + $file.FullName
            $decision = [pscustomobject]@{Path=$target; Action='Write'}
        } else {
            $hash = Get-FileDigest $file.FullName
            $decision = Get-LmsTarget $target $hash $Options.Conflict $Planned
        }
        $details.Add([pscustomobject]@{Source=$file.FullName; Target=$decision.Path; Action=$decision.Action; Reason=$classification.Reason; Course=$courseName})
        if ($decision.Action -ne 'Write') { Write-Host "  [$($decision.Action); original kept] $($file.FullName)"; continue }
        Write-Host "  [Move] $($file.FullName) -> $($decision.Path)"
        Write-Host "    Why: $($classification.Reason)"
        if (-not $Options.Preview) {
            if (-not $journalPath) {
                $history = Get-ContainedPath $Root '.lms-unpacker/history'
                $null = [IO.Directory]::CreateDirectory($history)
                $journalPath = Join-Path $history ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [guid]::NewGuid().ToString('N') + '.json')
            }
            $prefix = $Root.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
            $move = [pscustomobject]@{Source=$file.FullName.Substring($prefix.Length); Target=$decision.Path.Substring($prefix.Length); Hash=$hash; State='Pending'}
            $journal.Moves += $move
            Save-LmsJournal $journal $journalPath
            Assert-PlainPath $decision.Path
            $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($decision.Path))
            [IO.File]::Move($file.FullName,$decision.Path)
            $move.State = 'Moved'
            Save-LmsJournal $journal $journalPath
        }
        $moved++
    }
    if ($journalPath) { Write-Host "Undo record: $journalPath" }
    return [pscustomobject]@{Moved=$moved; Journal=$journalPath; Unclassified=$unclassified; Details=$details.ToArray()}
}

function Invoke-LmsUnpacker {
    [CmdletBinding()]
    param(
        [string]$Path='.', [ValidateSet('Flatten','Extract','Organize')][string]$Mode='Flatten',
        [ValidateSet('Category','Week','Topic')][string]$GroupBy='Category',
        [ValidateRange(0,1)][int]$Depth=1, [ValidateSet('Skip','Rename','Overwrite')][string]$Conflict='Skip',
        [bool]$KeepZip=$false, [bool]$Preview=$false, [bool]$OrganizeExisting=$false,
        [bool]$ExistingOnly=$false, [string]$RulesPath, [string]$OutputPath,
        [hashtable]$Control, [hashtable]$PlannedTargets,
        [ValidateRange(1,100000)][int]$MaxEntries=10000,
        [ValidateRange(1,107374182400)][long]$MaxExpandedBytes=2GB
    )
    $options = @{} + $PSBoundParameters
    if (-not $Control) { $Control = [hashtable]::Synchronized(@{CancelRequested=$false; Current=''; Completed=0; Total=0; Phase=''}) }
    $options.Control = $Control
    $options.OutputPath = $null
    if ($OutputPath) {
        $options.OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
        Assert-PlainPath $options.OutputPath
        if (Test-Path -LiteralPath $options.OutputPath -PathType Leaf) { throw 'Output path must be a folder.' }
        if ($ExistingOnly) { throw 'OutputPath applies to ZIP extraction only. Loose files are organized in place with undo.' }
    }
    foreach ($pair in @{Mode=$Mode; GroupBy=$GroupBy; Conflict=$Conflict; KeepZip=$KeepZip; Preview=$Preview; ExistingOnly=$ExistingOnly; MaxEntries=$MaxEntries; MaxExpandedBytes=$MaxExpandedBytes}.GetEnumerator()) { $options[$pair.Key] = $pair.Value }
    if (($OrganizeExisting -or $ExistingOnly) -and $Mode -ne 'Organize') { throw 'Use -Mode Organize with -OrganizeExisting or -ExistingOnly.' }
    if (($OrganizeExisting -or $ExistingOnly) -and $Conflict -eq 'Overwrite') { throw 'Existing-file organization supports Skip or Rename, not Overwrite.' }
    $profile = Read-LmsRules $RulesPath
    if (-not (Test-Path -LiteralPath $Path)) { throw "Selected folder or ZIP does not exist: $Path" }
    $inputItem = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not $inputItem -or -not $inputItem.PSObject.Properties['FullName']) { throw "Choose a filesystem folder or ZIP: $Path" }
    Assert-PlainPath $inputItem.FullName
    $files = @()
    $root = $inputItem.FullName
    if ($inputItem.PSIsContainer) {
        $folders = @($inputItem)
        if ($Depth -eq 1) {
            $protected = @('Lab','Labs','submission','submissions','templates','Practice','needed','Syllabi','Lectures','Assignments','Quizzes and Exams','Books','Course Info','evidence','ScreenShots','node_modules')
            $folders += @(Get-ChildItem -LiteralPath $root -Directory | Where-Object {
                $_.Name -notin $protected -and -not $_.Name.StartsWith('.') -and -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint)
            })
        }
        foreach ($folder in $folders) { $files += @(Get-ChildItem -LiteralPath $folder.FullName -File | Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) }) }
    } else {
        if ($OrganizeExisting -or $ExistingOnly) { throw 'Existing-file organization requires a folder.' }
        if ($inputItem.Extension -ne '.zip') { throw 'Choose a folder or a .zip file.' }
        $files = @($inputItem)
        $root = $inputItem.DirectoryName
    }
    $zips = @($files | Where-Object { $_.Extension -eq '.zip' } | Sort-Object FullName)
    $options.Root = $root
    $options.Sources = @{}
    foreach ($zip in $zips) { $options.Sources[$zip.FullName] = $true }
    $result = [pscustomobject]@{Archives=0; Written=0; Skipped=0; Moved=0; Unclassified=0; Errors=0; Cancelled=$false; Preview=$Preview; Journal=$null; Details=@()}
    Write-Host "LMS Unpacker | Mode: $Mode | Conflicts: $Conflict | Keep ZIP: $KeepZip"
    if ($Mode -eq 'Organize') { Write-Host "Grouping: $GroupBy" }
    if ($Preview) { Write-Host 'PREVIEW: no files, folders or logs will be created, changed or deleted.' }
    if (-not $ExistingOnly -and -not $KeepZip) { Write-Host 'Successfully processed ZIPs will be deleted, including files skipped because their names already exist.' }
    $planned = if ($null -ne $PlannedTargets) { $PlannedTargets } else { @{} }
    if ($OrganizeExisting -or $ExistingOnly) {
        try {
            $organization = Invoke-LmsOrganization ($files | Sort-Object FullName) $root $options $profile $planned
            $result.Moved = $organization.Moved
            $result.Journal = $organization.Journal
            $result.Unclassified = $organization.Unclassified
            $result.Details += $organization.Details
        } catch {
            $result.Errors++
            Write-Host "[ERROR] Organization stopped: $($_.Exception.Message). Check .lms-unpacker/history for recovery. ZIP processing cancelled."
            return $result
        }
    }
    if (-not $ExistingOnly) {
        if ($zips.Count -eq 0) { Write-Host 'No ZIP files found in the selected scan scope.' }
        foreach ($zip in $zips) {
            if ($Control.CancelRequested) { break }
            Write-Host "Archive: $($zip.FullName)"
            $archivePlan = @{} + $planned
            try {
                $unpacked = Invoke-LmsArchive $zip $options $profile $archivePlan
                $result.Archives++; $result.Written += $unpacked.Written; $result.Skipped += $unpacked.Skipped
                $result.Unclassified += $unpacked.Unclassified
                $result.Details += $unpacked.Details
                foreach ($key in $archivePlan.Keys) { $planned[$key] = $archivePlan[$key] }
            } catch [OperationCanceledException] { $result.Cancelled=$true; Write-Host $_.Exception.Message; break }
            catch { $result.Errors++; Write-Host "[ERROR; ZIP retained] $($_.Exception.Message)" }
        }
    }
    $result.Cancelled = $result.Cancelled -or [bool]$Control.CancelRequested
    Write-Host "Summary: $($result.Archives) ZIP(s), $($result.Written) file(s) written, $($result.Skipped) skipped, $($result.Moved) organized, $($result.Unclassified) unclassified, $($result.Errors) error(s)."
    return $result
}

function Undo-LmsOrganization {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ReportPath, [switch]$Preview)
    $journal = Get-Content -LiteralPath $ReportPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($journal.Version -ne 1) { throw 'Unsupported undo record version.' }
    $root = (Get-Item -LiteralPath $journal.Root).FullName
    Assert-PlainPath $root
    $history = Get-ContainedPath $root '.lms-unpacker/history'
    $report = (Get-Item -LiteralPath $ReportPath).FullName
    if ([IO.Path]::GetDirectoryName($report) -ne $history) { throw 'The undo record must remain in its original .lms-unpacker/history folder.' }
    Assert-PlainPath $report
    $moves = @($journal.Moves)
    [array]::Reverse($moves)
    $restore = @()
    $recovered = @()
    foreach ($move in $moves) {
        if ($move.State -eq 'Undone') { continue }
        $source = Get-ContainedPath $root $move.Source
        $target = Get-ContainedPath $root $move.Target
        if ($move.State -eq 'Restoring' -and (Test-Path -LiteralPath $source -PathType Leaf) -and
            -not (Test-Path -LiteralPath $target) -and (Get-FileDigest $source) -eq $move.Hash) {
            $recovered += $move
            continue
        }
        if ($move.State -eq 'Pending' -and (Test-Path -LiteralPath $source -PathType Leaf) -and -not (Test-Path -LiteralPath $target)) { continue }
        if (Test-Path -LiteralPath $source) { throw "Original location is occupied; nothing undone: $source" }
        if (-not (Test-Path -LiteralPath $target -PathType Leaf) -or (Get-FileDigest $target) -ne $move.Hash) { throw "Organized file missing or modified; nothing undone: $target" }
        $restore += [pscustomobject]@{Source=$source; Target=$target; Move=$move}
    }
    if (-not $Preview -and $recovered.Count -gt 0) {
        foreach ($move in $recovered) { $move.State = 'Undone' }
        Save-LmsJournal $journal $report
    }
    foreach ($item in $restore) {
        Write-Host "[Restore] $($item.Target) -> $($item.Source)"
        if (-not $Preview) {
            Assert-PlainPath $item.Source
            Assert-PlainPath $item.Target
            $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($item.Source))
            $item.Move.State = 'Restoring'
            Save-LmsJournal $journal $report
            [IO.File]::Move($item.Target,$item.Source)
            $item.Move.State = 'Undone'
            Save-LmsJournal $journal $report
        }
    }
    Write-Host "Restored $($restore.Count) file(s). Empty category folders are kept."
}

function Test-LmsProfile {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $null = Read-LmsRules $Path
    return $true
}

Export-ModuleMember -Function Invoke-LmsUnpacker, Undo-LmsOrganization, Test-LmsProfile
