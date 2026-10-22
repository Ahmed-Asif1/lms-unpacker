#requires -Version 5.1
[CmdletBinding()]
param([string]$Path)
$ErrorActionPreference = 'Stop'

function Read-Choice([string]$Prompt, [string[]]$Allowed, [string]$Default) {
    while ($true) {
        $answer = Read-Host "$Prompt [$Default] (Q to quit)"
        if ($null -eq $answer -or $answer -eq 'q') { throw [OperationCanceledException]::new('Cancelled; no further changes.') }
        if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $Default }
        if ($answer -in $Allowed) { return $answer }
        Write-Host ('Enter one of: ' + ($Allowed -join ', ') + '.')
    }
}

try {
    Write-Host 'LMS Unpacker'
    Write-Host 'Keyboard guide: type a choice and press Enter. Enter accepts [default]. Q quits.'
    Write-Host 'No administrator access or installation is needed.'
    Write-Host 'New here? Use LMS-Unpacker-CLI.exe --tutorial, or open START-HERE.html in the source folder.'
    Import-Module (Join-Path $PSScriptRoot 'LmsUnpacker.psm1') -Force
    if (-not $Path) {
        $Path = Read-Host 'Folder or ZIP path (paste a path, or press Enter for the current folder)'
        if (-not $Path) { $Path = (Get-Location).Path }
        if ($Path -eq 'q') { return }
    }
    $Path = $Path.Trim().Trim('"')
    $item = Get-Item -LiteralPath $Path
    Write-Host "Selected: $($item.FullName)"
    Write-Host '1. Flatten ZIP downloads (remove nested folders)'
    Write-Host '2. Just unzip (keep folders inside a folder named after each ZIP)'
    Write-Host '3. Organize ZIP downloads and loose course documents'
    Write-Host '4. Organize loose course documents only'
    Write-Host '5. Undo a previous organization'
    $task = Read-Choice 'Task' @('1','2','3','4','5') '1'
    if ($task -eq '5') {
        $report = (Read-Host 'Full path to the undo JSON record').Trim().Trim('"')
        if ($report -eq 'q') { return }
        Undo-LmsOrganization -ReportPath $report -Preview
        if ((Read-Choice 'Restore these files? Y=yes, N=cancel' @('y','n') 'n') -eq 'y') { Undo-LmsOrganization -ReportPath $report }
        return
    }
    $mode = switch ($task) { '1' {'Flatten'} '2' {'Extract'} default {'Organize'} }
    if (-not $item.PSIsContainer -and $task -eq '4') { throw 'Choose a folder to organize existing documents.' }
    $depth = 1
    $conflict = 'Skip'
    $keep = $false
    Write-Host 'Defaults: scan one level of course folders; skip existing names; delete ZIPs after success.'
    if ((Read-Choice 'Settings: 1=use defaults, 2=customize' @('1','2') '1') -eq '2') {
        if ($item.PSIsContainer) { $depth = [int](Read-Choice 'Scan: 0=this folder, 1=include immediate course folders' @('0','1') '1') }
        $conflict = if ((Read-Choice 'Conflicts: 1=skip existing names, 2=rename different versions' @('1','2') '1') -eq '1') { 'Skip' } else { 'Rename' }
        if ($task -ne '4') { $keep = (Read-Choice 'Keep ZIP after success? Y=yes, N=delete (including skipped content)' @('y','n') 'n') -eq 'y' }
    }
    $rules = $null
    $groupBy = 'Category'
    if ($mode -eq 'Organize') {
        Write-Host 'Profiles: 1=general categories; 2=NUST Fall 2026; 3=my JSON profile.'
        Write-Host 'Files without week labels need a matching syllabus profile. General categories cannot infer their teaching week.'
        $profile = Read-Choice 'Profile' @('1','2','3') '1'
        if ($profile -eq '2') { $rules = Join-Path $PSScriptRoot 'profiles\nust.json' }
        if ($profile -eq '3') {
            $rules = (Read-Host 'Profile JSON path').Trim().Trim('"')
            if ($rules -eq 'q') { return }
            if (-not $rules) { throw 'A profile path is required for option 3.' }
        }
        $groupBy = switch (Read-Choice 'Group lectures: 1=categories only, 2=by week, 3=by topic' @('1','2','3') '1') {
            '2' { 'Week' }
            '3' { 'Topic' }
            default { 'Category' }
        }
        if ($groupBy -eq 'Topic') { Write-Host 'Topic names come from profile rules; unmatched lecture topics are labeled Unsorted topics.' }
    }
    $options = @{
        Path=$item.FullName; Mode=$mode; GroupBy=$groupBy; Depth=$depth; Conflict=$conflict; KeepZip=$keep; RulesPath=$rules
        OrganizeExisting=($task -eq '3' -and $item.PSIsContainer); ExistingOnly=($task -eq '4')
    }
    Write-Host 'Building a preview. Large archives can take a moment to read.'
    $preview = Invoke-LmsUnpacker @options -Preview $true
    if ($preview.Errors -gt 0) { throw 'Preview found errors. Resolve them before applying changes.' }
    if (($preview.Archives + $preview.Moved) -eq 0) { Write-Host 'Nothing to apply.'; return }
    if ((Read-Choice 'Apply the displayed changes? Y=yes, N=cancel' @('y','n') 'n') -eq 'y') {
        $result = Invoke-LmsUnpacker @options
        if ($result.Errors -gt 0) { exit 1 }
    } else { Write-Host 'Cancelled. No changes made.' }
} catch [OperationCanceledException] {
    Write-Host $_.Exception.Message
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)"
    Write-Host 'Check the path and options, then run Run-Unpack.bat again.'
    Write-Host 'For copy-and-paste launch commands, open START-HERE.html or LAUNCH-HELP.txt.'
    exit 1
}
