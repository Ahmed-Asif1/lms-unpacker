function Set-SelectedPaths([string[]]$Paths) {
    if (-not $Paths.Count) { return }
    $ui.QueueList.Items.Clear()
    $ui.InputPath.Text=$Paths[0]
    foreach ($entry in @($Paths | Select-Object -Skip 1 -Unique)) { $null=$ui.QueueList.Items.Add($entry) }
    Invalidate-Preview
}
function Update-ReviewFilter {
    if ($null -eq $ui.PlanGrid.ItemsSource) { return }
    $view=[Windows.Data.CollectionViewSource]::GetDefaultView($ui.PlanGrid.ItemsSource)
    if ($ui.UnclassifiedOnly.IsChecked) { $view.Filter=[Predicate[object]]{ param($row); return $row.Action -eq 'Unclassified' -or $row.Reason -like 'Unclassified archive entry*' } }
    else { $view.Filter=$null }
}
$ui.UnclassifiedOnly.Add_Click({ Update-ReviewFilter })
function Get-WorkspaceSnapshot([string]$Name) {
    return [pscustomobject]@{
        Name=$Name; Path=$ui.InputPath.Text; Queue=@($ui.QueueList.Items); Output=$ui.OutputPath.Text
        Task=$ui.TaskChoice.SelectedIndex; Profile=$ui.ProfileChoice.SelectedIndex; ProfilePath=$ui.ProfilePath.Text
        Group=$ui.GroupChoice.SelectedIndex; Conflict=$ui.ConflictChoice.SelectedIndex
        KeepZip=[bool]$ui.KeepZip.IsChecked; ScanChildren=[bool]$ui.ScanChildren.IsChecked
    }
}
function Restore-Workspace($Saved) {
    foreach ($pair in @(@('Task',3),@('Profile',2),@('Group',2),@('Conflict',1))) {
        if ($null -eq $Saved.($pair[0]) -or [int]$Saved.($pair[0]) -lt 0 -or [int]$Saved.($pair[0]) -gt $pair[1]) { throw 'Saved workspace settings are invalid. Remove it and save a new workspace.' }
    }
    Set-SelectedPaths (@($Saved.Path) + @($Saved.Queue))
    $ui.OutputPath.Text=[string]$Saved.Output
    $ui.TaskChoice.SelectedIndex=[int]$Saved.Task; $ui.ProfileChoice.SelectedIndex=[int]$Saved.Profile
    $ui.ProfilePath.Text=[string]$Saved.ProfilePath; $ui.GroupChoice.SelectedIndex=[int]$Saved.Group
    $ui.ConflictChoice.SelectedIndex=[int]$Saved.Conflict; $ui.KeepZip.IsChecked=[bool]$Saved.KeepZip
    $ui.ScanChildren.IsChecked=[bool]$Saved.ScanChildren; $ui.WorkspaceName.Text=[string]$Saved.Name
    Invalidate-Preview
}
function Edit-SelectedProfile($Seed) {
    Import-Module (Join-Path $PSScriptRoot 'LmsUnpacker.psm1') -Force
    $profile = switch ($ui.ProfileChoice.SelectedIndex) { 1 { Join-Path $PSScriptRoot 'profiles/nust.json' } 2 { $ui.ProfilePath.Text.Trim().Trim('"') } default { '' } }
    $saved=Show-ProfileEditor $window $profile $Seed
    if ($saved) { $ui.ProfilePath.Text=$saved; $ui.ProfileChoice.SelectedIndex=2; Invalidate-Preview; $ui.StatusText.Text='Profile saved and selected. Preview to check the new rules.' }
}
$ui.CancelButton.Add_Click({
    if ($state.Busy -and $state.Control) { $state.Control.CancelRequested=$true; $ui.CancelButton.IsEnabled=$false; $ui.StatusText.Text='Cancellation requested. Finishing the current read or publication safely; please wait.' }
})
$ui.QueueAddButton.Add_Click({
    $path=$ui.InputPath.Text.Trim().Trim('"')
    if ($path -and -not $ui.QueueList.Items.Contains($path)) { $null=$ui.QueueList.Items.Add($path); Invalidate-Preview }
})
$ui.QueueClearButton.Add_Click({ $ui.QueueList.Items.Clear(); Invalidate-Preview })
$ui.SaveWorkspaceButton.Add_Click({
    try {
        $name=$ui.WorkspaceName.Text.Trim()
        if (-not $name) { throw 'Enter a workspace name first.' }
        $state.Workspaces=@($state.Workspaces | Where-Object { $_.Name -ne $name }) + @(Get-WorkspaceSnapshot $name)
        Save-Preferences
        $ui.WorkspaceChoice.ItemsSource=@($state.Workspaces)
        $ui.StatusText.Text='Workspace saved locally. Select it next time to restore paths and settings.'
    } catch { Show-Problem $_.Exception.Message }
})
$ui.RemoveWorkspaceButton.Add_Click({
    if ($ui.WorkspaceChoice.SelectedItem) {
        $name=$ui.WorkspaceChoice.SelectedItem.Name
        $state.Workspaces=@($state.Workspaces | Where-Object { $_.Name -ne $name })
        $ui.WorkspaceChoice.ItemsSource=@($state.Workspaces); Save-Preferences
    }
})
$ui.WorkspaceChoice.Add_SelectionChanged({ if ($ui.WorkspaceChoice.SelectedItem) { try { Restore-Workspace $ui.WorkspaceChoice.SelectedItem } catch { Show-Problem $_.Exception.Message } } })
$ui.OutputBrowseButton.Add_Click({
    $dialog=[Windows.Forms.FolderBrowserDialog]::new(); $dialog.Description='Choose where ZIP contents will be written'; $dialog.ShowNewFolderButton=$true
    try { if ($dialog.ShowDialog() -eq 'OK') { $ui.OutputPath.Text=$dialog.SelectedPath } } finally { $dialog.Dispose() }
})
$ui.EditProfileButton.Add_Click({ try { Edit-SelectedProfile $null } catch { Show-Problem $_.Exception.Message } })
$ui.ClassifyButton.Add_Click({
    try {
        $selected=$ui.PlanGrid.SelectedItem
        if (-not $selected) { throw 'Select a file in the preview first. Unclassified rows are the best place to start.' }
        if ($ui.TaskChoice.SelectedIndex -lt 2) { throw 'Choose an organization task and preview before adding classification rules.' }
        $seed=[pscustomobject]@{Course=$(if ($selected.Course) { $selected.Course } else { '*' }); Pattern=[Management.Automation.WildcardPattern]::Escape($selected.File); Folder='Lectures/Unscheduled'; Topic=''; Reason='Assigned in the review screen'}
        Edit-SelectedProfile $seed
    } catch { Show-Problem $_.Exception.Message }
})
if (-not $SmokeTest -and [IO.File]::Exists($preferences)) {
    try { $savedPreferences=Get-Content -LiteralPath $preferences -Raw -Encoding UTF8 | ConvertFrom-Json; $state.Workspaces=@($savedPreferences.Workspaces | Where-Object { $_ -and $_.Name }); $ui.WorkspaceChoice.ItemsSource=@($state.Workspaces) } catch { $state.Workspaces=@() }
}
