#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\LmsUnpacker.psm1') -Force
$testRoot = Join-Path $PSScriptRoot ('.runs\lms-tests-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($testRoot)
$script:passed = 0

function Assert($Condition, [string]$Message) { if (-not $Condition) { throw "ASSERTION: $Message" } }
function New-Case([string]$Name) {
    $path = Join-Path $testRoot $Name
    $null = [IO.Directory]::CreateDirectory($path)
    return $path
}
function Write-File([string]$Path, [string]$Text) {
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path,$Text)
}
function New-Zip([string]$Path, [System.Collections.IDictionary]$Entries) {
    $zip = [IO.Compression.ZipFile]::Open($Path,'Create')
    try {
        foreach ($key in $Entries.Keys) {
            $entry = $zip.CreateEntry($key)
            if (-not $key.EndsWith('/')) {
                $writer = [IO.StreamWriter]::new($entry.Open())
                try { $writer.Write([string]$Entries[$key]) } finally { $writer.Dispose() }
            }
        }
    } finally { $zip.Dispose() }
}
function Test-Case([string]$Name, [scriptblock]$Body) {
    & $Body
    $script:passed++
    Write-Host "PASS: $Name"
}

try {
    Test-Case 'Default flattens, skips different existing content, deletes ZIP' {
        $dir = New-Case 'defaults'
        Write-File "$dir\a.txt" 'original'
        New-Zip "$dir\download.zip" ([ordered]@{'nested/a.txt'='new'; 'nested/b.txt'='second'})
        $r = Invoke-LmsUnpacker -Path $dir
        Assert ($r.Errors -eq 0 -and $r.Skipped -eq 1 -and $r.Written -eq 1) 'default counts'
        Assert ([IO.File]::ReadAllText("$dir\a.txt") -eq 'original') 'existing content changed'
        Assert ([IO.File]::ReadAllText("$dir\b.txt") -eq 'second') 'flattened file missing'
        Assert (-not (Test-Path -LiteralPath "$dir\download.zip")) 'ZIP not deleted'
    }
    Test-Case 'Preview creates nothing and models collisions across entries and archives' {
        $dir = New-Case 'preview [literal]'
        New-Zip "$dir\a.zip" ([ordered]@{'one/a.txt'='one'; 'two/a.txt'='two'})
        New-Zip "$dir\b.zip" @{'a.txt'='three'}
        $before = @(Get-ChildItem -LiteralPath $dir -Recurse | ForEach-Object { $_.FullName + (Get-FileHash -LiteralPath $_.FullName).Hash })
        $r = Invoke-LmsUnpacker -Path $dir -Preview $true
        $after = @(Get-ChildItem -LiteralPath $dir -Recurse | ForEach-Object { $_.FullName + (Get-FileHash -LiteralPath $_.FullName).Hash })
        Assert (($before -join '|') -eq ($after -join '|')) 'preview mutated inputs'
        Assert ($r.Written -eq 1 -and $r.Skipped -eq 2 -and $r.Errors -eq 0) 'preview collision accounting'
    }
    Test-Case 'Rename is repeatable and recognizes an already renamed version' {
        $dir = New-Case 'rename'
        Write-File "$dir\a.txt" 'old'
        New-Zip "$dir\a.zip" @{'nested/a.txt'='new'}
        $r = Invoke-LmsUnpacker -Path $dir -Conflict Rename -KeepZip $true
        Assert ($r.Errors -eq 0 -and (Test-Path "$dir\a_1.txt")) 'rename failed'
        $r = Invoke-LmsUnpacker -Path $dir -Conflict Rename -KeepZip $true
        Assert ($r.Written -eq 0 -and $r.Skipped -eq 1) 'rerun generated another copy'
        Assert (-not (Test-Path "$dir\a_2.txt")) 'unnecessary second version'
    }
    Test-Case 'Explicit overwrite replaces content' {
        $dir = New-Case 'overwrite'
        Write-File "$dir\a.txt" 'old'
        New-Zip "$dir\a.zip" @{'a.txt'='new'}
        $r = Invoke-LmsUnpacker -Path $dir -Conflict Overwrite
        Assert ($r.Errors -eq 0) 'overwrite error'
        Assert ([IO.File]::ReadAllText("$dir\a.txt") -eq 'new') 'overwrite not applied'
    }
    Test-Case 'Ordinary extraction preserves structure, empty folders and literal filenames' {
        $dir = New-Case 'extract'
        New-Zip "$dir\bundle.zip" ([ordered]@{'one/a[1].txt'='one'; 'two/a[1].txt'='two'; 'empty/'=''})
        $r = Invoke-LmsUnpacker -Path "$dir\bundle.zip" -Mode Extract
        Assert ($r.Errors -eq 0 -and $r.Written -eq 2) 'extract failed'
        Assert (Test-Path -LiteralPath "$dir\bundle\one\a[1].txt") 'literal file missing'
        Assert (Test-Path -LiteralPath "$dir\bundle\empty" -PathType Container) 'empty folder missing'
    }
    Test-Case 'Traversal, absolute, ADS and reserved paths rejected before writes' {
        foreach ($bad in @('../escape.txt','/absolute.txt','C:/root.txt','safe/CON.txt','safe/a.txt:stream','safe/../escape.txt','safe/trailing.')) {
            $dir = New-Case ([guid]::NewGuid().ToString('N'))
            New-Zip "$dir\bad.zip" ([ordered]@{'good.txt'='good'; $bad='bad'})
            $r = Invoke-LmsUnpacker -Path $dir
            Assert ($r.Errors -eq 1) "unsafe path accepted: $bad"
            Assert ((Test-Path "$dir\bad.zip") -and -not (Test-Path "$dir\good.txt")) 'unsafe archive modified output'
        }
    }
    Test-Case 'Broken ZIP retained while another ZIP completes' {
        $dir = New-Case 'broken'
        Write-File "$dir\a.zip" 'not an archive'
        New-Zip "$dir\b.zip" @{'good.txt'='yes'}
        $r = Invoke-LmsUnpacker -Path $dir
        Assert ($r.Errors -eq 1 -and $r.Archives -eq 1) 'failure did not isolate archive'
        Assert (Test-Path "$dir\a.zip") 'broken ZIP deleted'
    }
    Test-Case 'Entry and expanded byte limits retain source' {
        $dir = New-Case 'limits'
        New-Zip "$dir\a.zip" @{'a.txt'='12345'; 'b.txt'='67890'}
        $r = Invoke-LmsUnpacker -Path $dir -MaxEntries 1
        Assert ($r.Errors -eq 1) 'entry limit ignored'
        $r = Invoke-LmsUnpacker -Path $dir -MaxExpandedBytes 5
        Assert ($r.Errors -eq 1 -and (Test-Path "$dir\a.zip")) 'size limit ignored'
    }
    Test-Case 'File-folder conflicts reject archive before publishing files' {
        $dir = New-Case 'structural'
        New-Zip "$dir\bundle.zip" ([ordered]@{'folder'='file'; 'folder/a.txt'='nested'})
        $r = Invoke-LmsUnpacker -Path $dir -Mode Extract
        Assert ($r.Errors -eq 1 -and -not (Test-Path "$dir\bundle")) 'structural collision caused partial output'
    }
    Test-Case 'Output cannot overwrite an input archive' {
        $dir = New-Case 'self'
        New-Zip "$dir\self.zip" @{'self.zip'='pretend zip'}
        $r = Invoke-LmsUnpacker -Path $dir -Conflict Overwrite
        Assert ($r.Errors -eq 1 -and (Test-Path "$dir\self.zip")) 'source archive overwritten'
    }
    Test-Case 'Organization scopes, preview, custom rules and undo' {
        $dir = New-Case 'organize'
        Write-File "$dir\Biology\Assignment 1.pdf" 'assignment'
        Write-File "$dir\Biology\cell structure.pdf" 'cells'
        Write-File "$dir\Biology\unknown.pdf" 'unknown'
        Write-File "$dir\Biology\submission\Assignment 1.pdf" 'student'
        Write-File "$dir\Lab\Lecture 1.pdf" 'project'
        Write-File "$dir\Biology\program.cpp" 'source'
        $profile = Join-Path $dir 'profile.json'
        Write-File $profile '{"Version":1,"Courses":[{"Code":"BIO-101","Folder":"Biology"}],"Rules":[{"Course":"BIO-101","Pattern":"*cell structure*","Folder":"Lectures/Week 01"}]}'
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Week -ExistingOnly $true -RulesPath $profile -Preview $true
        Assert ($r.Errors -eq 0 -and $r.Moved -eq 2) 'organization preview wrong'
        Assert (-not (Test-Path "$dir\.lms-unpacker")) 'preview created history'
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Week -ExistingOnly $true -RulesPath $profile
        Assert ($r.Errors -eq 0 -and $r.Moved -eq 2) 'organization failed'
        Assert (Test-Path "$dir\Biology\Lectures\Week 01\cell structure.pdf") 'week rule not applied'
        Assert (Test-Path "$dir\Lab\Lecture 1.pdf") 'protected folder touched'
        Assert (Test-Path "$dir\Biology\submission\Assignment 1.pdf") 'submission touched'
        Assert (Test-Path "$dir\Biology\unknown.pdf") 'unknown moved'
        Undo-LmsOrganization -ReportPath $r.Journal -Preview
        Assert (-not (Test-Path "$dir\Biology\Assignment 1.pdf")) 'undo preview mutated files'
        Undo-LmsOrganization -ReportPath $r.Journal
        Assert (Test-Path "$dir\Biology\Assignment 1.pdf") 'undo missed assignment'
        Assert (Test-Path "$dir\Biology\cell structure.pdf") 'undo missed lecture'
        Undo-LmsOrganization -ReportPath $r.Journal
    }
    Test-Case 'Undo refuses changed files before restoring anything' {
        $dir = New-Case 'undo-changed'
        Write-File "$dir\Assignment 1.pdf" 'one'
        Write-File "$dir\Assignment 2.pdf" 'two'
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -ExistingOnly $true
        Assert ($r.Errors -eq 0 -and $r.Moved -eq 2) 'setup organization failed'
        Write-File "$dir\Assignments\Assignment 1.pdf" 'edited'
        $threw = $false
        try { Undo-LmsOrganization -ReportPath $r.Journal } catch { $threw = $true }
        Assert $threw 'modified file was undone'
        Assert (-not (Test-Path "$dir\Assignment 2.pdf")) 'undo was partially applied'
    }
    Test-Case 'Profile routes supplied LMS ZIP naming and topic weeks' {
        $dir = New-Case 'course-routing'
        New-Zip "$dir\MATH-125-F26 AB 2K26-BSCS-16_20261021_2205.zip" @{'nested/week 2.pdf'='discrete'}
        New-Zip "$dir\CS-123-F26 AB 2K26-BSCS-16_20261021_2204.zip" @{'nested/Methods of Proof Lecture.pptx'='proof'}
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Week -RulesPath (Join-Path $PSScriptRoot '..\profiles\nust.json')
        Assert ($r.Errors -eq 0 -and $r.Archives -eq 2) 'course routing failed'
        Assert (Test-Path "$dir\Discrete\Lectures\Week 02\week 2.pdf") 'Discrete route wrong'
        Assert (Test-Path "$dir\Quantitative\Lectures\Week 06\Methods of Proof Lecture.pptx") 'QR route wrong'
    }
    Test-Case 'CSV builder supports other courses and validates generated profile' {
        $dir = New-Case 'builder'
        & (Join-Path $PSScriptRoot '..\New-CourseProfile.ps1') -CoursesCsv (Join-Path $PSScriptRoot '..\profiles\courses.example.csv') -SyllabusCsv (Join-Path $PSScriptRoot '..\profiles\syllabus.example.csv') -OutputPath "$dir\custom.json"
        Assert (Test-LmsProfile "$dir\custom.json") 'generated profile invalid'
        New-Zip "$dir\BIO-101-download.zip" @{'cell structure.pdf'='cells'}
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Week -RulesPath "$dir\custom.json"
        Assert ($r.Errors -eq 0 -and (Test-Path "$dir\Biology\Lectures\Week 01\cell structure.pdf")) 'custom profile did not work'
    }
    Test-Case 'Depth zero and no ZIP are valid' {
        $dir = New-Case 'depth'
        $null = [IO.Directory]::CreateDirectory("$dir\Course")
        New-Zip "$dir\Course\a.zip" @{'a.txt'='a'}
        $r = Invoke-LmsUnpacker -Path $dir -Depth 0
        Assert ($r.Errors -eq 0 -and $r.Archives -eq 0) 'depth zero scanned child'
        $r = Invoke-LmsUnpacker -Path $dir -Depth 1
        Assert ($r.Archives -eq 1) 'depth one missed child'
    }
    Test-Case 'Category and week grouping respect LMS folder context' {
        $dir = New-Case 'grouping'
        New-Zip "$dir\a.zip" ([ordered]@{'Week 07/topic.pdf'='topic'; 'Week 07/Assignment 2.docx'='assignment'})
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Week -KeepZip $true
        Assert ($r.Errors -eq 0 -and (Test-Path "$dir\Lectures\Week 07\topic.pdf")) 'archive week context lost'
        Assert (Test-Path "$dir\Assignments\Assignment 2.docx") 'assignment misclassified as lecture'
        $dir = New-Case 'category'
        New-Zip "$dir\a.zip" @{'QR Week7 Lecture 21.pptx'='lecture'}
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Category
        Assert ($r.Errors -eq 0 -and (Test-Path "$dir\Lectures\QR Week7 Lecture 21.pptx")) 'category option created weeks'
    }
    Test-Case 'CRC corruption detected even when content can be decompressed' {
        $dir = New-Case 'crc'
        New-Zip "$dir\bad.zip" @{'lecture.pdf'='valid compressed payload'}
        $bytes = [IO.File]::ReadAllBytes("$dir\bad.zip")
        for ($i=0; $i -lt $bytes.Length-20; $i++) {
            if ([BitConverter]::ToUInt32($bytes,$i) -eq 0x02014b50) {
                $bytes[$i+16] = $bytes[$i+16] -bxor 1
                break
            }
        }
        [IO.File]::WriteAllBytes("$dir\bad.zip",$bytes)
        $r = Invoke-LmsUnpacker -Path $dir
        Assert ($r.Errors -eq 1 -and (Test-Path "$dir\bad.zip")) 'CRC failure lost archive'
        Assert (-not (Test-Path "$dir\lecture.pdf")) 'corrupt entry published'
    }
    Test-Case 'Empty archive and duplicate entry names are handled' {
        $dir = New-Case 'empty'
        New-Zip "$dir\empty.zip" @{}
        $r = Invoke-LmsUnpacker -Path $dir
        Assert ($r.Errors -eq 0 -and $r.Archives -eq 1) 'empty ZIP failed'
        New-Zip "$dir\a.zip" ([ordered]@{'one/a.txt'='one'; 'two/a.txt'='two'; 'three/a.txt'='two'})
        $r = Invoke-LmsUnpacker -Path $dir -Conflict Rename
        Assert ($r.Errors -eq 0 -and $r.Written -eq 2 -and $r.Skipped -eq 1) 'internal collision plan failed'
    }
    Test-Case 'Existing-file collisions keep the loose source, including duplicates' {
        $dir = New-Case 'organize-conflict'
        Write-File "$dir\Assignment 1.pdf" 'same'
        Write-File "$dir\Assignments\Assignment 1.pdf" 'same'
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -ExistingOnly $true
        Assert ($r.Errors -eq 0 -and $r.Moved -eq 0 -and (Test-Path "$dir\Assignment 1.pdf")) 'organizer deleted loose duplicate'
    }
    Test-Case 'Junction destinations are rejected and not followed' {
        $dir = New-Case 'junction'
        $outside = New-Case 'junction-target'
        $link = Join-Path $dir 'Assignments'
        $null = New-Item -ItemType Junction -Path $link -Target $outside
        try {
            New-Zip "$dir\a.zip" @{'Assignment 1.pdf'='file'}
            $r = Invoke-LmsUnpacker -Path $dir -Mode Organize
            Assert ($r.Errors -eq 1 -and (Test-Path "$dir\a.zip")) 'junction followed'
            Assert (@(Get-ChildItem -LiteralPath $outside).Count -eq 0) 'wrote through junction'
        } finally { Remove-Item -LiteralPath $link -Force }
    }
    Test-Case 'Locked output reports failure and keeps the input ZIP' {
        $dir = New-Case 'locked'
        Write-File "$dir\a.txt" 'old'
        New-Zip "$dir\a.zip" @{'a.txt'='new'}
        $lock = [IO.File]::Open("$dir\a.txt",'Open','ReadWrite','None')
        try {
            $r = Invoke-LmsUnpacker -Path $dir -Conflict Overwrite
            Assert ($r.Errors -eq 1 -and (Test-Path "$dir\a.zip")) 'locked output caused archive deletion'
        } finally { $lock.Dispose() }
    }
    Test-Case 'Unicode profiles and filenames survive organization and undo' {
        $dir = New-Case 'unicode'
        $courseFolder = 'Biolog' + [char]0x00ED + 'a'
        $fileName = 'cell ' + [char]0x03B1 + '.pdf'
        Write-File "$dir\$courseFolder\$fileName" 'unicode'
        $config = @{Version=1; Courses=@(@{Code='BIO-101'; Folder=$courseFolder}); Rules=@(@{Course='BIO-101'; Pattern='cell *'; Folder='Lectures/Week 01'})}
        [IO.File]::WriteAllText("$dir\profile.json",($config | ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Week -ExistingOnly $true -RulesPath "$dir\profile.json"
        Assert ($r.Errors -eq 0 -and $r.Moved -eq 1) 'Unicode organization failed'
        Undo-LmsOrganization -ReportPath $r.Journal
        Assert (Test-Path -LiteralPath "$dir\$courseFolder\$fileName") 'Unicode undo failed'
    }
    Test-Case 'Interrupted undo recovers without moving the restored file again' {
        $dir = New-Case 'undo-recovery'
        Write-File "$dir\Assignment 1.pdf" 'original'
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -ExistingOnly $true
        Assert ($r.Errors -eq 0) 'recovery setup failed'
        $journal = Get-Content -LiteralPath $r.Journal -Raw -Encoding UTF8 | ConvertFrom-Json
        $journal.Moves[0].State = 'Restoring'
        [IO.File]::WriteAllText($r.Journal,($journal | ConvertTo-Json -Depth 8))
        [IO.File]::Move("$dir\Assignments\Assignment 1.pdf","$dir\Assignment 1.pdf")
        Undo-LmsOrganization -ReportPath $r.Journal
        $updated = Get-Content -LiteralPath $r.Journal -Raw | ConvertFrom-Json
        Assert ($updated.Moves[0].State -eq 'Undone') 'interrupted undo not recovered'
    }
    Test-Case 'CLI WhatIf and failure exit codes' {
        $dir = New-Case 'cli'
        New-Zip "$dir\a.zip" @{'a.txt'='payload'}
        $executable = (Get-Process -Id $PID).Path
        & $executable -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\Unpack-Lms.ps1') -Path $dir -WhatIf
        Assert ($LASTEXITCODE -eq 0 -and (Test-Path "$dir\a.zip") -and -not (Test-Path "$dir\a.txt")) 'CLI WhatIf changed files'
        & $executable -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot '..\Unpack-Lms.ps1') -Path "$dir\missing"
        Assert ($LASTEXITCODE -eq 1) 'CLI failure returned success'
    }
    Test-Case 'Guided launcher previews, cancels, and applies using keyboard input' {
        $dir = New-Case 'launcher'
        New-Zip "$dir\a.zip" @{'a.txt'='payload'}
        $executable = (Get-Process -Id $PID).Path
        $launcher = Join-Path $PSScriptRoot '..\Start-Unpacker.ps1'
        @('1','1','n') | & $executable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $launcher -Path $dir
        Assert ($LASTEXITCODE -eq 0 -and (Test-Path "$dir\a.zip") -and -not (Test-Path "$dir\a.txt")) 'launcher cancel changed files'
        @('1','1','y') | & $executable -NoLogo -NoProfile -ExecutionPolicy Bypass -File $launcher -Path $dir
        Assert ($LASTEXITCODE -eq 0 -and -not (Test-Path "$dir\a.zip") -and (Test-Path "$dir\a.txt")) 'launcher apply failed'
    }
    Test-Case 'All 42 supplied Calculus filenames map by syllabus week or topic, with explanations' {
        $dir = New-Case 'calculus'
        $courseDir = Join-Path $dir 'Calculus'
        $cases = @(Import-Csv -LiteralPath (Join-Path $PSScriptRoot 'fixtures\calculus.csv'))
        Assert ($cases.Count -eq 42) 'expected the full Calculus filename fixture'
        foreach ($case in $cases) { Write-File (Join-Path $courseDir $case.File) ('fixture: ' + $case.File) }
        foreach ($group in @('Week','Topic')) {
            $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy $group -ExistingOnly $true -RulesPath (Join-Path $PSScriptRoot '..\profiles\nust.json') -Preview $true
            Assert ($r.Errors -eq 0 -and $r.Moved -eq 42 -and $r.Unclassified -eq 0) "$group coverage incomplete"
            foreach ($case in $cases) {
                $detail = @($r.Details | Where-Object { [IO.Path]::GetFileName($_.Source) -eq $case.File })
                $expectedFolder = if ($group -eq 'Week') { $case.WeekFolder } else { $case.TopicFolder }
                Assert ($detail.Count -eq 1 -and $detail[0].Target -eq (Join-Path $courseDir ($expectedFolder + '/' + $case.File))) "Incorrect $group folder for $($case.File)"
                Assert (-not [string]::IsNullOrWhiteSpace($detail[0].Reason)) 'missing explanation'
            }
        }
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Topic -ExistingOnly $true -RulesPath (Join-Path $PSScriptRoot '..\profiles\nust.json')
        Assert ($r.Errors -eq 0 -and $r.Moved -eq 42) 'topic organization failed'
        Undo-LmsOrganization -ReportPath $r.Journal
        foreach ($case in $cases) { Assert (Test-Path -LiteralPath (Join-Path $courseDir $case.File)) 'topic undo lost a file' }
    }
    Test-Case 'Topic rules from another syllabus support punctuation variants and ZIP contents' {
        $dir = New-Case 'custom-topic'
        Write-File "$dir\courses.csv" "Code,Folder,Name`nBIO-101,Biology,Biology"
        Write-File "$dir\syllabus.csv" "Code,Week,Pattern,Folder,Topic,Reason`nBIO-101,2,*cell structure*,,Cells,Week 2 in supplied syllabus"
        & (Join-Path $PSScriptRoot '..\New-CourseProfile.ps1') -CoursesCsv "$dir\courses.csv" -SyllabusCsv "$dir\syllabus.csv" -OutputPath "$dir\profile.json"
        New-Zip "$dir\BIO-101-download.zip" @{'cell_structure.pdf'='cells'; 'Lecture 1.pdf'='unknown topic'}
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -GroupBy Topic -RulesPath "$dir\profile.json"
        Assert ($r.Errors -eq 0 -and (Test-Path "$dir\Biology\Lectures\Cells\cell_structure.pdf")) 'custom topic was not honored'
        Assert (Test-Path "$dir\Biology\Lectures\Unsorted topics\Lecture 1.pdf") 'topic guessed without evidence'
    }
    Test-Case 'Fast existing-only preview does not read nonconflicting document contents' {
        $dir = New-Case 'preview-fast'
        Write-File "$dir\Assignment 1.pdf" 'locked content'
        $lock = [IO.File]::Open("$dir\Assignment 1.pdf",'Open','ReadWrite','None')
        try {
            $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -ExistingOnly $true -Preview $true
            Assert ($r.Errors -eq 0 -and $r.Moved -eq 1) 'preview unnecessarily opened document content'
        } finally { $lock.Dispose() }
        Assert (-not (Test-Path "$dir\Assignments")) 'fast preview created a folder'
    }
    Test-Case 'Organization preview detects a file blocking the destination directory' {
        $dir = New-Case 'organization-blocked'
        Write-File "$dir\Assignments" 'blocking file'
        Write-File "$dir\Assignment 1.pdf" 'document'
        $r = Invoke-LmsUnpacker -Path $dir -Mode Organize -ExistingOnly $true -Preview $true
        Assert ($r.Errors -eq 1 -and (Test-Path "$dir\Assignment 1.pdf")) 'blocked parent was missed'
    }
    Test-Case 'BAT launch works with spaces, ampersands, no argument and help' {
        $dir = New-Case 'batch app & spaces'
        foreach ($file in @('Run-Unpack.bat','Start-Unpacker.ps1','LmsUnpacker.psm1','ZipIntegrity.cs')) {
            Copy-Item -LiteralPath (Join-Path $PSScriptRoot ('..\' + $file)) -Destination $dir
        }
        Push-Location $dir
        try {
            $help = & cmd.exe /d /c 'Run-Unpack.bat /?'
            Assert ($LASTEXITCODE -eq 0 -and ($help -join ' ') -match 'ExecutionPolicy Bypass') 'BAT help failed'
            @('q','') | & cmd.exe /d /c 'Run-Unpack.bat'
            Assert ($LASTEXITCODE -eq 0) 'no-argument launcher failed'
            @('q','') | & cmd.exe /d /c 'Run-Unpack.bat "."'
            Assert ($LASTEXITCODE -eq 0) 'quoted path launcher failed'
        } finally { Pop-Location }
    }
    Write-Host "All $script:passed tests passed on PowerShell $($PSVersionTable.PSVersion)."
} finally {
    $resolved = [IO.Path]::GetFullPath($testRoot)
    $tempPrefix = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '.runs')).TrimEnd('\') + '\'
    if ($resolved.StartsWith($tempPrefix,[StringComparison]::OrdinalIgnoreCase) -and ([IO.Path]::GetFileName($resolved) -like 'lms-tests-*')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
