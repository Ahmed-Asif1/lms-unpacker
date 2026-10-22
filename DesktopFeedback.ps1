function Set-FeedbackStyle([string]$Kind) {
    if ([Windows.SystemParameters]::HighContrast) { return }
    $colors=switch ($Kind) {
        'Success' { @('#EAF5EE','#14634B') }
        'Error' { @('#FFF0EC','#A33322') }
        'Cancelled' { @('#FFF6DD','#795500') }
        'Working' { @('#EAF2FA','#235B87') }
        default { @('#F5F5F0','#66736D') }
    }
    $ui.FeedbackPanel.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[0])
    $ui.FeedbackPanel.BorderBrush=[Windows.Media.BrushConverter]::new().ConvertFromString($colors[1])
}
function Reset-Feedback {
    $ui.FeedbackTitle.Text='Ready to preview'
    $ui.WorkItemText.Text=''
    $ui.ResultOpenButton.Visibility='Collapsed'
    $ui.BusyProgress.Visibility='Collapsed'
    $window.Title='LMS Unpacker'
    $window.TaskbarItemInfo.ProgressState='None'
    Set-FeedbackStyle 'Ready'
}
function Start-Feedback([string]$Operation,[hashtable]$Options) {
    $state.Elapsed=[Diagnostics.Stopwatch]::StartNew()
    $state.LastFeedback=-1000
    $state.KeepZipForRun=[bool]$Options.KeepZip
    $ui.ResultOpenButton.Visibility='Collapsed'
    $ui.WorkItemText.Text='Preparing the selected files...'
    $ui.BusyProgress.IsIndeterminate=$true
    $ui.BusyProgress.Value=0
    $window.TaskbarItemInfo.ProgressState='Indeterminate'
    $ui.FeedbackTitle.Text=if ($Operation -like '*Preview') { 'Building your preview...' } elseif ($Operation -eq 'UndoApply') { 'Restoring original locations...' } elseif ($Options.ExistingOnly) { 'Organizing your documents...' } else { 'Unpacking your files...' }
    $ui.SummaryText.Text=if ($Operation -like '*Preview') { 'Reading and checking files. Your materials will not be changed.' } else { 'Please keep the app open. Progress is shown for each phase as files are checked and written.' }
    $window.Title=$ui.FeedbackTitle.Text+' - LMS Unpacker'
    Set-FeedbackStyle 'Working'
}
function Update-Feedback {
    if (-not $state.Elapsed -or $state.Elapsed.ElapsedMilliseconds-$state.LastFeedback -lt 500) { return }
    $state.LastFeedback=$state.Elapsed.ElapsedMilliseconds
    $p=$state.Control
    $elapsed=$state.Elapsed.Elapsed.ToString('mm\:ss')
    if ($p.CancelRequested) {
        $ui.FeedbackTitle.Text='Stopping safely...'
        $ui.SummaryText.Text="Finishing the current safe boundary. Unprocessed ZIPs will be kept. Elapsed $elapsed."
        $window.TaskbarItemInfo.ProgressState='Paused'
        return
    }
    $parts=@($p.Phase)
    if ($state.Operation -notlike 'Undo*') { $parts += "Input $([Math]::Max(1,$p.QueueIndex)) of $($p.QueueTotal)" }
    if ($p.ArchiveTotal -gt 0) { $parts += "ZIP $($p.ArchiveIndex) of $($p.ArchiveTotal)" }
    if ($p.Total -gt 0) {
        $parts += "$($p.Completed) of $($p.Total) entries in this phase"
        $window.TaskbarItemInfo.ProgressState='Normal'
        $window.TaskbarItemInfo.ProgressValue=[Math]::Min(1.0,[double]$p.Completed / $p.Total)
    } else { $window.TaskbarItemInfo.ProgressState='Indeterminate' }
    $parts += "Elapsed $elapsed"
    $ui.SummaryText.Text=$parts -join ' | '
    $ui.WorkItemText.Text=[string]$p.Current
}
function Complete-Feedback($Result) {
    $state.Elapsed.Stop()
    $duration=if ($state.Elapsed.Elapsed.TotalSeconds -lt 60) { '{0:0.0} seconds' -f $state.Elapsed.Elapsed.TotalSeconds } else { $state.Elapsed.Elapsed.ToString('hh\:mm\:ss') }
    $window.TaskbarItemInfo.ProgressState='None'
    $ui.WorkItemText.Text='Elapsed '+$duration
    $ui.ResultOpenButton.Visibility='Collapsed'
    if ($Result.PSObject.Properties['Cancelled'] -and $Result.Cancelled) {
        if ($Result.Preview) {
            $ui.FeedbackTitle.Text='Preview stopped - no files changed'
            $ui.SummaryText.Text='The partial plan has been discarded. Preview again when you are ready.'
        } else {
            $ui.FeedbackTitle.Text='Stopped safely - some work may be complete'
            $ui.SummaryText.Text="Completed before stopping: $($Result.Archives) ZIPs, $($Result.Written) extracted, $($Result.Skipped) skipped, $($Result.Moved) organized. Unprocessed ZIPs were kept. Preview again to continue."
        }
        Set-FeedbackStyle 'Cancelled'
    } elseif ($Result.Preview) {
        $ui.FeedbackTitle.Text=if ($ui.ApplyButton.IsEnabled) { 'Preview ready - no files changed' } else { 'Nothing to apply' }
        Set-FeedbackStyle 'Ready'
    } elseif ($state.Operation -eq 'UndoApply') {
        $ui.FeedbackTitle.Text='Done - original locations restored'
        Set-FeedbackStyle 'Success'
    } else {
        $ui.FeedbackTitle.Text='Done - your files are ready'
        $zipStatus=if ($state.KeepZipForRun) { 'Source ZIPs were kept.' } elseif ($Result.Archives -gt 0) { 'Successfully processed ZIPs were permanently deleted, including skipped incoming files.' } else { 'No ZIPs were processed.' }
        $ui.SummaryText.Text="ZIPs processed: $($Result.Archives) | Extracted: $($Result.Written) | Skipped: $($Result.Skipped) | Organized: $($Result.Moved) | Unclassified: $($Result.Unclassified). $zipStatus"
        $ui.ResultOpenButton.Content=if ($state.Control.QueueTotal -gt 1) { '_Open first result folder' } else { '_Open result folder' }
        $ui.ResultOpenButton.Visibility='Visible'
        Set-FeedbackStyle 'Success'
    }
    $window.Title=$ui.FeedbackTitle.Text+' - LMS Unpacker'
}
function Stop-FeedbackWithError {
    if ($state.Elapsed) { $state.Elapsed.Stop() }
    $ui.FeedbackTitle.Text='Needs attention - processing stopped'
    $ui.SummaryText.Text='Some files may already have been processed. Affected ZIPs were kept. See Activity and errors before trying again.'
    $ui.WorkItemText.Text=''
    $ui.ResultOpenButton.Visibility='Collapsed'
    $window.Title='Needs attention - LMS Unpacker'
    $window.TaskbarItemInfo.ProgressState='Error'
    $window.TaskbarItemInfo.ProgressValue=1
    Set-FeedbackStyle 'Error'
}
$ui.ResultOpenButton.Add_Click({ $ui.OpenFolderButton.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) })
