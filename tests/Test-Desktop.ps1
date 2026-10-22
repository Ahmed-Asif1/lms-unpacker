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
