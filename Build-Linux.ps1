#requires -Version 7.0
[CmdletBinding()]
param([string]$OutputPath=(Join-Path $PSScriptRoot 'dist/LMS-Unpacker-CLI.sh'))
$ErrorActionPreference='Stop'
$output=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output))
$memory=[IO.MemoryStream]::new()
$zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Create,$true)
try {
    foreach ($file in @('Start-Cli.ps1','Start-Unpacker.ps1','Unpack-Lms.ps1','LmsUnpacker.psm1','ZipIntegrity.cs','Undo-Organization.ps1','New-CourseProfile.ps1','START-HERE.html','README.md','SECURITY.md','LICENSE','VERSION','profiles/nust.json','profiles/courses.example.csv','profiles/syllabus.example.csv','docs/PROFILES.md','docs/SIGNING.md')) {
        $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $PSScriptRoot $file),$file)
    }
} finally { $zip.Dispose() }
try {
    $launcher=([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'packaging/LinuxLauncher.sh')) -replace "`r`n","`n").TrimEnd() + "`n"
    $payload=[Convert]::ToBase64String($memory.ToArray(),[Base64FormattingOptions]::InsertLineBreaks) -replace "`r`n","`n"
    [IO.File]::WriteAllText($output,($launcher + $payload + "`n"),[Text.UTF8Encoding]::new($false))
    $hash=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText(($output+'.sha256'),($hash+'  '+[IO.Path]::GetFileName($output)+"`n"))
    Write-Host "Linux launcher: $output"
} finally { $memory.Dispose() }
