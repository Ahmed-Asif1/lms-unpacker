#requires -Version 5.1
[CmdletBinding()]
param([string]$Path, [switch]$SmokeTest, [string]$RenderPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Windows.Forms

try {
    $reader = [Xml.XmlReader]::Create((Join-Path $PSScriptRoot 'Desktop.xaml'))
    try { $window = [Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Dispose() }
    if ([IO.File]::Exists((Join-Path $PSScriptRoot 'App.ico'))) { $window.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([uri](Join-Path $PSScriptRoot 'App.ico')) }
    $ui = @{}
    foreach ($name in @('HelpButton','StartMenuButton','RemoveShortcutButton','PathPanel','InputPath','FolderButton','ZipButton',
        'SettingsPanel','TaskChoice','TaskHint','OrganizationPanel','ProfileChoice','CustomProfilePanel','ProfilePath','ProfileBrowseButton',
        'CreateProfileButton','GroupChoice','GroupHint','ConflictChoice','KeepZip','ScanChildren','DefaultsNotice','PreviewButton','UndoButton',
        'SummaryText','ResultsTabs','PlanGrid','ActivityText','JournalText','StatusText','BusyProgress','OpenFolderButton','ApplyButton',
        'WorkspaceChoice','WorkspaceName','SaveWorkspaceButton','RemoveWorkspaceButton','QueueList','QueueAddButton','QueueClearButton','QueueFirstButton','QueueRemoveButton','QueueUpButton','QueueDownButton','FileDetails',
        'EditProfileButton','ClassifyButton','OutputPath','OutputBrowseButton','CancelButton','UnclassifiedOnly','QueueExpander','FeedbackPanel','FeedbackTitle','WorkItemText','ResultOpenButton',
        'WorkspaceExpander','OptionsExpander','AppExpander','ReviewTools','DiscoveryText','AppFolderButton','RescanButton','ArchivesTab','ArchiveGrid','UseDetectedButton')) {
        $ui[$name] = $window.FindName($name)
        if (-not $ui[$name]) { throw "Missing interface control: $name" }
    }
    $state = @{ Busy=$false; Preview=$null; Operation=$null; Worker=$null; Handle=$null; InformationIndex=0; UndoPath=$null; Workspaces=@(); LastFolderPicker=''; LastZipPicker=''; DiscoveryVersion=0; DiscoveryWorker=$null; DiscoveryPending=$null }
    $preferences = Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'LMS Unpacker\preferences.json'
    $shortcut = Join-Path ([Environment]::GetFolderPath('Programs')) 'LMS Unpacker.lnk'
    $appExe = $env:LMS_APP_EXE
    Import-Module (Join-Path $PSScriptRoot 'DesktopPaths.psm1') -Force
    $state.LaunchFolder=Get-LmsLaunchFolder $appExe (Get-Location).Path
    $savedPreferences=$null
    if (-not $SmokeTest -and [IO.File]::Exists($preferences)) {
        try {
            $savedPreferences=Get-Content -LiteralPath $preferences -Raw -Encoding UTF8 | ConvertFrom-Json
            $state.Workspaces=@($savedPreferences.Workspaces | Where-Object { $_ -and $_.Name })
            $state.LastFolderPicker=if ($savedPreferences.LastFolderPicker) { $savedPreferences.LastFolderPicker } else { $savedPreferences.Path }
            $state.LastZipPicker=if ($savedPreferences.LastZipPicker) { $savedPreferences.LastZipPicker } else { $savedPreferences.Path }
            $ui.WorkspaceChoice.ItemsSource=@($state.Workspaces)
        } catch { $state.Workspaces=@() }
    }
    $window.Width = [Math]::Min(1120,[Windows.SystemParameters]::WorkArea.Width - 30)
    $window.Height = [Math]::Min(790,[Windows.SystemParameters]::WorkArea.Height - 30)
    if (-not [Windows.SystemParameters]::HighContrast) {
        $window.Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#F5F4EF')
        $window.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#182D2B')
        foreach ($name in @('ApplyButton')) {
            $ui[$name].Background = [Windows.Media.BrushConverter]::new().ConvertFromString('#14634B')
            $ui[$name].Foreground = [Windows.Media.Brushes]::White
        }
    }

    function Show-Problem([string]$Message) {
        $ui.StatusText.Text = $Message
        $null = [Windows.MessageBox]::Show($window,$Message,'LMS Unpacker','OK','Warning')
    }
    function Update-Hints {
        $ui.QueueExpander.Header = 'Additional inputs (' + $ui.QueueList.Items.Count + ')'
        $organize = $ui.TaskChoice.SelectedIndex -ge 2
        $ui.OrganizationPanel.Visibility = if ($organize) { 'Visible' } else { 'Collapsed' }
        $ui.ReviewTools.Visibility = if ($organize -and $ui.PlanGrid.ItemsSource) { 'Visible' } else { 'Collapsed' }
        $ui.PlanGrid.Columns[4].Visibility=if ($organize) { 'Visible' } else { 'Collapsed' }
        $ui.PlanGrid.Columns[3].Visibility=if (@($ui.PlanGrid.ItemsSource | Where-Object { $_.Comparison }).Count) { 'Visible' } else { 'Collapsed' }
        $ui.CustomProfilePanel.Visibility = if ($ui.ProfileChoice.SelectedIndex -eq 2) { 'Visible' } else { 'Collapsed' }
        $ui.KeepZip.IsEnabled = $ui.TaskChoice.SelectedIndex -ne 3
        $ui.OutputPath.IsEnabled = $ui.TaskChoice.SelectedIndex -ne 3
        $ui.OutputBrowseButton.IsEnabled = $ui.TaskChoice.SelectedIndex -ne 3
        $ui.TaskHint.Text = @('Remove LMS wrapper folders. Files land directly beside each ZIP.',
            'Keep every internal folder inside a folder named after the ZIP. Best for projects and linked files.',
            'Sort ZIP contents and loose course documents into useful folders. Working subfolders are not scanned recursively.',
            'Organize already-extracted documents. No ZIPs are opened or deleted.')[ $ui.TaskChoice.SelectedIndex ]
        $ui.GroupHint.Text = @('Assignments, books and other categories stay separate.',
            'Use week labels or syllabus rules. Broad topics may span weeks; uncertain weeks stay Unscheduled.',
            'Topic names come from your profile. Lectures without a matching topic go to Unsorted topics.')[ $ui.GroupChoice.SelectedIndex ]
        $ui.DefaultsNotice.Text = if ($ui.TaskChoice.SelectedIndex -eq 3) { 'Existing documents are never overwritten. An undo record is saved when files move.' }
            elseif ($ui.KeepZip.IsChecked) { 'Source ZIPs will be kept after success.' }
            elseif ($ui.ConflictChoice.SelectedIndex -eq 0) { 'After success, ZIPs are permanently deleted, including incoming files skipped because their names already exist.' }
            else { 'Different versions get new filenames. Source ZIPs are permanently deleted after success.' }
    }
    function Invalidate-Preview {
        if ($state.Busy) { return }
        $state.Preview = $null
        $state.UndoPath = $null
        $ui.ApplyButton.IsEnabled = $false
        $ui.ApplyButton.Content = '_Apply changes'
        $ui.PlanGrid.ItemsSource = $null
        $ui.ClassifyButton.IsEnabled=$false
        $ui.SummaryText.Text = 'Selection or settings changed. Preview to see the current plan.'
        $ui.StatusText.Text = 'Ready • Preview first'
        Reset-Feedback
        $ui.OpenFolderButton.IsEnabled = -not [string]::IsNullOrWhiteSpace($ui.InputPath.Text)
        Update-Hints
        if (-not $state.UpdatingDiscovery) { Request-ZipDiscovery }
    }
    function Get-Options {
        $selectedPath = $ui.InputPath.Text.Trim().Trim('"')
        if (-not $selectedPath) { throw 'Choose a folder or ZIP first.' }
        $item = Get-Item -LiteralPath $selectedPath
        if (-not $item.PSIsContainer -and $item.Extension -ne '.zip') { throw 'Choose a folder or a ZIP file.' }
        if (-not $item.PSIsContainer -and $ui.TaskChoice.SelectedIndex -eq 3) { throw 'Choose a folder for existing-document organization.' }
        $rules = if ($ui.TaskChoice.SelectedIndex -ge 2) { switch ($ui.ProfileChoice.SelectedIndex) {
            1 { Join-Path $PSScriptRoot 'profiles\nust.json' }
            2 { if (-not $ui.ProfilePath.Text.Trim()) { throw 'Choose your JSON profile, or use General.' }; $ui.ProfilePath.Text.Trim().Trim('"') }
            default { $null }
        } } else { $null }
        return @{
            Path=$item.FullName; Mode=@('Flatten','Extract','Organize','Organize')[$ui.TaskChoice.SelectedIndex]
            QueuePaths=@($ui.QueueList.Items); OutputPath=$(if ($ui.TaskChoice.SelectedIndex -ne 3) { $ui.OutputPath.Text.Trim().Trim('"') } else { '' })
            GroupBy=@('Category','Week','Topic')[$ui.GroupChoice.SelectedIndex]; Depth=[int][bool]$ui.ScanChildren.IsChecked
            Conflict=@('Skip','Rename')[$ui.ConflictChoice.SelectedIndex]; KeepZip=[bool]$ui.KeepZip.IsChecked; RulesPath=$rules
            OrganizeExisting=($ui.TaskChoice.SelectedIndex -eq 2 -and $item.PSIsContainer); ExistingOnly=($ui.TaskChoice.SelectedIndex -eq 3)
        }
    }
    function Set-Busy([bool]$Busy) {
        $state.Busy = $Busy
        $ui.PathPanel.IsEnabled = -not $Busy
        $ui.SettingsPanel.IsEnabled = -not $Busy
        foreach ($name in @('UndoButton','StartMenuButton','RemoveShortcutButton','ClassifyButton','PreviewButton')) { $ui[$name].IsEnabled = -not $Busy }
        $ui.ClassifyButton.IsEnabled = -not $Busy -and $ui.TaskChoice.SelectedIndex -ge 2 -and $null -ne $ui.PlanGrid.SelectedItem
        $ui.UseDetectedButton.IsEnabled = -not $Busy -and $ui.ArchiveGrid.SelectedItems.Count -gt 0
        $ui.CancelButton.Visibility = if ($Busy -and $state.Operation -notlike 'Undo*') { 'Visible' } else { 'Collapsed' }
        $ui.CancelButton.IsEnabled = $true
        $ui.ApplyButton.IsEnabled = $false
        $ui.BusyProgress.Visibility = if ($Busy) { 'Visible' } else { 'Collapsed' }
        $ui.OpenFolderButton.IsEnabled = -not $Busy -and -not [string]::IsNullOrWhiteSpace($ui.InputPath.Text)
        $ui.PreviewButton.Content = if ($Busy -and $state.Operation -like '*Preview') { 'Reading files...' } else { '_Preview changes' }
        if ($Busy -and $state.Operation -like '*Apply') { $ui.ApplyButton.Content='Working...' }
    }
    function Save-Preferences {
        try {
            $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($preferences))
            $remember = $ui.InputPath.Text.Trim().Trim('"')
            if (-not [IO.Directory]::Exists($remember)) { $remember = [IO.Path]::GetDirectoryName($remember) }
            [IO.File]::WriteAllText($preferences,(@{Path=$remember; Workspaces=@($state.Workspaces | Select-Object * -ExcludeProperty Hint); LastFolderPicker=$state.LastFolderPicker; LastZipPicker=$state.LastZipPicker} | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        } catch { $ui.ActivityText.AppendText("Could not remember the last path: $($_.Exception.Message)`r`n") }
    }
    function Start-Work([string]$Operation, [hashtable]$Options, [string]$UndoPath) {
        if ($state.Busy) { return }
        $state.Operation = $Operation
        if ($Options.Path) {
            $selectedItem = Get-Item -LiteralPath $Options.Path
            $state.DisplayRoot = if ($selectedItem.PSIsContainer) { $selectedItem.FullName } else { $selectedItem.DirectoryName }
        }
        $state.InformationIndex = 0
        $state.Control = [hashtable]::Synchronized(@{CancelRequested=$false; Current=''; Completed=0; Total=0; Phase='Starting'; QueueIndex=0; QueueTotal=1})
        $ui.ActivityText.Clear()
        $ui.JournalText.Visibility = 'Collapsed'
        $ui.StatusText.Text = if ($Operation -like '*Preview') { 'Reading the selected files and building a preview…' } else { 'Applying changes. Please keep the app open until it finishes.' }
        Start-Feedback $Operation $Options
        Set-Busy $true
        $worker = [PowerShell]::Create()
        $script = {
            param($Root,$Options,$Operation,$UndoPath,$Control)
            $ErrorActionPreference = 'Stop'
            Import-Module (Join-Path $Root 'LmsUnpacker.psm1') -Force
            if ($Operation -like 'Undo*') {
                Undo-LmsOrganization -ReportPath $UndoPath -Preview:($Operation -eq 'UndoPreview')
                return [pscustomobject]@{Undo=$true; Preview=($Operation -eq 'UndoPreview'); Errors=0; Details=@()}
            }
            $paths = @(@($Options.Path) + @($Options.QueuePaths) | Select-Object -Unique)
            $Options.Remove('QueuePaths')
            # Reject overlapping scopes before touching any files. A queue is an explicit set of independent inputs.
            $seen=@{}
            $inputs = @(foreach ($selectedPath in $paths) {
                $selectedItem=Get-Item -LiteralPath $selectedPath -ErrorAction Stop
                if (-not $seen.ContainsKey($selectedItem.FullName)) { $seen[$selectedItem.FullName]=$true; $selectedItem }
            })
            foreach ($input in $inputs) {
                if (-not $input.PSIsContainer -and $input.Extension -ne '.zip') { throw 'Each queued item must be a folder or ZIP.' }
                if (-not $input.PSIsContainer -and ($Options.ExistingOnly -or $Options.OrganizeExisting)) {
                    if ($Options.ExistingOnly) { throw 'Loose-document tasks require folders throughout the queue.' }
                }
                foreach ($other in $inputs) {
                    if ($input -ne $other -and $other.PSIsContainer -and $input.FullName.StartsWith(($other.FullName.TrimEnd('\') + '\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Queue paths overlap. Remove the nested selection and preview again.' }
                }
            }
            $total = [pscustomobject]@{Archives=0; Written=0; Skipped=0; Moved=0; Unclassified=0; Errors=0; Cancelled=$false; Preview=($Operation -eq 'Preview'); Journal=$null; Details=@()}
            $sharedTargets = @{}
            $Control.QueueTotal = $inputs.Count
            foreach ($input in $inputs) {
                if ($Control.CancelRequested) { $total.Cancelled=$true; break }
                $Control.QueueIndex++; $Control.Completed=0; $Control.Total=0
                $jobOptions = @{} + $Options
                $jobOptions.Path=$input.FullName
                if (-not $input.PSIsContainer) { $jobOptions.OrganizeExisting=$false }
                $result = Invoke-LmsUnpacker @jobOptions -Preview ($Operation -eq 'Preview') -Control $Control -PlannedTargets $sharedTargets
                foreach ($field in @('Archives','Written','Skipped','Moved','Unclassified','Errors')) { $total.$field += $result.$field }
                $total.Details += $result.Details
                if ($result.Journal) { $total.Journal = (@($total.Journal,$result.Journal) | Where-Object { $_ }) -join [Environment]::NewLine }
                $total.Cancelled = $result.Cancelled
                if ($result.Errors -gt 0 -or $result.Cancelled) { break }
            }
            return $total
        }
        $null = $worker.AddScript($script).AddArgument($PSScriptRoot).AddArgument($Options).AddArgument($Operation).AddArgument($UndoPath).AddArgument($state.Control)
        $state.Worker = $worker
        try { $state.Handle = $worker.BeginInvoke(); $timer.Start() }
        catch { $worker.Dispose(); $state.Worker = $null; Set-Busy $false; Stop-FeedbackWithError; throw }
    }
    function Read-Activity {
        Update-Feedback
        if ($state.Control -and -not $state.Control.CancelRequested) {
            $progress = $state.Control
            $ui.BusyProgress.IsIndeterminate = $progress.Total -eq 0
            if ($progress.Total -gt 0) { $ui.BusyProgress.Value = [Math]::Min(100,100 * $progress.Completed / $progress.Total) }
            $ui.StatusText.Text = 'Working - you can review the activity log while this runs.'
        }
        $stream = $state.Worker.Streams.Information
        while ($state.InformationIndex -lt $stream.Count) {
            $ui.ActivityText.AppendText([string]$stream[$state.InformationIndex].MessageData + "`r`n")
            $state.InformationIndex++
        }
    }
    $timer = [Windows.Threading.DispatcherTimer]::new()
    $timer.Interval = [TimeSpan]::FromMilliseconds(180)
    $timer.Add_Tick({
        try {
            Read-Activity
            if (-not $state.Handle.IsCompleted) { return }
            $timer.Stop()
            $output = @($state.Worker.EndInvoke($state.Handle))
            Read-Activity
            if ($state.Worker.Streams.Error.Count -gt 0) { throw ($state.Worker.Streams.Error | Out-String) }
            $result = $output | Select-Object -Last 1
            if (-not $result) { throw 'No operation result was returned. Review the activity log.' }
            if ($result.Errors -gt 0) { throw 'Some operations failed. Read Activity and errors for details. Affected ZIPs were kept; some files may already have been written.' }
            if ($state.Operation -like 'Undo*') {
                $ui.PlanGrid.ItemsSource = $null
                $ui.ResultsTabs.SelectedIndex = 1
                $ui.SummaryText.Text = if ($result.Preview) { 'Undo preview ready. Check the listed original locations before restoring.' } else { 'Original file locations restored. Empty folders are kept.' }
            } else {
                $selectedRoot = $state.DisplayRoot
                $rootPrefix = $selectedRoot.TrimEnd('\') + '\'
                $rows = @($result.Details | ForEach-Object {
                    $destination = if ($_.PSObject.Properties['Target']) { $_.Target } else { $_.Path }
                    $relative = if ($destination -and $destination.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)) { $destination.Substring($rootPrefix.Length) } else { $destination }
                    $comparisonLabel = if ($_.Comparison -like 'Identical*') { 'Identical content' } elseif ($_.Comparison) { 'Different content' } else { '' }
                    [pscustomobject]@{ Action=$_.Action; File=[IO.Path]::GetFileName($_.Source); Source=$_.Source; Course=$_.Course; Destination=$relative; FullDestination=$destination; Reason=$_.Reason; Comparison=$_.Comparison; ComparisonLabel=$comparisonLabel; Bytes=$_.Bytes; Archive=$_.Archive }
                })
                $ui.PlanGrid.ItemsSource = $rows
                $ui.ResultsTabs.SelectedIndex=0
                Update-ReviewFilter
                Update-Hints
                $prefix = if ($result.Preview) { 'Planned' } else { 'Completed' }
                $ui.SummaryText.Text = "$prefix`: $($result.Archives) ZIPs; $($result.Written) extracted; $($result.Moved) organized; $($result.Skipped) skipped; $($result.Unclassified) unclassified."
                if ($result.Journal) { $ui.JournalText.Text = 'Undo record: ' + $result.Journal; $ui.JournalText.Visibility = 'Visible' }
            }
            $state.Preview = if ($result.Preview) { $result } else { $null }
            Set-Busy $false
            $ui.ApplyButton.IsEnabled = $result.Preview -and ($state.Operation -eq 'UndoPreview' -or ($result.Archives + $result.Moved -gt 0))
            $ui.ApplyButton.Content = if ($state.Operation -eq 'UndoPreview') { '_Restore original locations' } else { '_Apply changes' }
            $ui.StatusText.Text = if ($ui.ApplyButton.IsEnabled) { 'Preview ready • Review destinations and settings, then apply.' } elseif ($result.Preview) { 'Nothing to apply. Check the selected folder, task and scan depth.' } else { 'Finished • Your selected folder is ready to open.' }
            if ($result.PSObject.Properties['Cancelled'] -and $result.Cancelled) {
                $state.Preview=$null; $ui.ApplyButton.IsEnabled=$false
                $ui.StatusText.Text='Cancelled safely. Completed work remains; unprocessed ZIPs are kept. Preview again to continue.'
            }
            if (-not $result.Preview -and -not $SmokeTest) { Save-Preferences }
            Complete-Feedback $result
            if (-not $result.Preview) { Request-ZipDiscovery }
        } catch {
            $timer.Stop()
            $state.Preview = $null
            $ui.ActivityText.AppendText("[ERROR] $($_.Exception.Message)`r`n")
            $ui.ResultsTabs.SelectedIndex = 1
            $ui.SummaryText.Text = 'Operation stopped or reported errors. Review the activity log before trying again.'
            Set-Busy $false
            $ui.StatusText.Text = 'Needs attention • See Activity and errors'
            Stop-FeedbackWithError
        } finally {
            if (-not $state.Busy -and $state.Worker) { $state.Worker.Dispose(); $state.Worker = $null; $state.Handle = $null }
        }
    })
    . (Join-Path $PSScriptRoot 'ProfileEditor.ps1')
    . (Join-Path $PSScriptRoot 'DesktopFeatures.ps1')
    . (Join-Path $PSScriptRoot 'HistoryDialog.ps1')
    . (Join-Path $PSScriptRoot 'DesktopFeedback.ps1')
    . (Join-Path $PSScriptRoot 'DesktopDiscovery.ps1')
    $ui.PreviewButton.Add_Click({ try { $state.UndoPath = $null; Start-Work 'Preview' (Get-Options) $null } catch { Show-Problem $_.Exception.Message } })
    $ui.ApplyButton.Add_Click({
        try {
            if (-not $state.Preview -or $state.Busy) { return }
            if ($state.UndoPath) { Start-Work 'UndoApply' @{} $state.UndoPath }
            else { Start-Work 'Apply' (Get-Options) $null }
        } catch { Show-Problem $_.Exception.Message }
    })
    $ui.FolderButton.Add_Click({
        $dialog = New-InputFolderDialog
        try { if ($dialog.ShowDialog() -eq 'OK') { $ui.InputPath.Text = $dialog.SelectedPath; Remember-PickerSelection 'Folder' $dialog.SelectedPath } } finally { $dialog.Dispose() }
    })
    $ui.ZipButton.Add_Click({
        $dialog = New-InputZipDialog
        if ($dialog.ShowDialog($window)) { Set-SelectedPaths $dialog.FileNames; Remember-PickerSelection 'Zip' $dialog.FileNames[0] }
    })
    $ui.ProfileBrowseButton.Add_Click({
        $dialog = [Microsoft.Win32.OpenFileDialog]::new()
        $dialog.Filter = 'Course profiles (*.json)|*.json'
        if ($dialog.ShowDialog($window)) { $ui.ProfilePath.Text = $dialog.FileName }
    })
    $ui.CreateProfileButton.Add_Click({
        try {
            $courseDialog = [Microsoft.Win32.OpenFileDialog]::new()
            $courseDialog.Title = '1. Choose courses CSV (Code, Folder, Name)'; $courseDialog.Filter = 'CSV files (*.csv)|*.csv'
            if (-not $courseDialog.ShowDialog($window)) { return }
            $syllabus = [Microsoft.Win32.OpenFileDialog]::new()
            $syllabus.Title = '2. Choose syllabus CSV (Cancel to use course routing only)'; $syllabus.Filter = 'CSV files (*.csv)|*.csv'
            $syllabusPath = if ($syllabus.ShowDialog($window)) { $syllabus.FileName } else { '' }
            $save = [Microsoft.Win32.SaveFileDialog]::new()
            $save.Title = '3. Save your course profile (use a new filename)'; $save.Filter = 'JSON profile (*.json)|*.json'; $save.FileName = 'my-courses.json'
            if (-not $save.ShowDialog($window)) { return }
            if ([IO.File]::Exists($save.FileName)) { throw 'That profile already exists. Choose a new filename to preserve your existing rules.' }
            $builder = [PowerShell]::Create()
            try {
                $null = $builder.AddCommand((Join-Path $PSScriptRoot 'New-CourseProfile.ps1')).AddParameter('CoursesCsv',$courseDialog.FileName).AddParameter('SyllabusCsv',$syllabusPath).AddParameter('OutputPath',$save.FileName)
                $null = $builder.Invoke()
                if ($builder.HadErrors -or -not [IO.File]::Exists($save.FileName)) { throw ($builder.Streams.Information | Out-String) }
            } finally { $builder.Dispose() }
            $ui.ProfilePath.Text = $save.FileName
            $ui.ProfileChoice.SelectedIndex = 2
            $ui.StatusText.Text = 'Profile created and selected. Preview to check your rules.'
        } catch { Show-Problem $_.Exception.Message }
    })
    $ui.UndoButton.Add_Click({
        try {
            $record = Show-HistoryDialog $window (@($ui.InputPath.Text) + @($ui.QueueList.Items))
            if ($record) { $state.UndoPath = $record; Start-Work 'UndoPreview' @{} $state.UndoPath }
        } catch { Show-Problem $_.Exception.Message }
    })
    $ui.OpenFolderButton.Add_Click({
        try {
            $selected = $ui.InputPath.Text.Trim().Trim('"')
            $folder = if ($ui.OutputPath.IsEnabled -and $ui.OutputPath.Text.Trim()) { $ui.OutputPath.Text.Trim().Trim('"') } elseif ([IO.Directory]::Exists($selected)) { $selected } else { [IO.Path]::GetDirectoryName($selected) }
            if (-not [IO.Directory]::Exists($folder)) { throw 'The selected folder does not exist.' }
            Start-Process -FilePath explorer.exe -ArgumentList ('"' + $folder + '"')
        } catch { Show-Problem $_.Exception.Message }
    })
    $ui.HelpButton.Add_Click({ try { Start-Process -FilePath (Join-Path $PSScriptRoot 'START-HERE.html') } catch { Show-Problem $_.Exception.Message } })
    $ui.StartMenuButton.Add_Click({
        try {
            if (-not $appExe -or -not [IO.File]::Exists($appExe)) { throw 'Use the packaged LMS-Unpacker.exe to add the app to the Start menu.' }
            Import-Module (Join-Path $PSScriptRoot 'DesktopIntegration.psm1') -Force
            $null = Add-LmsStartShortcut -Executable $appExe
            $ui.RemoveShortcutButton.Visibility = 'Visible'
            $ui.StatusText.Text = 'Added to Start. Search for LMS Unpacker; you can move or remove the original download.'
        } catch { Show-Problem $_.Exception.Message }
    })
    $ui.RemoveShortcutButton.Add_Click({
        try { if ([IO.File]::Exists($shortcut)) { [IO.File]::Delete($shortcut) }; $ui.RemoveShortcutButton.Visibility = 'Collapsed'; $ui.StatusText.Text = 'Start menu shortcut removed. The app copy remains in LocalAppData\Programs\LMS Unpacker.' }
        catch { Show-Problem $_.Exception.Message }
    })
    foreach ($name in @('InputPath','ProfilePath','OutputPath')) { $ui[$name].Add_TextChanged({ Invalidate-Preview }) }
    foreach ($name in @('TaskChoice','ProfileChoice','GroupChoice','ConflictChoice')) { $ui[$name].Add_SelectionChanged({ Invalidate-Preview }) }
    foreach ($name in @('KeepZip','ScanChildren')) { $ui[$name].Add_Click({ Invalidate-Preview }) }
    $window.Add_PreviewDragOver({
        param($sender,$event)
        $event.Effects = if (-not $state.Busy -and $event.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { 'Copy' } else { 'None' }
        $event.Handled = $true
    })
    $window.Add_PreviewDrop({
        param($sender,$event)
        $event.Handled = $true
        if ($state.Busy -or -not $event.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { return }
        $paths = @($event.Data.GetData([Windows.DataFormats]::FileDrop))
        Set-SelectedPaths $paths
    })
    $window.Add_Closing({ param($sender,$event)
        if ($state.Busy) { $event.Cancel = $true; $ui.StatusText.Text = 'Please wait for this operation to finish before closing.' }
    })
    $window.Add_Closed({ $timer.Stop(); $discoveryTimer.Stop(); if ($state.DiscoveryWorker) { $state.DiscoveryWorker.Stop(); $state.DiscoveryWorker.Dispose() } })
    if (-not $SmokeTest) {
        if (-not $Path -and $env:LMS_ARGUMENTS) {
            [string[]]$launchArgs = ([Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($env:LMS_ARGUMENTS)) | ConvertFrom-Json)
            if ($launchArgs.Count -gt 1) { throw 'Open the desktop app with no arguments, or pass one folder or ZIP path.' }
            if ($launchArgs.Count -eq 1) { $Path = $launchArgs[0] }
        }
        if ([IO.File]::Exists($shortcut)) { $ui.RemoveShortcutButton.Visibility = 'Visible' }
    }
    if ($Path -eq '--verify-startup') {
        Import-Module (Join-Path $PSScriptRoot 'LmsUnpacker.psm1') -Force
        Import-Module (Join-Path $PSScriptRoot 'DesktopIntegration.psm1') -Force
        $null = Test-LmsProfile (Join-Path $PSScriptRoot 'profiles\nust.json')
        if (-not [IO.File]::Exists((Join-Path $PSScriptRoot 'START-HERE.html'))) { throw 'Embedded guide is missing.' }
        exit 0
    }
    if (-not $SmokeTest) {
        $startup=Get-LmsStartupSelection $Path $state.LaunchFolder $savedPreferences.Path
        $ui.InputPath.Text=$startup.Path
        Request-ZipDiscovery -StartupCandidates $startup.Candidates
    } elseif ($Path) { $ui.InputPath.Text=$Path }
    Update-Hints
    if ($SmokeTest) {
        # Real WPF controls and the asynchronous engine, without showing a window or launching external apps.
        & (Join-Path $PSScriptRoot 'tests\Test-Desktop.ps1')
    } else {
        $window.Add_ContentRendered({ $null = $ui.FolderButton.Focus() })
        $null = $window.ShowDialog()
    }
} catch {
    if ($SmokeTest) { throw }
    $null = [Windows.MessageBox]::Show($_.Exception.Message,'LMS Unpacker could not open','OK','Error')
    exit 1
}
