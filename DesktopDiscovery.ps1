function Set-DesktopHelp {
    $help=@{
        HelpButton='Open the offline visual guide: first launch, scan depth, workspaces, conflicts, course rules and recovery.'
        WorkspaceExpander='A workspace remembers paths, queue, profile and task settings. It does not copy documents. Save one for a semester or a regular routine.'
        WorkspaceChoice='Load a saved setup. Hover a saved item to inspect its folder and settings before choosing it.'
        WorkspaceName='Name this setup, for example Fall semester. Saving an existing name updates it.'
        SaveWorkspaceButton='Save the current paths and task settings locally for reuse next time.'
        RemoveWorkspaceButton='Forget the selected workspace. Your documents are not deleted.'
        QueueExpander='Process several independent folders or ZIPs in order. A single Courses folder already scans its immediate course folders.'
        QueueList='Select an additional path to reorder or remove it. Delete removes only the queue entry, not the file or folder.'
        QueueAddButton='Keep the current path in the queue, then choose the next folder or ZIP.'
        QueueClearButton='Clear additional queued paths. Keep the main selection and all files on disk.'
        QueueFirstButton='Swap this queued path with the main path. Under Skip, the first matching destination wins.'
        QueueRemoveButton='Remove this path from the queue without deleting it from disk.'
        QueueUpButton='Move the selected input earlier. At the top, swap it with the main input.'
        QueueDownButton='Move the selected input later in the queue.'
        OptionsExpander='Change filename conflicts, one-level course-folder scanning and the optional ZIP output folder.'
        AppExpander='Optional Start menu shortcut installation and removal.'
        FolderButton='Choose the folder containing your ZIPs or course folders. First use starts beside the app; later choices remember the last folder.'
        ZipButton='Choose one or several ZIPs with Ctrl or Shift. First use starts beside the app; later choices remember the last ZIP folder.'
        AppFolderButton='Select the folder containing this EXE. Useful when you keep the app beside your course folders.'
        RescanButton='Refresh the ZIP list after adding downloads. Discovery reads filenames only; Preview checks archive contents.'
        TaskChoice='Flatten removes LMS wrapper folders. Just unzip keeps the original structure. Organization adds optional course categories and syllabus rules.'
        KeepZip='Unchecked by default: successfully processed ZIPs are permanently deleted, including skipped incoming files. Check this to retain archives.'
        ScanChildren='Scan this folder and immediate course folders (one level). Deeper folders, links, hidden folders and known working folders such as Lab and submission are excluded.'
        ConflictChoice='Skip keeps existing names even when content differs. Rename keeps different versions with numbered names. Identical matching content is skipped.'
        OutputPath='Leave blank to extract beside each ZIP. A chosen destination collects ZIP output; course routing and original folder structure still apply.'
        OutputBrowseButton='Choose where ZIP contents are written. Loose documents are always organized in place with undo.'
        ProfileChoice='General works with any courses. The NUST mapping is optional. Choose your own JSON profile to use your course codes and syllabus.'
        ProfilePath='Path to your own validated JSON course profile.'
        ProfileBrowseButton='Load your own course names and filename rules from a JSON profile.'
        EditProfileButton='Edit course names and syllabus rules visually. Save a new profile copy to preserve the original.'
        CreateProfileButton='Create a course profile from a courses CSV and optional syllabus CSV. Example columns are explained in the visual guide.'
        GroupChoice='Group lectures by category, known week or named topic. Uncertain week information is never guessed.'
        ClassifyButton='Choose an organization task, preview, and select a file to create a reusable classification rule.'
        UnclassifiedOnly='Show only files without a confident category. Loose documents stay unchanged; unmatched ZIP entries go into Unclassified.'
        UndoButton='Find previous organization records, then preview restoring loose documents. Extraction and deleted ZIPs cannot be undone here.'
        PreviewButton='Read and validate files, then show proposed actions. Preview never extracts, moves or deletes your materials.'
        ApplyButton='Run a successful preview first. Apply rechecks the files and follows your conflict and ZIP deletion settings.'
        CancelButton='Stop at the next safe boundary. Completed work remains; unprocessed ZIPs are retained.'
        OpenFolderButton='Open the selected folder, or ZIP output destination, in File Explorer.'
        ResultOpenButton='Open the result folder. For multiple input locations this opens the first result folder.'
        ArchivesTab='ZIP filenames found in the current scope. Discovery does not open or extract the archives.'
        ArchiveGrid='Found ZIPs. Select one or more rows, then Use selected ZIPs to limit the next preview.'
        UseDetectedButton='Limit processing to the selected ZIPs. Ctrl or Shift selects several. Preview again after changing the selection.'
        StartMenuButton='Copy the EXE to your local Programs folder and create a per-user Start shortcut. No administrator access is needed.'
        RemoveShortcutButton='Remove the Start shortcut. The copied app remains in your local Programs folder.'
    }
    foreach ($name in $help.Keys) {
        $ui[$name].ToolTip=$help[$name]
        [Windows.Automation.AutomationProperties]::SetHelpText($ui[$name],$help[$name])
        [Windows.Controls.ToolTipService]::SetInitialShowDelay($ui[$name],350)
        [Windows.Controls.ToolTipService]::SetShowDuration($ui[$name],20000)
        [Windows.Controls.ToolTipService]::SetShowOnDisabled($ui[$name],$true)
    }
}
function Get-WorkspaceHint($Saved) {
    $task=@('Flatten ZIPs','Just unzip','Organize ZIPs and documents','Organize documents only')[[int]$Saved.Task]
    $output=if ($Saved.Output) { $Saved.Output } else { 'Beside each ZIP' }
    $retention=if ($Saved.KeepZip) { 'Keep ZIPs' } else { 'Delete successful ZIPs' }
    return "Folder: $($Saved.Path)`nAdditional inputs: $(@($Saved.Queue).Count)`nTask: $task`nOutput: $output`n$retention"
}
function Update-WorkspaceHints {
    foreach ($saved in $state.Workspaces) {
        $hint=try { Get-WorkspaceHint $saved } catch { 'Saved setup. Remove and recreate it if the settings are no longer valid.' }
        $saved | Add-Member -NotePropertyName Hint -NotePropertyValue $hint -Force
    }
}
function Remember-PickerSelection([string]$Kind,[string]$Selected) {
    $folder=if ([IO.Directory]::Exists($Selected)) { $Selected } else { [IO.Path]::GetDirectoryName($Selected) }
    if ($Kind -eq 'Folder') { $state.LastFolderPicker=$folder } else { $state.LastZipPicker=$folder }
    if (-not $SmokeTest) { Save-Preferences }
}
function New-InputFolderDialog {
    $dialog=[Windows.Forms.FolderBrowserDialog]::new()
    $dialog.Description='Choose the folder containing your ZIPs or course folders'
    $dialog.ShowNewFolderButton=$false
    $dialog.SelectedPath=Get-LmsPickerFolder $state.LastFolderPicker $state.LaunchFolder
    return $dialog
}
function New-InputZipDialog {
    $dialog=[Microsoft.Win32.OpenFileDialog]::new()
    $dialog.Title='Choose ZIPs'; $dialog.Filter='ZIP archives (*.zip)|*.zip'; $dialog.Multiselect=$true
    $dialog.InitialDirectory=Get-LmsPickerFolder $state.LastZipPicker $state.LaunchFolder
    return $dialog
}
function Request-ZipDiscovery([string[]]$StartupCandidates,[switch]$Force) {
    if ($SmokeTest -and -not $Force) { return }
    $state.DiscoveryVersion++
    $state.DiscoveryPending=@{Paths=@($ui.InputPath.Text)+@($ui.QueueList.Items); Depth=[int][bool]$ui.ScanChildren.IsChecked; Startup=@($StartupCandidates); Version=$state.DiscoveryVersion}
    $ui.DiscoveryText.Text='Looking for ZIPs...'
    $discoveryTimer.Start()
}
function Read-DiscoveryResult($Result) {
    if ($Result.SelectedPath -and $Result.SelectedPath -ne $ui.InputPath.Text) {
        $state.UpdatingDiscovery=$true
        try { $ui.InputPath.Text=$Result.SelectedPath } finally { $state.UpdatingDiscovery=$false }
    }
    $ui.ArchiveGrid.ItemsSource=@($Result.Rows)
    $count=@($Result.Rows).Count
    $ui.ArchivesTab.Header="ZIPs found ($count)"
    $scope=if ($ui.ScanChildren.IsChecked) { 'this folder and one level of course folders' } else { 'the selected folder only' }
    if ($ui.QueueList.Items.Count) { $scope='the selected inputs' }
    $ui.DiscoveryText.Text=if ($count) { "$count ZIP(s) found in $scope. Preview to check their contents." } else { "No ZIPs found in $scope. Choose another location or organize existing documents." }
    if (-not $ui.PlanGrid.ItemsSource -and -not $state.Busy) { $ui.ResultsTabs.SelectedIndex=3 }
}
$discoveryTimer=[Windows.Threading.DispatcherTimer]::new()
$discoveryTimer.Interval=[TimeSpan]::FromMilliseconds(300)
$discoveryTimer.Add_Tick({
    try {
        if ($state.DiscoveryWorker) {
            if (-not $state.DiscoveryHandle.IsCompleted) { return }
            try {
                $output=@($state.DiscoveryWorker.EndInvoke($state.DiscoveryHandle))
                if ($state.DiscoveryActiveVersion -eq $state.DiscoveryVersion -and -not $state.Busy) {
                    if ($state.DiscoveryWorker.HadErrors) { throw 'Could not scan every selected folder. Check access permissions and try Rescan.' }
                    Read-DiscoveryResult ($output | Select-Object -Last 1)
                }
            } finally { $state.DiscoveryWorker.Dispose(); $state.DiscoveryWorker=$null; $state.DiscoveryHandle=$null }
        }
        if ($state.Busy) { return }
        if (-not $state.DiscoveryPending) { $discoveryTimer.Stop(); return }
        $job=$state.DiscoveryPending; $state.DiscoveryPending=$null
        $state.DiscoveryActiveVersion=$job.Version
        $worker=[PowerShell]::Create()
        $script={
            param($Root,$Job)
            $ErrorActionPreference='Stop'
            Import-Module (Join-Path $Root 'LmsUnpacker.psm1') -Force
            $paths=$Job.Paths; $selected=$null; $files=@()
            if ($Job.Startup.Count) {
                foreach ($candidate in $Job.Startup) {
                    try { $found=@(Find-LmsArchives -Path $candidate -Depth $Job.Depth) } catch { continue }
                    if ($found.Count) { $paths=@($candidate); $files=$found; $selected=$candidate; break }
                }
            }
            if (-not $selected) {
                foreach ($path in $paths) {
                    if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) { $files+=@(Find-LmsArchives -Path $path -Depth $Job.Depth) }
                }
            }
            $rows=@($files | Sort-Object FullName -Unique | ForEach-Object {
                [pscustomobject]@{Name=$_.Name; Folder=$_.Directory.Name; Size=('{0:N1} KB' -f ($_.Length/1KB)); FullPath=$_.FullName}
            })
            [pscustomobject]@{SelectedPath=$selected; Rows=$rows}
        }
        $null=$worker.AddScript($script).AddArgument($PSScriptRoot).AddArgument($job)
        $state.DiscoveryWorker=$worker
        $state.DiscoveryHandle=$worker.BeginInvoke()
    } catch {
        $ui.DiscoveryText.Text='Could not complete ZIP discovery. Check the path and permissions, then Rescan.'
        if ($state.DiscoveryWorker) { $state.DiscoveryWorker.Dispose(); $state.DiscoveryWorker=$null }
        if (-not $state.DiscoveryPending) { $discoveryTimer.Stop() }
    }
})
$ui.RescanButton.Add_Click({ Request-ZipDiscovery -Force })
$ui.AppFolderButton.Add_Click({ Set-SelectedPaths @($state.LaunchFolder); Request-ZipDiscovery -Force })
$ui.ArchiveGrid.Add_SelectionChanged({ $ui.UseDetectedButton.IsEnabled=-not $state.Busy -and $ui.ArchiveGrid.SelectedItems.Count -gt 0 })
$ui.UseDetectedButton.Add_Click({ if (-not $state.Busy) { Set-SelectedPaths @($ui.ArchiveGrid.SelectedItems | ForEach-Object { $_.FullPath }) } })
Set-DesktopHelp
Update-WorkspaceHints
$workspaceStyle=[Windows.Style]::new([Windows.Controls.ComboBoxItem])
$workspaceStyle.Setters.Add([Windows.Setter]::new([Windows.FrameworkElement]::ToolTipProperty,[Windows.Data.Binding]::new('Hint')))
$ui.WorkspaceChoice.ItemContainerStyle=$workspaceStyle
