# Cross-platform integration tests: only synthetic files, no user materials.
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../LmsUnpacker.psm1') -Force
. (Join-Path $PSScriptRoot '../ProfileEditor.ps1')
$run=Join-Path $PSScriptRoot ('.runs/portable-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($run)
function Assert-Portable($Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Make-PortableZip([string]$Path,$Entries) {
    $zip=[IO.Compression.ZipFile]::Open($Path,'Create')
    try { foreach ($key in $Entries.Keys) {
        $writer=[IO.StreamWriter]::new($zip.CreateEntry($key).Open())
        try { $writer.Write([string]$Entries[$key]) } finally { $writer.Dispose() }
    } } finally { $zip.Dispose() }
}
try {
    $inputFolder=Join-Path $run 'input with spaces & punctuation'
    $outputFolder=Join-Path $run 'output'
    $null=[IO.Directory]::CreateDirectory($inputFolder)
    $source=Join-Path $inputFolder 'sample.zip'
    Make-PortableZip $source @{'nested/note.txt'='first'}
    $r=Invoke-LmsUnpacker -Path $source -OutputPath $outputFolder -Preview $true
    Assert-Portable ($r.Errors -eq 0 -and -not [IO.Directory]::Exists($outputFolder) -and [IO.File]::Exists($source)) 'Output preview must not create directories or delete sources'
    $r=Invoke-LmsUnpacker -Path $source -OutputPath $outputFolder
    Assert-Portable ($r.Errors -eq 0 -and [IO.File]::ReadAllText((Join-Path $outputFolder 'note.txt')) -eq 'first' -and -not [IO.File]::Exists($source)) 'Output extraction and delete defaults'
    Make-PortableZip $source @{'nested/note.txt'='different'}
    $r=Invoke-LmsUnpacker -Path $source -OutputPath $outputFolder
    Assert-Portable ($r.Skipped -eq 1 -and -not [IO.File]::Exists($source) -and [IO.File]::ReadAllText((Join-Path $outputFolder 'note.txt')) -eq 'first') 'Skip and delete defaults at external destination'
    Assert-Portable ($r.Details[0].Comparison -like 'Different content*existing file*' -and $r.Details[0].Bytes -eq 9) 'Different existing content must be explicit'
    Make-PortableZip $source @{'nested/note.txt'='first'}
    $r=Invoke-LmsUnpacker -Path $source -OutputPath $outputFolder -Preview $true
    Assert-Portable ($r.Details[0].Action -eq 'Duplicate' -and $r.Details[0].Comparison -like 'Identical content*existing file*') 'Identical content comparison'
    [IO.File]::Delete($source)
    Make-PortableZip $source @{'nested/note.txt'='new version'}
    $r=Invoke-LmsUnpacker -Path $source -OutputPath $outputFolder -Preview $true -Conflict Rename
    Assert-Portable ($r.Details[0].Target.EndsWith('note_1.txt') -and $r.Details[0].Comparison -like 'Different content*') 'Renamed files must retain conflict explanation'
    Write-Host 'PASS: External ZIP destination, preview and defaults'

    $a=Join-Path $inputFolder 'a.zip'; $b=Join-Path $inputFolder 'b.zip'
    Make-PortableZip $a @{'same.txt'='a'}; Make-PortableZip $b @{'same.txt'='b'}
    $planned=@{}
    $r=Invoke-LmsUnpacker -Path $a -OutputPath $outputFolder -Preview $true -PlannedTargets $planned
    $r=Invoke-LmsUnpacker -Path $b -OutputPath $outputFolder -Preview $true -PlannedTargets $planned
    Assert-Portable ($r.Skipped -eq 1 -and $r.Written -eq 0) 'Queue preview must detect collisions across selected paths'
    $control=[hashtable]::Synchronized(@{CancelRequested=$true; Current=''; Completed=0; Total=0; Phase=''})
    $r=Invoke-LmsUnpacker -Path $a -Control $control
    Assert-Portable ($r.Cancelled -and $r.Archives -eq 0 -and [IO.File]::Exists($a)) 'Cancelled work must retain unprocessed ZIPs'
    Write-Host 'PASS: Shared queue collision plan and cancellation'

    $profile=Join-Path $run 'profile.json'
    Save-VisualProfile $profile @([pscustomobject]@{Code='BIO-101'; Folder='Biology'; Name='Biology'}) @([pscustomobject]@{Course='BIO-101'; Pattern='*cell*'; Folder='Lectures/Week 02'; Topic='Cell biology'; Reason='Local syllabus'})
    $courseZip=Join-Path $inputFolder 'BIO-101-course.zip'
    Make-PortableZip $courseZip @{'section/cell.pdf'='fixture'}
    $r=Invoke-LmsUnpacker -Path $courseZip -Mode Organize -GroupBy Topic -RulesPath $profile -OutputPath $outputFolder
    Assert-Portable ($r.Errors -eq 0 -and [IO.File]::Exists((Join-Path $outputFolder 'Biology/Lectures/Cell biology/cell.pdf'))) 'Profile editor output must route any course by topic'
    $rejected=$false
    try { Save-VisualProfile (Join-Path $run 'bad.json') @() @([pscustomobject]@{Course='*'; Pattern='*'; Folder='../escape'}) } catch { $rejected=$true }
    Assert-Portable ($rejected -and -not [IO.File]::Exists((Join-Path $run 'bad.json'))) 'Profile validation must reject unsafe rules before save'
    Write-Host 'PASS: Visual profile model, generic course routing, safe validation'

    $loose=Join-Path $run 'Biology'; $null=[IO.Directory]::CreateDirectory($loose)
    [IO.File]::WriteAllText((Join-Path $loose 'cell.pdf'),'fixture')
    [IO.File]::WriteAllText((Join-Path $loose 'mystery.pdf'),'unknown')
    $r=Invoke-LmsUnpacker -Path $loose -Mode Organize -ExistingOnly $true -GroupBy Week -RulesPath $profile
    Assert-Portable ($r.Moved -eq 1 -and $r.Unclassified -eq 1 -and $r.Errors -eq 0) 'Loose file organization and unclassified review'
    $unknown=@($r.Details | Where-Object Action -eq 'Unclassified')[0]
    Assert-Portable ($unknown.Course -eq 'BIO-101' -and $unknown.Source.EndsWith('mystery.pdf')) 'Review needs original course and filename'
    Undo-LmsOrganization -ReportPath $r.Journal
    Assert-Portable ([IO.File]::Exists((Join-Path $loose 'cell.pdf'))) 'Undo must restore organized files'
    Write-Host 'PASS: Cross-platform organization, review metadata and undo'

    foreach ($bad in @('../outside.txt','/absolute.txt','safe/CON.txt','a.txt:stream')) {
        $malformed=Join-Path $run ([guid]::NewGuid().ToString('N')+'.zip')
        Make-PortableZip $malformed @{$bad='invalid'}
        $r=Invoke-LmsUnpacker -Path $malformed -OutputPath $outputFolder
        Assert-Portable ($r.Errors -eq 1 -and [IO.File]::Exists($malformed)) 'Unsafe ZIP must be retained and rejected'
    }
    Write-Host 'PASS: Cross-platform unsafe ZIP rejection'
    $limited=Join-Path $run 'limited.zip'
    Make-PortableZip $limited @{'large.txt'=('x'*2048)}
    $r=Invoke-LmsUnpacker -Path $limited -MaxExpandedBytes 128
    Assert-Portable ($r.Errors -eq 1 -and [IO.File]::Exists($limited)) 'Expanded-size limit must retain source'
    if ($env:OS -ne 'Windows_NT') {
        $link=Join-Path $run 'linked-output'
        $null=New-Item -ItemType SymbolicLink -Path $link -Target $outputFolder
        $rejected=$false
        try { $null=Invoke-LmsUnpacker -Path $limited -OutputPath $link } catch { $rejected=$true }
        Assert-Portable ($rejected -and [IO.File]::Exists($limited)) 'Linux output symlinks must be rejected'
        Remove-Item -LiteralPath $link
    }
    Write-Host 'PASS: Expanded-size limit and platform link protection'
    Write-Host 'All portable integration checks passed.'
} finally {
    $resolved=[IO.Path]::GetFullPath($run)
    $prefix=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.runs')).TrimEnd([IO.Path]::DirectorySeparatorChar)+[IO.Path]::DirectorySeparatorChar
    if ($resolved.StartsWith($prefix,[StringComparison]::Ordinal) -and [IO.Path]::GetFileName($resolved).StartsWith('portable-')) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
