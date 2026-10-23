#requires -Version 5.1
param([Parameter(Mandatory)][string]$CliPath,[Parameter(Mandatory)][string]$DesktopPath)
$ErrorActionPreference = 'Stop'
$releaseRoot = Join-Path $PSScriptRoot ('.runs\release-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($releaseRoot)
function Assert-Release($Condition,[string]$Message) { if (-not $Condition) { throw "Release test failed: $Message" } }
function Invoke-DesktopCheck([string]$Executable) {
    $start = [Diagnostics.ProcessStartInfo]::new($Executable,'--verify-startup')
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true; $start.WindowStyle = 'Hidden'
    $process = [Diagnostics.Process]::Start($start)
    try {
        if (-not $process.WaitForExit(30000)) { $process.Kill(); throw 'Packaged desktop startup timed out.' }
        Assert-Release ($process.ExitCode -eq 0) 'packaged desktop could not load its UI, engine and profile'
    } finally { $process.Dispose() }
}
try {
    Add-Type -AssemblyName System.IO.Compression
    foreach ($executable in @($CliPath,$DesktopPath)) {
        $hostAssembly=[Reflection.Assembly]::Load([IO.File]::ReadAllBytes($executable))
        $payloadStream=$hostAssembly.GetManifestResourceStream('App.zip')
        $payload=[IO.Compression.ZipArchive]::new($payloadStream,[IO.Compression.ZipArchiveMode]::Read)
        try {
            $names=@($payload.Entries | ForEach-Object { $_.FullName })
            Assert-Release ($names -contains 'LMS-Unpacker/START-HERE.html') 'offline user tutorial missing'
            Assert-Release (-not @($names | Where-Object { $_ -match '(?i)(BUILD-IT-YOURSELF\.html|CODE-REFERENCE\.html|Build-CodeReference\.ps1|(^|/)(AGENT|AGENTS)\.md)$' }).Count) 'local learning files or agent notes leaked into executable'
        } finally { $payload.Dispose(); $payloadStream.Dispose() }
    }
    $onlyFiles = Join-Path $releaseRoot 'Only these files & spaces'
    $null = [IO.Directory]::CreateDirectory($onlyFiles)
    Copy-Item -LiteralPath $CliPath -Destination $onlyFiles
    Copy-Item -LiteralPath $DesktopPath -Destination $onlyFiles
    $cli = Join-Path $onlyFiles 'LMS-Unpacker-CLI.exe'
    $desktop = Join-Path $onlyFiles 'LMS-Unpacker.exe'
    $tempBefore = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'lms-unpacker-*' | Select-Object -ExpandProperty FullName)
    $help = & $cli --help
    Assert-Release ($LASTEXITCODE -eq 0 -and ($help -join ' ') -match 'DELETE ZIPs') 'CLI help or embedded runtime failed'
    @('q') | & $cli
    Assert-Release ($LASTEXITCODE -eq 0) 'standalone guided CLI menu failed'
    $materials = Join-Path $releaseRoot 'materials & [brackets]'
    $null = [IO.Directory]::CreateDirectory($materials)
    $archivePath = Join-Path $materials 'example.zip'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::Open($archivePath,'Create')
    try { $writer = [IO.StreamWriter]::new($archive.CreateEntry('nested/example.txt').Open()); try { $writer.Write('fixture') } finally { $writer.Dispose() } } finally { $archive.Dispose() }
    & $cli -Path $archivePath -Mode Extract -DryRun
    Assert-Release ($LASTEXITCODE -eq 0 -and [IO.File]::Exists($archivePath) -and -not [IO.Directory]::Exists((Join-Path $materials 'example'))) 'CLI preview changed files or failed'
    & $cli -Path $archivePath -Mode Extract
    Assert-Release ($LASTEXITCODE -eq 0 -and -not [IO.File]::Exists($archivePath) -and [IO.File]::Exists((Join-Path $materials 'example\nested\example.txt'))) 'standalone extraction failed'
    $failure = & $cli -Path (Join-Path $materials 'missing.zip') -DryRun
    Assert-Release ($LASTEXITCODE -eq 1 -and ($failure -join ' ') -match 'does not exist') 'CLI did not propagate an understandable failure'
    $calculus = Join-Path $materials 'Calculus'
    $null = [IO.Directory]::CreateDirectory($calculus)
    [IO.File]::WriteAllText((Join-Path $calculus 'Continuity.pdf'),'fixture')
    & $cli -Path $calculus -Mode Organize -ExistingOnly -GroupBy Topic -RulesPath NUST -DryRun
    Assert-Release ($LASTEXITCODE -eq 0 -and [IO.File]::Exists((Join-Path $calculus 'Continuity.pdf'))) 'embedded NUST profile or topic preview failed'
    Invoke-DesktopCheck $desktop
    Import-Module (Join-Path $PSScriptRoot '..\DesktopIntegration.psm1') -Force
    $shortcutFile = Join-Path $releaseRoot 'LMS Unpacker.lnk'
    $installed = Add-LmsStartShortcut -Executable $desktop -InstallFolder (Join-Path $releaseRoot 'Installed app') -ShortcutPath $shortcutFile
    $shell = New-Object -ComObject WScript.Shell
    try {
        $link = $shell.CreateShortcut($shortcutFile)
        try { Assert-Release ($link.TargetPath -eq $installed -and [IO.File]::Exists($installed)) 'shortcut target does not point to the copied app' }
        finally { $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
    } finally { $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
    Invoke-DesktopCheck $installed
    $null = Add-LmsStartShortcut -Executable $installed -InstallFolder ([IO.Path]::GetDirectoryName($installed)) -ShortcutPath $shortcutFile
    $null = Add-LmsStartShortcut -Executable $desktop -InstallFolder ([IO.Path]::GetDirectoryName($installed)) -ShortcutPath $shortcutFile
    $tempAfter = @(Get-ChildItem -LiteralPath ([IO.Path]::GetTempPath()) -Directory -Filter 'lms-unpacker-*' | Where-Object { $_.FullName -notin $tempBefore })
    Assert-Release ($tempAfter.Count -eq 0) 'portable runtime did not clean up its temporary directory'
    Write-Host 'PASS: Both standalone executables, CLI preview/apply/errors, copied Start menu target, repeat shortcut installation and temporary cleanup'
} finally {
    $resolvedRelease = [IO.Path]::GetFullPath($releaseRoot)
    $testPrefix = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.runs')).TrimEnd('\') + '\'
    if ($resolvedRelease.StartsWith($testPrefix,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedRelease) -like 'release-*') {
        Remove-Item -LiteralPath $resolvedRelease -Recurse -Force
    }
}
