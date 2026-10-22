#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param([Parameter(Mandatory)][string]$ReportPath, [switch]$DryRun)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'LmsUnpacker.psm1') -Force
    if ($DryRun -or $WhatIfPreference) { Undo-LmsOrganization -ReportPath $ReportPath -Preview }
    elseif ($PSCmdlet.ShouldProcess($ReportPath,'Restore organized files')) { Undo-LmsOrganization -ReportPath $ReportPath }
} catch { Write-Host "[ERROR] $($_.Exception.Message)"; exit 1 }
