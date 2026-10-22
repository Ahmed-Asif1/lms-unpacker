# History is an index of local organization journals. Undo validates every path and hash again.
function Test-HistoryPlainPath([string]$Path) {
    $part=[IO.Path]::GetFullPath($Path)
    while ($part) {
        if (Test-Path -LiteralPath $part) {
            if ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { return $false }
        }
        $part=[IO.Path]::GetDirectoryName($part)
    }
    return $true
}
function Get-OrganizationHistory([string[]]$Paths) {
    $seen=@{}
    foreach ($path in $Paths) {
        if (-not $path.Trim()) { continue }
        try {
            $root=[IO.Path]::GetFullPath($path.Trim().Trim('"'))
            if (-not [IO.Directory]::Exists($root)) { $root=[IO.Path]::GetDirectoryName($root) }
            $folder=Join-Path $root '.lms-unpacker/history'
            if ($seen.ContainsKey($folder) -or -not (Test-HistoryPlainPath $folder) -or -not [IO.Directory]::Exists($folder)) { continue }
            $seen[$folder]=$true
            foreach ($file in @(Get-ChildItem -LiteralPath $folder -Filter '*.json' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 500)) {
                $status='Unreadable record'; $count=0; $canPreview=$false
                try {
                    if ($file.Length -gt 10MB -or -not (Test-HistoryPlainPath $file.FullName)) { throw 'Unsafe or oversized record' }
                    $journal=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($journal.Version -ne 1 -or [IO.Path]::GetFullPath($journal.Root) -ne $root -or -not $journal.PSObject.Properties['Moves']) { throw 'Invalid record' }
                    $moves=@($journal.Moves)
                    if (@($moves | Where-Object { $_.State -notin @('Pending','Moved','Restoring','Undone') }).Count) { throw 'Unknown state' }
                    $count=@($moves | Where-Object { $_.State -ne 'Undone' }).Count
                    $status=if ($count) { 'Available for validation' } else { 'Already undone / empty' }
                    $canPreview=$count -gt 0
                } catch { }
                [pscustomobject]@{Updated=$file.LastWriteTime.ToString('yyyy-MM-dd HH:mm'); Root=$root; Remaining=$count; Status=$status; Path=$file.FullName; CanPreview=$canPreview}
            }
        } catch { }
    }
}
function Show-HistoryDialog($Owner,[string[]]$Paths,[scriptblock]$Inspect) {
    [xml]$markup=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Organization history" Width="850" Height="480" MinWidth="640" MinHeight="360" WindowStartupLocation="CenterOwner" FontFamily="Segoe UI" FontSize="14" Background="{DynamicResource {x:Static SystemColors.WindowBrushKey}}" Foreground="{DynamicResource {x:Static SystemColors.WindowTextBrushKey}}">
 <Grid Margin="18"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <TextBlock Text="Undo moves of loose documents. ZIP extraction and ZIP deletion cannot be undone here. Select a record, then preview; files and hashes are checked before any restore." TextWrapping="Wrap" Margin="0,0,0,12"/>
 <DataGrid Grid.Row="1" x:Name="Records" AutoGenerateColumns="False" IsReadOnly="True" CanUserAddRows="False" SelectionMode="Single" AutomationProperties.Name="Organization history records"><DataGrid.Columns><DataGridTextColumn Header="Updated" Binding="{Binding Updated}" Width="145"/><DataGridTextColumn Header="Folder" Binding="{Binding Root}" Width="*"/><DataGridTextColumn Header="Remaining" Binding="{Binding Remaining}" Width="85"/><DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="190"/></DataGrid.Columns></DataGrid>
 <TextBlock Grid.Row="2" x:Name="Hint" TextWrapping="Wrap" Margin="0,10" AutomationProperties.LiveSetting="Polite"/>
 <WrapPanel Grid.Row="3"><Button x:Name="Preview" Content="_Preview undo" Padding="14,9" Margin="0,0,8,0" IsEnabled="False"/><Button x:Name="Folder" Content="Choose another _folder..." Padding="14,9" Margin="0,0,8,0"/><Button x:Name="Browse" Content="Browse _record..." Padding="14,9" Margin="0,0,8,0"/><Button Content="_Cancel" IsCancel="True" Padding="14,9"/></WrapPanel>
 </Grid>
</Window>
'@
    $reader=[Xml.XmlNodeReader]::new($markup)
    try { $dialog=[Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Close() }
    $records=$dialog.FindName('Records'); $hint=$dialog.FindName('Hint'); $preview=$dialog.FindName('Preview')
    $records.ItemsSource=@(Get-OrganizationHistory $Paths)
    $hint.Text='Showing up to 500 recent records per selected folder. If no records appear, choose the folder you originally organized.'
    $records.Add_SelectionChanged({ $preview.IsEnabled=$null -ne $records.SelectedItem -and $records.SelectedItem.CanPreview; if ($records.SelectedItem) { $hint.Text=$records.SelectedItem.Path } })
    $preview.Add_Click({ if ($records.SelectedItem.CanPreview) { $dialog.Tag=$records.SelectedItem.Path; $dialog.DialogResult=$true } })
    $dialog.FindName('Folder').Add_Click({
        $picker=[Windows.Forms.FolderBrowserDialog]::new(); $picker.Description='Choose the folder originally organized'; $picker.ShowNewFolderButton=$false
        try { if ($picker.ShowDialog() -eq 'OK') { $records.ItemsSource=@(Get-OrganizationHistory @($picker.SelectedPath)); $hint.Text='Select a record to preview undo. Only this folder is searched.' } } finally { $picker.Dispose() }
    })
    $dialog.FindName('Browse').Add_Click({
        $picker=[Microsoft.Win32.OpenFileDialog]::new(); $picker.Title='Choose an original organization record'; $picker.Filter='Undo records (*.json)|*.json'
        if ($picker.ShowDialog($dialog)) { $dialog.Tag=$picker.FileName; $dialog.DialogResult=$true }
    })
    if ($Inspect) { & $Inspect $dialog $records; return }
    $dialog.Owner=$Owner
    if ($dialog.ShowDialog()) { return [string]$dialog.Tag }
}
