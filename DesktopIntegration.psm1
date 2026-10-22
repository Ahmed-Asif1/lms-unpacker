#requires -Version 5.1
function Add-LmsStartShortcut {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Executable,
        [string]$InstallFolder = (Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Programs\LMS Unpacker'),
        [string]$ShortcutPath = (Join-Path ([Environment]::GetFolderPath('Programs')) 'LMS Unpacker.lnk')
    )
    $ErrorActionPreference = 'Stop'
    $source = (Get-Item -LiteralPath $Executable).FullName
    $null = [IO.Directory]::CreateDirectory($InstallFolder)
    $target = [IO.Path]::GetFullPath((Join-Path $InstallFolder 'LMS-Unpacker.exe'))
    if ($source -ne $target) {
        $temporary = Join-Path $InstallFolder ('update-' + [guid]::NewGuid().ToString('N') + '.tmp')
        try {
            [IO.File]::Copy($source,$temporary,$false)
            if ([IO.File]::Exists($target)) { [IO.File]::Replace($temporary,$target,[NullString]::Value) }
            else { [IO.File]::Move($temporary,$target) }
        } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
    }
    $shell = New-Object -ComObject WScript.Shell
    try {
        $link = $shell.CreateShortcut($ShortcutPath)
        try {
            $link.TargetPath = $target
            $link.WorkingDirectory = [Environment]::GetFolderPath('UserProfile')
            $link.Description = 'Unpack ZIPs and organize your courses'
            $link.IconLocation = $target + ',0'
            $link.Save()
        } finally { $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($link) }
    } finally { $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($shell) }
    return $target
}
Export-ModuleMember -Function Add-LmsStartShortcut
