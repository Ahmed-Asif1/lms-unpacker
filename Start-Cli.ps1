#requires -Version 5.1
$ErrorActionPreference = 'Stop'
try {
    $arguments = @()
    if ($env:LMS_ARGUMENTS) { [string[]]$arguments = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:LMS_ARGUMENTS)) | ConvertFrom-Json) }
    if ($arguments.Count -eq 0 -or $arguments[0] -eq '--menu') {
        if ($arguments.Count -gt 2) { throw 'Use --menu with at most one folder or ZIP path.' }
        $selected = if ($arguments.Count -gt 1) { $arguments[1] } else { $null }
        & (Join-Path $PSScriptRoot 'Start-Unpacker.ps1') -Path $selected
        exit $LASTEXITCODE
    }
    if ($arguments[0] -in @('--help','-h','/?')) {
        Write-Host @'
LMS Unpacker CLI
  LMS-Unpacker-CLI.exe                           Guided menu
  LMS-Unpacker-CLI.exe --menu "C:\Courses"        Menu with a selected folder
  LMS-Unpacker-CLI.exe -Path "C:\Courses" -DryRun Preview default flattening
  LMS-Unpacker-CLI.exe -Path "C:\a.zip" -Mode Extract
  LMS-Unpacker-CLI.exe -Path "C:\Courses" -Mode Organize -GroupBy Topic -RulesPath NUST -ExistingOnly -DryRun
  LMS-Unpacker-CLI.exe --undo "C:\Courses\.lms-unpacker\history\record.json" -DryRun
  LMS-Unpacker-CLI.exe --profile                 Build a profile from your CSVs
  LMS-Unpacker-CLI.exe --tutorial                Open the offline visual guide

Defaults: Flatten; Skip existing filenames; DELETE ZIPs after success, including skips.
Use -KeepZip to retain ZIPs, or -Conflict Rename to keep different versions.
Named options run directly. Review with -DryRun first; remove it to apply.
-Mode Flatten|Extract|Organize   -GroupBy Category|Week|Topic   -Depth 0|1
-Conflict Skip|Rename|Overwrite -RulesPath NUST|<JSON path>    -KeepZip
-OrganizeExisting  -ExistingOnly  -DryRun / -WhatIf  -MaxEntries N  -MaxExpandedGB N
Only existing-file organization can be undone. ZIP deletion is permanent.
From PowerShell, prefix a quoted executable path with &. No separate files are needed.
'@
        exit 0
    }
    if ($arguments[0] -eq '--tutorial') {
        Start-Process -FilePath (Join-Path $PSScriptRoot 'START-HERE.html')
        $null = Read-Host 'Press Enter when you have finished with the guide (temporary help files will be removed)'
        exit 0
    }
    if ($arguments[0] -eq '--profile') {
        $courseCsv = (Read-Host 'Courses CSV path').Trim().Trim('"')
        $syllabusCsv = (Read-Host 'Syllabus CSV path (Enter to omit)').Trim().Trim('"')
        $output = (Read-Host 'Save profile JSON to (new filename)').Trim().Trim('"')
        & (Join-Path $PSScriptRoot 'New-CourseProfile.ps1') -CoursesCsv $courseCsv -SyllabusCsv $syllabusCsv -OutputPath $output
        exit $LASTEXITCODE
    }
    if ($arguments[0] -eq '--undo') {
        if ($arguments.Count -lt 2 -or $arguments.Count -gt 3 -or ($arguments.Count -eq 3 -and $arguments[2] -ne '-DryRun')) { throw 'Use --undo <record.json> [-DryRun].' }
        Import-Module (Join-Path $PSScriptRoot 'LmsUnpacker.psm1') -Force
        Undo-LmsOrganization -ReportPath $arguments[1] -Preview:($arguments.Count -eq 3)
        exit 0
    }
    $switches = @('KeepZip','DryRun','WhatIf','OrganizeExisting','ExistingOnly','SkipExisting','Overwrite','PassThru')
    $values = @('Path','Mode','GroupBy','Depth','Conflict','RulesPath','MaxEntries','MaxExpandedGB')
    $options = @{}
    for ($index = 0; $index -lt $arguments.Count; $index++) {
        $name = [string]$arguments[$index]
        if (-not $name.StartsWith('-')) { throw 'Use -Path before a folder or ZIP path. Use --help for examples.' }
        $name = $name.TrimStart('-')
        if ($options.ContainsKey($name)) { throw "Duplicate option: $name" }
        if ($name -in $switches) { $options[$name] = $true }
        elseif ($name -in $values) {
            $index++
            if ($index -ge $arguments.Count) { throw "Missing value for -$name" }
            $options[$name] = $arguments[$index]
        } else { throw "Unknown option: -$name. Use --help." }
    }
    if ($options.RulesPath -eq 'NUST') { $options.RulesPath = Join-Path $PSScriptRoot 'profiles\nust.json' }
    & (Join-Path $PSScriptRoot 'Unpack-Lms.ps1') @options
    exit $LASTEXITCODE
} catch { Write-Host "[ERROR] $($_.Exception.Message)"; exit 1 }
