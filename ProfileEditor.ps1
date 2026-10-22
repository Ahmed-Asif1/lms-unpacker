# Visual editor; saves a validated copy so shipped profiles and previous versions survive.
function Save-VisualProfile([string]$Destination, $Courses, $Rules) {
    Import-Module (Join-Path $PSScriptRoot 'LmsUnpacker.psm1') -Force
    $model = @{Version=1; Courses=@($Courses); Rules=@($Rules)}
    $temporary = Join-Path ([IO.Path]::GetTempPath()) ('lms-profile-' + [guid]::NewGuid().ToString('N') + '.json')
    try {
        [IO.File]::WriteAllText($temporary,($model | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
        $null = Test-LmsProfile $temporary
        [IO.File]::Copy($temporary,$Destination,$false)
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}

function Show-ProfileEditor($Owner, [string]$ProfilePath, $Seed, [scriptblock]$Inspect) {
    [xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="Course and syllabus editor" Width="940" Height="640" MinWidth="700" MinHeight="460" WindowStartupLocation="CenterOwner" FontFamily="Segoe UI" FontSize="14">
 <Grid Margin="18"><Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
 <TextBlock Text="Create rules for any course. Add rows at the bottom; select a row and press Delete to remove it. Save a copy, then preview before applying." TextWrapping="Wrap" Margin="0,0,0,14"/>
 <TabControl Grid.Row="1">
  <TabItem Header="_Courses"><DataGrid x:Name="Courses" AutoGenerateColumns="False" CanUserAddRows="True" CanUserDeleteRows="True" AutomationProperties.Name="Course mappings"><DataGrid.Columns>
   <DataGridTextColumn Header="Code (e.g. BIO-101)" Binding="{Binding Code}" Width="180"/><DataGridTextColumn Header="Folder (e.g. Biology)" Binding="{Binding Folder}" Width="220"/><DataGridTextColumn Header="Course name" Binding="{Binding Name}" Width="*"/>
  </DataGrid.Columns></DataGrid></TabItem>
  <TabItem Header="_Syllabus rules"><DataGrid x:Name="Rules" AutoGenerateColumns="False" CanUserAddRows="True" CanUserDeleteRows="True" AutomationProperties.Name="Filename and syllabus rules"><DataGrid.Columns>
   <DataGridTextColumn Header="Course code or *" Binding="{Binding Course}" Width="120"/><DataGridTextColumn Header="Filename pattern" Binding="{Binding Pattern}" Width="180"/><DataGridTextColumn Header="Category / week folder" Binding="{Binding Folder}" Width="190"/><DataGridTextColumn Header="Topic (optional)" Binding="{Binding Topic}" Width="150"/><DataGridTextColumn Header="Reason (optional)" Binding="{Binding Reason}" Width="200"/>
  </DataGrid.Columns></DataGrid></TabItem>
 </TabControl>
 <TextBlock Grid.Row="2" Margin="0,12,0,12" TextWrapping="Wrap" Text="Example: BIO-101 | *cell* | Lectures/Week 02 | Cell biology. Use Assignments or Books for other categories. * matches any text. Rules match filenames, first match wins. New review rules are inserted first. Unknown weeks can use Lectures/Unscheduled."/>
 <DockPanel Grid.Row="3"><Button x:Name="Save" Content="_Save profile copy..." Padding="16,10" DockPanel.Dock="Right"/><TextBlock x:Name="Error" TextWrapping="Wrap" VerticalAlignment="Center" Margin="0,0,12,0" AutomationProperties.LiveSetting="Polite"/></DockPanel>
 </Grid>
</Window>
'@
    $editor = [Windows.Markup.XamlReader]::Load([Xml.XmlNodeReader]::new($markup))
    if (-not $Inspect) { $editor.Owner = $Owner }
    $editor.Width = [Math]::Min(940,[Windows.SystemParameters]::WorkArea.Width - 30)
    $editor.Height = [Math]::Min(640,[Windows.SystemParameters]::WorkArea.Height - 30)
    $coursesTable = [Data.DataTable]::new()
    foreach ($column in @('Code','Folder','Name')) { $null = $coursesTable.Columns.Add($column,[string]) }
    $rulesTable = [Data.DataTable]::new()
    foreach ($column in @('Course','Pattern','Folder','Topic','Reason')) { $null = $rulesTable.Columns.Add($column,[string]) }
    if ($ProfilePath) {
        $null = Test-LmsProfile $ProfilePath
        $profile = Get-Content -LiteralPath $ProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($course in $profile.Courses) { $row=$coursesTable.NewRow(); foreach ($c in $coursesTable.Columns) { $row[$c.ColumnName]=[string]$course.($c.ColumnName) }; $coursesTable.Rows.Add($row) }
    } else { $profile = @{Rules=@()} }
    $rules = @()
    if ($Seed) { $rules += $Seed }
    $rules += @($profile.Rules)
    foreach ($rule in $rules) { $row=$rulesTable.NewRow(); foreach ($c in $rulesTable.Columns) { $row[$c.ColumnName]=[string]$rule.($c.ColumnName) }; $rulesTable.Rows.Add($row) }
    $courseGrid = $editor.FindName('Courses'); $ruleGrid = $editor.FindName('Rules')
    $courseGrid.ItemsSource = $coursesTable.DefaultView; $ruleGrid.ItemsSource = $rulesTable.DefaultView
    if ($Seed) { $ruleGrid.Parent.IsSelected=$true }
    $saved = @{Path=$null}
    $editor.FindName('Save').Add_Click({
        try {
            foreach ($grid in @($courseGrid,$ruleGrid)) { if (-not $grid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Cell,$true) -or -not $grid.CommitEdit([Windows.Controls.DataGridEditingUnit]::Row,$true)) { throw 'Finish the current row before saving.' } }
            $courses = @($coursesTable.Rows | Where-Object { $_.RowState -ne 'Deleted' } | ForEach-Object { [pscustomobject]@{Code=[string]$_.Code; Folder=[string]$_.Folder; Name=[string]$_.Name} })
            $rules = @($rulesTable.Rows | Where-Object { $_.RowState -ne 'Deleted' } | ForEach-Object { [pscustomobject]@{Course=[string]$_.Course; Pattern=[string]$_.Pattern; Folder=[string]$_.Folder; Topic=[string]$_.Topic; Reason=[string]$_.Reason} })
            $dialog=[Microsoft.Win32.SaveFileDialog]::new(); $dialog.Filter='JSON profile (*.json)|*.json'; $dialog.FileName='my-courses.json'; $dialog.Title='Save as a new profile file'
            if (-not $dialog.ShowDialog($editor)) { return }
            Save-VisualProfile $dialog.FileName $courses $rules
            $saved.Path=$dialog.FileName; $editor.DialogResult=$true
        } catch { $editor.FindName('Error').Text=$_.Exception.Message }
    })
    if ($Inspect) { & $Inspect $editor $coursesTable $rulesTable; return }
    $null=$editor.ShowDialog()
    return $saved.Path
}
