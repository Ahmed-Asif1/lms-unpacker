#requires -Version 5.1
[CmdletBinding()]
param([switch]$PackageOnly)
$ErrorActionPreference = 'Stop'
$buildRoot = $null
Push-Location $PSScriptRoot
try {
    if (-not $PackageOnly) {
        & (Join-Path $PSScriptRoot 'tests\Run-Tests.ps1')
        $windowsPowerShell = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
        & $windowsPowerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Start-Desktop.ps1') -SmokeTest
        if ($LASTEXITCODE -ne 0) { throw 'Desktop flow tests failed.' }
    }
    $version = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'VERSION') -Raw).Trim()
    if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid VERSION.' }
    $dist = Join-Path $PSScriptRoot 'dist'
    $null = [IO.Directory]::CreateDirectory($dist)
    $releaseDestination = Join-Path $dist "LMS-Unpacker-$version.zip"
    if (Test-Path -LiteralPath $releaseDestination) { throw "Release already exists: $releaseDestination. Move it elsewhere before rebuilding." }
    $buildRoot = Join-Path $dist ('.build-' + [guid]::NewGuid().ToString('N'))
    $null = [IO.Directory]::CreateDirectory($buildRoot)
    $destination = Join-Path $buildRoot "LMS-Unpacker-$version.zip"
    $icon = Join-Path $buildRoot 'App.ico'
    & (Join-Path $PSScriptRoot 'packaging\New-AppIcon.ps1') -OutputPath $icon
    $files = @('Unpack-Lms.ps1','LmsUnpacker.psm1','ZipIntegrity.cs','Start-Unpacker.ps1','Run-Unpack.bat','Run-Unpack.sh','Start-Cli.ps1','Start-Desktop.ps1','Desktop.xaml','DesktopIntegration.psm1','DesktopFeatures.ps1','ProfileEditor.ps1',
        'Undo-Organization.ps1','New-CourseProfile.ps1','START-HERE.html','LAUNCH-HELP.txt','README.md','SECURITY.md','LICENSE','VERSION','CHANGELOG.md',
        'profiles\nust.json','profiles\courses.example.csv','profiles\syllabus.example.csv','docs\PROFILES.md','docs\SIGNING.md')
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::Open($destination,'Create')
    try {
        foreach ($file in $files) {
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,(Join-Path $PSScriptRoot $file),('LMS-Unpacker/' + $file.Replace('\','/')))
        }
        $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$icon,'LMS-Unpacker/App.ico')
    } finally { $zip.Dispose() }
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not [IO.File]::Exists($compiler)) { $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
    $common = @('/nologo','/optimize+','/platform:anycpu',('/resource:' + $destination + ',App.zip'),('/win32icon:' + $icon),
        ('/win32manifest:' + (Join-Path $PSScriptRoot 'packaging\App.manifest')),
        '/r:System.IO.Compression.dll','/r:System.IO.Compression.FileSystem.dll','/r:System.Windows.Forms.dll','/r:System.Web.Extensions.dll')
    $desktop = Join-Path $buildRoot 'LMS-Unpacker.exe'
    $cli = Join-Path $buildRoot 'LMS-Unpacker-CLI.exe'
    foreach ($edition in @(@{Path=$desktop; Type='/target:winexe'; Define='/define:DESKTOP'},@{Path=$cli; Type='/target:exe'; Define='/define:CLI'})) {
        & $compiler @common $edition.Type $edition.Define ('/out:' + $edition.Path) (Join-Path $PSScriptRoot 'packaging\PortableHost.cs')
        if ($LASTEXITCODE -ne 0) { throw 'Portable executable compilation failed.' }
    }
    & (Join-Path $PSScriptRoot 'tests\Test-Release.ps1') -CliPath $cli -DesktopPath $desktop
    foreach ($artifact in @($desktop,$cli,$destination)) {
        $hash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
        [IO.File]::WriteAllText(($artifact + '.sha256'),($hash + '  ' + [IO.Path]::GetFileName($artifact) + [Environment]::NewLine))
        foreach ($file in @($artifact,($artifact + '.sha256'))) {
            $publishPath = Join-Path $dist ([IO.Path]::GetFileName($file))
            for ($attempt = 0; ; $attempt++) {
                try {
                    if ([IO.File]::Exists($publishPath)) { [IO.File]::Replace($file,$publishPath,[NullString]::Value) }
                    else { [IO.File]::Move($file,$publishPath) }
                    break
                } catch [IO.IOException] {
                    if ($attempt -ge 5) { throw }
                    Start-Sleep -Milliseconds (200 * ($attempt + 1))
                }
            }
        }
        Write-Host ('Release: ' + (Join-Path $dist ([IO.Path]::GetFileName($artifact))))
        Write-Host "SHA256: $hash"
    }
} finally {
    if ($buildRoot -and [IO.Directory]::Exists($buildRoot)) {
        $resolvedBuild = [IO.Path]::GetFullPath($buildRoot)
        $distPrefix = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'dist')).TrimEnd('\') + '\'
        if ($resolvedBuild.StartsWith($distPrefix,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedBuild) -like '.build-*') {
            Remove-Item -LiteralPath $resolvedBuild -Recurse -Force
        }
    }
    Pop-Location
}
