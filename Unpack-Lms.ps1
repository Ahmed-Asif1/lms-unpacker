<#
    If PowerShell won't run this script, run this once (no admin needed):
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

.SYNOPSIS
    Extracts LMS zip files and flattens the nested folder structure.
.DESCRIPTION
    Finds all .zip files in the current directory and one folder deep, 
    extracts them to a temp folder outside the course directory, moves all 
    nested files directly into the folder where the zip was found (deduping 
    identical files by content hash, not just name), and cleans up.
.EXAMPLE
    .\Unpack-LMS.ps1
    Default behavior: true duplicates (same content) are always skipped;
    files that share a name but differ in content get renamed.
.EXAMPLE
    .\Unpack-LMS.ps1 -Overwrite
    Forces the script to overwrite existing files that share a name but
    differ in content.
.EXAMPLE
    .\Unpack-LMS.ps1 -SkipExisting -KeepZip
    Skips files that share a name with an existing (different) file, and
    keeps the original .zip instead of deleting it.
.EXAMPLE
    .\Unpack-LMS.ps1 -DryRun
    Shows what would happen without moving, deleting, or extracting
    anything for real.
#>

[CmdletBinding()]
param (
    [switch]$Overwrite,
    [switch]$SkipExisting,
    [switch]$KeepZip,
    [switch]$DryRun
)

$currentDir = Get-Location
# Added -Depth 1 to search current directory and one level down
$zipFiles = Get-ChildItem -Path $currentDir -Filter *.zip -File -Depth 1

if ($zipFiles.Count -eq 0) {
    Write-Host "No zip files found in $currentDir or immediate subfolders." -ForegroundColor Yellow
    exit
}

if ($DryRun) {
    Write-Host "DRY RUN - no files will be moved, deleted, or extracted for real.`n" -ForegroundColor Magenta
}

foreach ($zip in $zipFiles) {
    # Dynamically set working directory to wherever this specific zip is located
    $workingDir = $zip.DirectoryName
    
    Write-Host "`nProcessing: $($zip.Name) (Found in: $($zip.Directory.Name))..." -ForegroundColor Cyan

    # Extract to a scratch folder outside the course directory so a crash
    # mid-run doesn't leave junk behind, and synced folders (OneDrive/
    # Dropbox) don't churn on temp files.
    $tempDir = Join-Path $env:TEMP ("lms_extract_" + [guid]::NewGuid().ToString("N"))

    try {
        Expand-Archive -Path $zip.FullName -DestinationPath $tempDir -Force
    }
    catch {
        Write-Host "  [Error] Could not extract $($zip.Name): $_" -ForegroundColor Red
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        continue
    }

    # Grab every file, completely ignoring the folder hierarchy
    $allFiles = Get-ChildItem -Path $tempDir -File -Recurse

    foreach ($file in $allFiles) {
        # Changed $currentDir to $workingDir so files extract to the right subfolder
        $destination = Join-Path $workingDir $file.Name

        if (Test-Path $destination) {
            $existingHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
            $incomingHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash

            if ($existingHash -eq $incomingHash) {
                Write-Host "  [Duplicate] $($file.Name) is identical, skipped." -ForegroundColor DarkGray
                continue
            }

            # Same name, genuinely different content from here on
            if ($Overwrite) {
                if (-not $DryRun) { Move-Item -Path $file.FullName -Destination $destination -Force }
                Write-Host "  [Overwritten] $($file.Name)" -ForegroundColor Red
            }
            elseif ($SkipExisting) {
                Write-Host "  [Skipped] $($file.Name) already exists (different content)." -ForegroundColor Yellow
            }
            else {
                # Default safety behavior: rename the incoming file
                $i = 1
                $newName = "$($file.BaseName)_$i$($file.Extension)"
                # Changed $currentDir to $workingDir
                $newDestination = Join-Path $workingDir $newName

                while (Test-Path $newDestination) {
                    $i++
                    $newName = "$($file.BaseName)_$i$($file.Extension)"
                    # Changed $currentDir to $workingDir
                    $newDestination = Join-Path $workingDir $newName
                }
                if (-not $DryRun) { Move-Item -Path $file.FullName -Destination $newDestination -Force }
                Write-Host "  [Renamed] $($file.Name) -> $newName" -ForegroundColor DarkGray
            }
        }
        else {
            if (-not $DryRun) { Move-Item -Path $file.FullName -Destination $destination -Force }
            Write-Host "  [Moved] $($file.Name)" -ForegroundColor Green
        }
    }

    # Clean up the extraction folder
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

    # Clean up the zip file unless the user wants to keep it
    if (-not $KeepZip) {
        if ($DryRun) {
            Write-Host "  [DryRun] Would delete original zip." -ForegroundColor DarkGray
        }
        else {
            Remove-Item -Path $zip.FullName -Force
            Write-Host "  Deleted original zip." -ForegroundColor DarkGray
        }
    }
}

Write-Host "`nCleanup complete!" -ForegroundColor Green