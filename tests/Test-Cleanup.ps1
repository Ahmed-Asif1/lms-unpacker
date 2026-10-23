#requires -Version 5.1
$ErrorActionPreference='Stop'
$repo=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $PSScriptRoot ('.runs/cleanup-'+[guid]::NewGuid().ToString('N'))
function Assert-Cleanup($Condition,[string]$Message) { if (-not $Condition) { throw "Cleanup check failed: $Message" } }
try {
    foreach($folder in @('tools','dist','tests/.runs')) { $null=[IO.Directory]::CreateDirectory((Join-Path $fixture $folder)) }
    Copy-Item -LiteralPath (Join-Path $repo 'tools/Clean-Workspace.ps1') -Destination (Join-Path $fixture 'tools/Clean-Workspace.ps1')
    [IO.File]::WriteAllText((Join-Path $fixture 'VERSION'),'2.0.0')
    $current=@('LMS-Unpacker.exe','LMS-Unpacker-CLI.exe','LMS-Unpacker-CLI.sh','LMS-Unpacker-2.0.0.zip')
    foreach($name in $current) {
        $file=Join-Path $fixture ('dist/'+$name)
        [IO.File]::WriteAllText($file,'Synthetic artifact; never executed')
        [IO.File]::WriteAllText(($file+'.sha256'),(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash+'  '+$name)
    }
    foreach($name in @('dist/LMS-Unpacker-1.0.0.zip','dist/LMS-Unpacker-1.0.0.zip.sha256','dist/LMS-Unpacker-3.0.0.zip','dist/unknown.txt','personal.txt','tests/.runs/fixture.txt')) {
        [IO.File]::WriteAllText((Join-Path $fixture $name),'fixture')
    }
    $cleaner=Join-Path $fixture 'tools/Clean-Workspace.ps1'
    & $cleaner
    Assert-Cleanup ([IO.File]::Exists((Join-Path $fixture 'dist/LMS-Unpacker-1.0.0.zip'))) 'preview deleted an old package'
    # An incomplete current release must prevent all deletion, even scratch.
    $sidecar=Join-Path $fixture 'dist/LMS-Unpacker-2.0.0.zip.sha256'
    $checksum=[IO.File]::ReadAllText($sidecar); [IO.File]::Delete($sidecar)
    $rejected=$false; try { & $cleaner -Apply } catch { $rejected=$true }
    Assert-Cleanup ($rejected -and [IO.Directory]::Exists((Join-Path $fixture 'tests/.runs'))) 'incomplete current release must block deletion'
    [IO.File]::WriteAllText($sidecar,$checksum)
    & $cleaner -Apply
    Assert-Cleanup (-not [IO.File]::Exists((Join-Path $fixture 'dist/LMS-Unpacker-1.0.0.zip')) -and -not [IO.Directory]::Exists((Join-Path $fixture 'tests/.runs'))) 'known old package and scratch were not removed'
    foreach($name in $current) { Assert-Cleanup ([IO.File]::Exists((Join-Path $fixture ('dist/'+$name)))) ('current artifact lost: '+$name) }
    foreach($name in @('dist/LMS-Unpacker-3.0.0.zip','dist/unknown.txt','personal.txt')) { Assert-Cleanup ([IO.File]::Exists((Join-Path $fixture $name))) ('unrecognized/newer file lost: '+$name) }
    Write-Host 'PASS: Cleanup preview, incomplete-release refusal, current/newer/unknown-file preservation and bounded removal'
} finally {
    $resolved=[IO.Path]::GetFullPath($fixture)
    $prefix=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.runs')).TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if ($resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved) -like 'cleanup-*' -and [IO.Directory]::Exists($resolved)) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
