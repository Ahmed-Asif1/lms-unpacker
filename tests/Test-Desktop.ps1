# Called by Start-Desktop.ps1 -SmokeTest in its UI context. No real user folders or shortcuts are changed.
$fixtureRoot = Join-Path $PSScriptRoot ('.runs\desktop-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($fixtureRoot)
$desktopPassed = 0
function Check-Desktop($Condition,[string]$Message) { if (-not $Condition) { throw "Desktop check failed: $Message" } }
function Click-Control([string]$Name) { $ui[$Name].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent)) }
function Wait-Desktop {
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while ($state.Busy -and [DateTime]::UtcNow -lt $deadline) {
        $frame = [Windows.Threading.DispatcherFrame]::new()
        $pulse = [Windows.Threading.DispatcherTimer]::new()
        $pulse.Interval = [TimeSpan]::FromMilliseconds(20)
        $pulse.Tag = $frame
        $pulse.Add_Tick({ param($sender,$event); $sender.Stop(); $sender.Tag.Continue = $false })
        $pulse.Start()
        [Windows.Threading.Dispatcher]::PushFrame($frame)
    }
    Check-Desktop (-not $state.Busy) 'background operation timed out'
}
function Make-DesktopZip([string]$ZipPath,[string]$Entry,[string]$Content) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::Open($ZipPath,'Create')
    try { $writer = [IO.StreamWriter]::new($archive.CreateEntry($Entry).Open()); try { $writer.Write($Content) } finally { $writer.Dispose() } }
    finally { $archive.Dispose() }
}
try {
    $ui.InputPath.Text = $fixtureRoot
    Check-Desktop (-not $ui.ApplyButton.IsEnabled -and -not $ui.KeepZip.IsChecked -and $ui.ConflictChoice.SelectedIndex -eq 0) 'initial defaults'
    Make-DesktopZip (Join-Path $fixtureRoot 'download.zip') 'section/Lecture 1.pdf' 'fixture'
    Click-Control PreviewButton
    Check-Desktop ($state.Busy -and $ui.FeedbackTitle.Text -eq 'Building your preview...' -and $ui.BusyProgress.IsIndeterminate -and $window.TaskbarItemInfo.ProgressState -eq 'Indeterminate') 'immediate preview feedback before worker finishes'
    Wait-Desktop
    Check-Desktop ($ui.FeedbackTitle.Text -eq 'Preview ready - no files changed' -and $ui.ResultOpenButton.Visibility -eq 'Collapsed') 'preview must not look like completed extraction'
    Check-Desktop ($ui.ApplyButton.IsEnabled -and $ui.PlanGrid.Items.Count -eq 1) ('preview failed: ' + $ui.ActivityText.Text)
    if ($RenderPath) {
        $content = $window.Content
        $content.Measure([Windows.Size]::new(1072,704))
        $content.Arrange([Windows.Rect]::new(0,0,1072,704))
        $content.UpdateLayout()
        $bitmap = [Windows.Media.Imaging.RenderTargetBitmap]::new(1072,704,96,96,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($content)
        $encoder = [Windows.Media.Imaging.PngBitmapEncoder]::new()
        $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $imageFile = [IO.File]::Create($RenderPath)
        try { $encoder.Save($imageFile) } finally { $imageFile.Dispose() }
    }
    Check-Desktop ([IO.File]::Exists((Join-Path $fixtureRoot 'download.zip')) -and -not [IO.File]::Exists((Join-Path $fixtureRoot 'Lecture 1.pdf'))) 'preview wrote files'
    $ui.ConflictChoice.SelectedIndex = 1
    Check-Desktop (-not $ui.ApplyButton.IsEnabled) 'changing options did not invalidate preview'
    $ui.ConflictChoice.SelectedIndex = 0
    Click-Control PreviewButton; Wait-Desktop
    Click-Control ApplyButton
    Check-Desktop ($state.Busy -and $ui.FeedbackTitle.Text -eq 'Unpacking your files...' -and $ui.ApplyButton.Content -eq 'Working...' -and -not $ui.OpenFolderButton.IsEnabled) 'immediate extraction feedback and disabled actions'
    Wait-Desktop
    Check-Desktop ([IO.File]::Exists((Join-Path $fixtureRoot 'Lecture 1.pdf')) -and -not [IO.File]::Exists((Join-Path $fixtureRoot 'download.zip'))) ('apply failed: ' + $ui.ActivityText.Text)
    Check-Desktop (-not $ui.ApplyButton.IsEnabled) 'apply should require a fresh preview'
    Check-Desktop ($ui.FeedbackTitle.Text -eq 'Done - your files are ready' -and $ui.SummaryText.Text -like '*Extracted: 1*permanently deleted*' -and $ui.ResultOpenButton.Visibility -eq 'Visible' -and $ui.BusyProgress.Visibility -eq 'Collapsed' -and $window.TaskbarItemInfo.ProgressState -eq 'None') 'persistent completion summary, result action and stopped progress'
    if ($RenderPath) {
        $window.Content.UpdateLayout()
        $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(1072,704,96,96,[Windows.Media.PixelFormats]::Pbgra32)
        $bitmap.Render($window.Content)
        $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
        $imageFile=[IO.File]::Create($RenderPath+'.done.png'); try { $encoder.Save($imageFile) } finally { $imageFile.Dispose() }
    }
    Write-Host 'PASS: Desktop preview, setting invalidation, default extraction and ZIP deletion'; $desktopPassed++

    Make-DesktopZip (Join-Path $fixtureRoot 'structure.zip') 'nested/linked.txt' 'fixture'
    $ui.TaskChoice.SelectedIndex = 1
    $ui.KeepZip.IsChecked = $true
    Invalidate-Preview
    Click-Control PreviewButton; Wait-Desktop
    Click-Control ApplyButton; Wait-Desktop
    Check-Desktop ([IO.File]::Exists((Join-Path $fixtureRoot 'structure\nested\linked.txt')) -and [IO.File]::Exists((Join-Path $fixtureRoot 'structure.zip'))) 'just-unzip or keep ZIP failed'
    Check-Desktop ($ui.SummaryText.Text -like '*Source ZIPs were kept*') 'completion must report chosen archive retention'
    Write-Host 'PASS: Desktop just-unzip preserves hierarchy and optional source ZIP'; $desktopPassed++

    $calculus = Join-Path $fixtureRoot 'Calculus'
    $null = [IO.Directory]::CreateDirectory($calculus)
    [IO.File]::WriteAllText((Join-Path $calculus 'Continuity.pdf'),'fixture')
    $ui.InputPath.Text = $calculus
    $ui.TaskChoice.SelectedIndex = 3
    $ui.ProfileChoice.SelectedIndex = 1
    $ui.GroupChoice.SelectedIndex = 2
    Click-Control PreviewButton; Wait-Desktop
    Check-Desktop ($ui.ApplyButton.IsEnabled -and $ui.PlanGrid.Items[0].Destination -like '*Limits and continuity*') ('topic preview failed: ' + $ui.ActivityText.Text)
    Click-Control ApplyButton; Wait-Desktop
    $journal = (Get-ChildItem -LiteralPath (Join-Path $calculus '.lms-unpacker\history') -Filter '*.json').FullName
    Check-Desktop ($ui.JournalText.Visibility -eq 'Visible') 'undo record not displayed'
    $history=@(Get-OrganizationHistory @($calculus,$calculus))
    Check-Desktop ($history.Count -eq 1 -and $history[0].CanPreview -and $history[0].Remaining -eq 1 -and $history[0].Path -eq $journal) 'history must find and deduplicate available records'
    Show-HistoryDialog $window @($calculus) {
        param($historyWindow,$records)
        $records.SelectedIndex=0
        Check-Desktop ($records.Items.Count -eq 1 -and $historyWindow.FindName('Preview').IsEnabled) 'history selection must enable preview'
    }
    $state.UndoPath = $journal
    Start-Work 'UndoPreview' @{} $journal; Wait-Desktop
    Check-Desktop $ui.ApplyButton.IsEnabled ('undo preview failed: ' + $ui.ActivityText.Text)
    Click-Control ApplyButton; Wait-Desktop
    Check-Desktop ([IO.File]::Exists((Join-Path $calculus 'Continuity.pdf'))) ('undo failed: ' + $ui.ActivityText.Text)
    $history=@(Get-OrganizationHistory @($calculus))
    Check-Desktop (-not $history[0].CanPreview -and $history[0].Remaining -eq 0) 'history must reflect completed undo'
    $badRecord=Join-Path $calculus '.lms-unpacker/history/broken.json'
    [IO.File]::WriteAllText($badRecord,'{broken')
    $history=@(Get-OrganizationHistory @($calculus))
    Check-Desktop (@($history | Where-Object Status -eq 'Unreadable record').Count -eq 1) 'malformed history must be visible but not usable'
    Write-Host 'PASS: Desktop syllabus topic organization and previewed undo'; $desktopPassed++

    $ui.InputPath.Text = Join-Path $fixtureRoot 'bad.zip'
    [IO.File]::WriteAllText($ui.InputPath.Text,'not a zip')
    $ui.TaskChoice.SelectedIndex = 0
    Click-Control PreviewButton; Wait-Desktop
    Check-Desktop (-not $ui.ApplyButton.IsEnabled -and $ui.ResultsTabs.SelectedIndex -eq 1 -and $ui.ActivityText.Text -match 'ERROR') 'archive error not surfaced'
    Check-Desktop ($ui.FeedbackTitle.Text -like 'Needs attention*' -and $ui.ResultOpenButton.Visibility -eq 'Collapsed' -and $window.TaskbarItemInfo.ProgressState -eq 'Error') 'errors must never show success feedback'
    Check-Desktop ([IO.File]::Exists($ui.InputPath.Text)) 'failed ZIP was deleted'
    Write-Host 'PASS: Desktop errors keep ZIPs and disable Apply'; $desktopPassed++
    $queueA=Join-Path $fixtureRoot 'queue-a.zip'; $queueB=Join-Path $fixtureRoot 'queue-b.zip'
    Make-DesktopZip $queueA 'same.txt' 'first'; Make-DesktopZip $queueB 'same.txt' 'second'
    Set-SelectedPaths @($queueA,$queueB)
    $ui.OutputPath.Text=Join-Path $fixtureRoot 'elsewhere'
    $ui.KeepZip.IsChecked=$false; Invalidate-Preview
    Click-Control PreviewButton; Wait-Desktop
    Check-Desktop ($ui.ApplyButton.IsEnabled -and $ui.PlanGrid.Items.Count -eq 2 -and $ui.PlanGrid.Items[1].Action -eq 'Skip') ('queue shared preview failed: '+$ui.ActivityText.Text)
    $ui.PlanGrid.SelectedIndex=1
    Check-Desktop ($ui.PlanGrid.Items[1].Comparison -like 'Different content*earlier planned output*' -and $ui.FileDetails.Text.Contains($queueB) -and $ui.FileDetails.Text.Contains('6 bytes')) 'conflict details need correct planned origin, archive and size'
    Check-Desktop (-not [IO.Directory]::Exists($ui.OutputPath.Text)) 'queue preview created output'
    Click-Control ApplyButton; Wait-Desktop
    Check-Desktop ([IO.File]::ReadAllText((Join-Path $ui.OutputPath.Text 'same.txt')) -eq 'first' -and -not [IO.File]::Exists($queueA) -and -not [IO.File]::Exists($queueB)) ('queue apply failed: '+$ui.ActivityText.Text)
    Write-Host 'PASS: Multiple ZIP queue, shared collision plan and output picker'; $desktopPassed++

    $ui.WorkspaceName.Text='Test workspace'
    $ui.TaskChoice.SelectedIndex=2; $ui.ProfileChoice.SelectedIndex=1; $ui.GroupChoice.SelectedIndex=2
    $saved=Get-WorkspaceSnapshot 'Test workspace'
    Set-SelectedPaths @($fixtureRoot); $ui.OutputPath.Text=''; $ui.TaskChoice.SelectedIndex=0
    Restore-Workspace $saved
    Check-Desktop ($ui.InputPath.Text -eq $queueA -and $ui.QueueList.Items[0] -eq $queueB -and $ui.OutputPath.Text.EndsWith('elsewhere') -and $ui.TaskChoice.SelectedIndex -eq 2 -and $ui.GroupChoice.SelectedIndex -eq 2 -and -not $ui.ApplyButton.IsEnabled) 'workspace restore and preview invalidation'
    Write-Host 'PASS: Saved workspace round trip with queue and organization settings'; $desktopPassed++

    Set-SelectedPaths @('first.zip','second.zip','third.zip')
    $ui.QueueList.SelectedIndex=1; Click-Control QueueUpButton
    Check-Desktop ($ui.QueueList.Items[0] -eq 'third.zip') 'queue move up'
    Click-Control QueueDownButton
    Check-Desktop ($ui.QueueList.Items[1] -eq 'third.zip') 'queue move down'
    Click-Control QueueFirstButton
    Check-Desktop ($ui.InputPath.Text -eq 'third.zip' -and $ui.QueueList.Items[1] -eq 'first.zip') 'queue promote must retain old first input'
    Click-Control QueueRemoveButton
    Check-Desktop ($ui.QueueList.Items.Count -eq 1 -and $ui.QueueList.Items[0] -eq 'second.zip' -and -not $ui.ApplyButton.IsEnabled) 'queue remove and invalidate'
    $ui.QueueList.SelectedIndex=0; Click-Control QueueUpButton
    Check-Desktop ($ui.InputPath.Text -eq 'second.zip' -and $ui.QueueList.Items[0] -eq 'third.zip') 'move up at queue boundary must swap first input'
    Write-Host 'PASS: Queue reordering, promotion, removal and preview invalidation'; $desktopPassed++

    Import-Module (Join-Path $PSScriptRoot '../LmsUnpacker.psm1') -Force
    $seed=[pscustomobject]@{Course='MATH-101'; Pattern='mystery.pdf'; Folder='Lectures/Unscheduled'; Topic='New topic'; Reason='Manual assignment'}
    Show-ProfileEditor $window (Join-Path $PSScriptRoot '../profiles/nust.json') $seed {
        param($editor,$courses,$rules)
        Check-Desktop ($courses.Rows.Count -eq 6 -and $rules.Rows[0].Pattern -eq 'mystery.pdf') 'profile editor must load courses and prepend review rule'
        Check-Desktop ($editor.FindName('Rules').Columns.Count -eq 5 -and $editor.FindName('Courses').Columns.Count -eq 3) 'profile controls missing'
        Check-Desktop ($editor.FindName('Save').Content -eq '_Save profile copy...') 'profile editor text must decode correctly in Windows PowerShell 5.1'
    }
    Write-Host 'PASS: Native profile editor loads courses and seeded review rules'; $desktopPassed++

    Make-DesktopZip $queueA 'new.txt' 'first'; Make-DesktopZip $queueB 'other.txt' 'second'
    Set-SelectedPaths @($queueA,$queueB); $ui.TaskChoice.SelectedIndex=0
    Start-Work 'Apply' (Get-Options) $null
    Click-Control CancelButton
    Wait-Desktop
    Check-Desktop (-not $ui.ApplyButton.IsEnabled -and $ui.StatusText.Text -like 'Cancelled safely*' -and [IO.File]::Exists($queueB)) ('safe cancellation failed: '+$ui.ActivityText.Text)
    Check-Desktop ($ui.FeedbackTitle.Text -like 'Stopped safely*' -and $ui.SummaryText.Text -like '*Unprocessed ZIPs were kept*') 'cancellation needs distinct completion feedback'
    Write-Host 'PASS: Cancel queue cooperatively and retain unprocessed ZIPs'; $desktopPassed++

    Set-SelectedPaths @($fixtureRoot,$queueB)
    Click-Control PreviewButton; Wait-Desktop
    Check-Desktop (-not $ui.ApplyButton.IsEnabled -and $ui.ActivityText.Text -match 'overlap') 'overlapping queue scopes must fail before apply'
    Write-Host 'PASS: Overlapping queue paths rejected before mutation'; $desktopPassed++
    $state.Elapsed=[Diagnostics.Stopwatch]::StartNew(); $state.LastFeedback=-1000; $state.Operation='Apply'
    $state.Control=@{CancelRequested=$false; Phase='Writing verified files'; Current='lecture.pdf'; Completed=2; Total=4; QueueIndex=1; QueueTotal=2; ArchiveIndex=2; ArchiveTotal=3}
    Update-Feedback
    Check-Desktop ($ui.SummaryText.Text -like '*Input 1 of 2*ZIP 2 of 3*2 of 4 entries in this phase*Elapsed*' -and $ui.WorkItemText.Text -eq 'lecture.pdf' -and $window.TaskbarItemInfo.ProgressValue -eq 0.5) 'current phase progress must not pretend to be whole queue completion'
    $state.Elapsed.Stop(); Reset-Feedback
    Complete-Feedback ([pscustomobject]@{Preview=$true; Cancelled=$true})
    Check-Desktop ($ui.FeedbackTitle.Text -eq 'Preview stopped - no files changed' -and $ui.ResultOpenButton.Visibility -eq 'Collapsed') 'cancelled preview must not claim files were changed'
    Reset-Feedback
    Write-Host 'PASS: Phase progress, taskbar state, elapsed time and completion feedback'; $desktopPassed++
    Write-Host "All $desktopPassed desktop flow tests passed."
} finally {
    if ($state.Busy -and $state.Worker) { $state.Worker.Stop(); $state.Worker.Dispose(); $state.Busy = $false }
    $timer.Stop()
    $resolvedFixture = [IO.Path]::GetFullPath($fixtureRoot)
    $safePrefix = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.runs')).TrimEnd('\') + '\'
    if ($resolvedFixture.StartsWith($safePrefix,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolvedFixture) -like 'desktop-*') {
        Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
    }
}
