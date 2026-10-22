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
    Wait-Desktop
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
    Click-Control ApplyButton; Wait-Desktop
    Check-Desktop ([IO.File]::Exists((Join-Path $fixtureRoot 'Lecture 1.pdf')) -and -not [IO.File]::Exists((Join-Path $fixtureRoot 'download.zip'))) ('apply failed: ' + $ui.ActivityText.Text)
    Check-Desktop (-not $ui.ApplyButton.IsEnabled) 'apply should require a fresh preview'
    Write-Host 'PASS: Desktop preview, setting invalidation, default extraction and ZIP deletion'; $desktopPassed++

    Make-DesktopZip (Join-Path $fixtureRoot 'structure.zip') 'nested/linked.txt' 'fixture'
    $ui.TaskChoice.SelectedIndex = 1
    $ui.KeepZip.IsChecked = $true
    Invalidate-Preview
    Click-Control PreviewButton; Wait-Desktop
    Click-Control ApplyButton; Wait-Desktop
    Check-Desktop ([IO.File]::Exists((Join-Path $fixtureRoot 'structure\nested\linked.txt')) -and [IO.File]::Exists((Join-Path $fixtureRoot 'structure.zip'))) 'just-unzip or keep ZIP failed'
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
    $state.UndoPath = $journal
    Start-Work 'UndoPreview' @{} $journal; Wait-Desktop
    Check-Desktop $ui.ApplyButton.IsEnabled ('undo preview failed: ' + $ui.ActivityText.Text)
    Click-Control ApplyButton; Wait-Desktop
    Check-Desktop ([IO.File]::Exists((Join-Path $calculus 'Continuity.pdf'))) ('undo failed: ' + $ui.ActivityText.Text)
    Write-Host 'PASS: Desktop syllabus topic organization and previewed undo'; $desktopPassed++

    $ui.InputPath.Text = Join-Path $fixtureRoot 'bad.zip'
    [IO.File]::WriteAllText($ui.InputPath.Text,'not a zip')
    $ui.TaskChoice.SelectedIndex = 0
    Click-Control PreviewButton; Wait-Desktop
    Check-Desktop (-not $ui.ApplyButton.IsEnabled -and $ui.ResultsTabs.SelectedIndex -eq 1 -and $ui.ActivityText.Text -match 'ERROR') 'archive error not surfaced'
    Check-Desktop ([IO.File]::Exists($ui.InputPath.Text)) 'failed ZIP was deleted'
    Write-Host 'PASS: Desktop errors keep ZIPs and disable Apply'; $desktopPassed++
    $queueA=Join-Path $fixtureRoot 'queue-a.zip'; $queueB=Join-Path $fixtureRoot 'queue-b.zip'
    Make-DesktopZip $queueA 'same.txt' 'first'; Make-DesktopZip $queueB 'same.txt' 'second'
    Set-SelectedPaths @($queueA,$queueB)
    $ui.OutputPath.Text=Join-Path $fixtureRoot 'elsewhere'
    $ui.KeepZip.IsChecked=$false; Invalidate-Preview
    Click-Control PreviewButton; Wait-Desktop
    Check-Desktop ($ui.ApplyButton.IsEnabled -and $ui.PlanGrid.Items.Count -eq 2 -and $ui.PlanGrid.Items[1].Action -eq 'Skip') ('queue shared preview failed: '+$ui.ActivityText.Text)
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

    Import-Module (Join-Path $PSScriptRoot '../LmsUnpacker.psm1') -Force
    $seed=[pscustomobject]@{Course='MATH-101'; Pattern='mystery.pdf'; Folder='Lectures/Unscheduled'; Topic='New topic'; Reason='Manual assignment'}
    Show-ProfileEditor $window (Join-Path $PSScriptRoot '../profiles/nust.json') $seed {
        param($editor,$courses,$rules)
        Check-Desktop ($courses.Rows.Count -eq 6 -and $rules.Rows[0].Pattern -eq 'mystery.pdf') 'profile editor must load courses and prepend review rule'
        Check-Desktop ($editor.FindName('Rules').Columns.Count -eq 5 -and $editor.FindName('Courses').Columns.Count -eq 3) 'profile controls missing'
    }
    Write-Host 'PASS: Native profile editor loads courses and seeded review rules'; $desktopPassed++

    Make-DesktopZip $queueA 'new.txt' 'first'; Make-DesktopZip $queueB 'other.txt' 'second'
    Set-SelectedPaths @($queueA,$queueB); $ui.TaskChoice.SelectedIndex=0
    Start-Work 'Apply' (Get-Options) $null
    Click-Control CancelButton
    Wait-Desktop
    Check-Desktop (-not $ui.ApplyButton.IsEnabled -and $ui.StatusText.Text -like 'Cancelled safely*' -and [IO.File]::Exists($queueB)) ('safe cancellation failed: '+$ui.ActivityText.Text)
    Write-Host 'PASS: Cancel queue cooperatively and retain unprocessed ZIPs'; $desktopPassed++

    Set-SelectedPaths @($fixtureRoot,$queueB)
    Click-Control PreviewButton; Wait-Desktop
    Check-Desktop (-not $ui.ApplyButton.IsEnabled -and $ui.ActivityText.Text -match 'overlap') 'overlapping queue scopes must fail before apply'
    Write-Host 'PASS: Overlapping queue paths rejected before mutation'; $desktopPassed++
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
