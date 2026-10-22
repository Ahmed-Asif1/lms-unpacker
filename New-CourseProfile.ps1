#requires -Version 5.1
<#
.SYNOPSIS
Build a reusable organization profile from course and syllabus CSV files.
.EXAMPLE
.\New-CourseProfile.ps1 -CoursesCsv .\courses.csv -SyllabusCsv .\syllabus.csv -OutputPath .\my-courses.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CoursesCsv,
    [string]$SyllabusCsv,
    [Parameter(Mandatory)][string]$OutputPath
)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'LmsUnpacker.psm1') -Force
    if (Test-Path -LiteralPath $OutputPath) { throw 'Output already exists. Choose a new profile filename.' }
    $courses = @(Import-Csv -LiteralPath $CoursesCsv -Encoding UTF8)
    if ($courses.Count -eq 0) { throw 'Courses CSV is empty. Expected columns: Code,Folder,Name.' }
    $rules = @()
    if ($SyllabusCsv) {
        foreach ($row in (Import-Csv -LiteralPath $SyllabusCsv -Encoding UTF8)) {
            if (-not $row.Code -or -not $row.Pattern) { throw 'Syllabus rows need Code and Pattern.' }
            if ($row.Code -notin $courses.Code) { throw "Unknown syllabus course: $($row.Code)" }
            $folder = $row.Folder
            if (-not $folder) {
                $week = 0
                if (-not [int]::TryParse($row.Week,[ref]$week) -or $week -lt 1 -or $week -gt 99) { throw 'Supply Folder or a Week from 1 to 99 for every syllabus rule.' }
                $folder = 'Lectures/Week {0:D2}' -f $week
            }
            $rule = [pscustomobject]@{Course=$row.Code; Pattern=$row.Pattern; Folder=$folder}
            foreach ($optional in @('Topic','Reason')) {
                if ($row.PSObject.Properties[$optional] -and $row.$optional) { $rule | Add-Member NoteProperty $optional $row.$optional }
            }
            $rules += $rule
        }
    }
    $profile = [pscustomobject]@{Version=1; Courses=$courses; Rules=$rules}
    $output = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('lms-profile-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        [IO.File]::WriteAllText($temporary,($profile | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        $null = Test-LmsProfile $temporary
        [IO.File]::Copy($temporary,$output,$false)
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
    Write-Host "Created profile: $output"
    Write-Host 'Use it with -Mode Organize -RulesPath, or choose My JSON profile in the launcher.'
} catch { Write-Host "[ERROR] $($_.Exception.Message)"; exit 1 }
