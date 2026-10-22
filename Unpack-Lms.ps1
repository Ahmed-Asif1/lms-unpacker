#requires -Version 5.1
<#
.SYNOPSIS
Unpack ZIP downloads or organize loose course documents.
.DESCRIPTION
Defaults: flatten ZIPs, scan the chosen folder and one level below, skip
existing names, delete successfully processed ZIPs (including skipped content).
Use -KeepZip to retain archives, -Conflict Rename to keep differing versions,
-Mode Extract for ordinary unzip, or -Mode Organize for course categories.
Preview with -DryRun or -WhatIf. Existing folders are never reorganized recursively.
.EXAMPLE
.\Unpack-Lms.ps1 -Path C:\Courses -DryRun
.EXAMPLE
.\Unpack-Lms.ps1 -Path C:\Downloads\materials.zip -Mode Extract
.EXAMPLE
.\Unpack-Lms.ps1 -Path C:\Courses -Mode Organize -OrganizeExisting -DryRun
.EXAMPLE
.\Unpack-Lms.ps1 -Path C:\Courses -Mode Organize -ExistingOnly -RulesPath .\profiles\nust.json
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = '.',
    [ValidateSet('Flatten','Extract','Organize')][string]$Mode = 'Flatten',
    [ValidateSet('Category','Week','Topic')][string]$GroupBy = 'Category',
    [ValidateRange(0,1)][int]$Depth = 1,
    [ValidateSet('Skip','Rename','Overwrite')][string]$Conflict = 'Skip',
    [switch]$KeepZip,
    [switch]$DryRun,
    [switch]$OrganizeExisting,
    [switch]$ExistingOnly,
    [string]$RulesPath,
    [string]$OutputPath,
    [ValidateRange(1,100000)][int]$MaxEntries = 10000,
    [ValidateRange(1,100)][int]$MaxExpandedGB = 2,
    [switch]$SkipExisting,
    [switch]$Overwrite,
    [switch]$PassThru
)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'LmsUnpacker.psm1') -Force
    if ($SkipExisting -and $Overwrite) { throw 'Choose either -SkipExisting or -Overwrite.' }
    if (($SkipExisting -or $Overwrite) -and $PSBoundParameters.ContainsKey('Conflict')) {
        throw 'Use -Conflict or the legacy switches, not both.'
    }
    if ($SkipExisting) { $Conflict = 'Skip' }
    if ($Overwrite) { $Conflict = 'Overwrite' }
    $options = @{
        Path=$Path; Mode=$Mode; GroupBy=$GroupBy; Depth=$Depth; Conflict=$Conflict; KeepZip=[bool]$KeepZip
        Preview=([bool]$DryRun -or [bool]$WhatIfPreference); OrganizeExisting=[bool]$OrganizeExisting
        ExistingOnly=[bool]$ExistingOnly; RulesPath=$RulesPath; OutputPath=$OutputPath; MaxEntries=$MaxEntries
        MaxExpandedBytes=([long]$MaxExpandedGB * 1GB)
    }
    if (-not $options.Preview -and -not $PSCmdlet.ShouldProcess($Path, "Run $Mode (conflicts: $Conflict; keep ZIP: $KeepZip)")) { return }
    $result = Invoke-LmsUnpacker @options
    if ($PassThru) { $result }
    if ($result.Errors -gt 0) { exit 1 }
} catch {
    Write-Host "[ERROR] $($_.Exception.Message)"
    exit 1
}
