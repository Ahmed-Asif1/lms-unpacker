#requires -Version 5.1
<# .SYNOPSIS
Preview known generated clutter; pass -Apply to remove it. Unknown files are untouched.
#>
[CmdletBinding()]
param([switch]$Apply)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path $PSScriptRoot -Parent))
$prefix=$root.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
$version=(Get-Content -LiteralPath (Join-Path $root 'VERSION') -Raw).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid VERSION.' }
$dist=Join-Path $root 'dist'
$keep=@('LMS-Unpacker.exe','LMS-Unpacker-CLI.exe','LMS-Unpacker-CLI.sh',"LMS-Unpacker-$version.zip")
function Assert-CleanupPath([string]$Path) {
    $resolved=[IO.Path]::GetFullPath($Path)
    if (-not $resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw "Outside workspace: $resolved" }
    $cursor=$resolved
    while ($cursor -and $cursor -ne $root) {
        if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Refusing linked path: $cursor" }
        $cursor=[IO.Path]::GetDirectoryName($cursor)
    }
    if (Test-Path -LiteralPath $resolved -PathType Container) {
        # Inspect one level at a time, rejecting links before descending.
        $pending=[Collections.Generic.Stack[string]]::new(); $pending.Push($resolved)
        while ($pending.Count) {
            foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing linked child: $($item.FullName)" }
                if ($item.PSIsContainer) { $pending.Push($item.FullName) }
            }
        }
    }
    return $resolved
}
$targets=@()
$scratch=Join-Path $root 'tests/.runs'
if (Test-Path -LiteralPath $scratch) { $targets+=Assert-CleanupPath $scratch }
$targets+=@(Get-ChildItem -LiteralPath $root -File -Filter 'test-results*.txt' | ForEach-Object { Assert-CleanupPath $_.FullName })
if (Test-Path -LiteralPath $dist) {
    $null=Assert-CleanupPath $dist
    $old=@(Get-ChildItem -LiteralPath $dist -File | Where-Object { $_.Name -match '^LMS-Unpacker-(\d+\.\d+\.\d+)\.zip(?:\.sha256)?$' -and [version]$Matches[1] -lt [version]$version })
    if ($old.Count) {
        foreach ($name in $keep) {
            $artifact=Join-Path $dist $name; $sidecar=$artifact+'.sha256'
            if (-not [IO.File]::Exists($artifact) -or -not [IO.File]::Exists($sidecar)) { throw 'Build all current artifacts before removing older packages.' }
            $expected=((Get-Content -LiteralPath $sidecar -Raw).Trim() -split '\s+')[0]
            if ($expected -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash -ne $expected) { throw "Current artifact checksum mismatch: $name" }
        }
        $targets+=@($old | ForEach-Object { Assert-CleanupPath $_.FullName })
    }
}
foreach ($target in $targets) {
    if ($Apply) { $null=Assert-CleanupPath $target; Remove-Item -LiteralPath $target -Recurse -Force; Write-Host "Removed: $target" }
    else { Write-Host "Would remove: $target" }
}
if (-not $targets.Count) { Write-Host 'No known generated clutter found.' }
elseif (-not $Apply) { Write-Host 'Preview only. Close active builds/tests, then use -Apply to clean these paths.' }
