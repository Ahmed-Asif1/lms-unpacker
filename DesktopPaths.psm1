# Pure path decisions shared by desktop startup, dialogs and integration checks.
function Get-LmsLaunchFolder([string]$Executable,[string]$WorkingDirectory) {
    if ($Executable -and [IO.File]::Exists($Executable)) { return [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Executable)) }
    if ([IO.Directory]::Exists($WorkingDirectory)) { return [IO.Path]::GetFullPath($WorkingDirectory) }
    return [Environment]::GetFolderPath('UserProfile')
}
function Get-LmsPickerFolder([string]$Remembered,[string]$LaunchFolder) {
    foreach ($candidate in @($Remembered,$LaunchFolder)) {
        if ([IO.Directory]::Exists($candidate)) { return [IO.Path]::GetFullPath($candidate) }
    }
    return [Environment]::GetFolderPath('UserProfile')
}
function Get-LmsStartupSelection([string]$ExplicitPath,[string]$LaunchFolder,[string]$Remembered) {
    if ($ExplicitPath) { return [pscustomobject]@{Path=$ExplicitPath; Candidates=@($ExplicitPath)} }
    $lastValid=[IO.Directory]::Exists($Remembered) -or [IO.File]::Exists($Remembered)
    $initial=if ($lastValid) { $Remembered } else { $LaunchFolder }
    return [pscustomobject]@{Path=$initial; Candidates=@(@($LaunchFolder,$initial) | Select-Object -Unique)}
}
Export-ModuleMember -Function Get-LmsLaunchFolder,Get-LmsPickerFolder,Get-LmsStartupSelection
