#requires -Version 5.1
<# .SYNOPSIS
Generate the offline file/function reference from public source, never ignored files.
#>
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$fileHelp=@{
 '.gitattributes'='Normalizes shell/workflow line endings. Bash launchers must keep LF endings across Windows and Linux checkouts.'
 '.gitignore'='Excludes generated binaries, scratch, logs, secrets, personal materials and local agent notes. It is not a substitute for reviewing staged changes.'
 '.github/ISSUE_TEMPLATE/bug_report.md'='Prompts reporters for reproducible behavior, environment and safe examples without requesting private course documents.'
 '.github/ISSUE_TEMPLATE/feature_request.md'='Collects a user problem, proposed behavior and alternatives for feature discussions.'
 '.github/PULL_REQUEST_TEMPLATE.md'='Reminds contributors to explain behavior, validation and relevant privacy/file-operation impact.'
 '.github/dependabot.yml'='Requests updates to GitHub Actions dependencies; updates still need review and successful checks.'
 '.github/workflows/test.yml'='Runs Windows engine and desktop tests, Linux portable/shell checks and guide checks; packages outputs only after prerequisite jobs pass.'
 '.github/workflows/release.yml'='Requires a tag matching VERSION, reuses tests, builds final artifacts, attests their origin, verifies hashes/provenance and creates a draft release.'
 'Build-Linux.ps1'='PowerShell 7 build entry point. Zips the explicit CLI runtime list in memory, appends Base64 to a Bash wrapper and writes a checksum. Does not bundle pwsh.'
 'Build-Release.ps1'='Windows build entry point. Runs tests, generates icon, creates an explicit runtime ZIP, compiles desktop/CLI hosts, tests standalone outputs and writes SHA-256 sidecars. Refuses an existing versioned ZIP.'
 'CHANGELOG.md'='Human-readable release changes. Describes shipped behavior and fixes rather than treating plans as completed work.'
 'CONTRIBUTING.md'='Contributor workflow, prerequisites and contribution expectations.'
 'Desktop.xaml'='Main WPF layout, control names, styles, wrapped tooltip template, settings tabs, result tables, empty states and fixed action area. Behavioral handlers live in PowerShell.'
 'DesktopDiscovery.ps1'='Dot-sourced UI helper: tooltip descriptions, independent picker memory, startup/discovery requests, a debounced background scanner and stale-result suppression.'
 'DesktopFeatures.ps1'='Dot-sourced UI helper: queue, workspace persistence/restoration, output picker, profile editing, row details, unclassified filter and cancellation event wiring.'
 'DesktopFeedback.ps1'='Dot-sourced UI helper: progress/elapsed text, taskbar status, ready/working/success/error/cancelled styling and completion actions.'
 'DesktopIntegration.psm1'='Exports per-user EXE copying and Start shortcut creation. Releases COM handles; shortcut installation is optional.'
 'DesktopPaths.psm1'='Pure path-choice helpers for actual EXE versus working directory, remembered picker fallback and explicit/startup input priority.'
 'HistoryDialog.ps1'='Lists local undo journals and shows a selection dialog. Listing is bounded; the engine remains responsible for full restore validation.'
 'LAUNCH-HELP.txt'='Plain-text fallback launch/troubleshooting instructions for users whose browser, BAT association or script policy causes difficulty.'
 'LICENSE'='MIT license terms and attribution shipped with every edition.'
 'LmsUnpacker.psm1'='Shared engine: validates paths/profiles, scans, classifies, plans conflicts, verifies/stages/publishes archives, organizes loose documents and validates undo.'
 'New-CourseProfile.ps1'='Converts courses/syllabus CSV rows into validated Version 1 JSON. Requires a new output filename and verifies rules before copying the result.'
 'PRIVACY.md'='Describes offline behavior, local paths/settings/journals, optional OS integrations and absence of telemetry.'
 'ProfileEditor.ps1'='WPF course/rule editor using DataTables. Saves a validated new JSON copy, optionally seeded from a selected unclassified result.'
 'README.md'='Project landing page: choices, defaults, downloads, CLI options, limitations and development entry points.'
 'Run-Unpack.bat'='Source-distribution Windows guided-menu launcher. Checks required siblings, selects PowerShell, passes one input path and pauses for readable output. It is not the standalone EXE.'
 'Run-Unpack.sh'='Source-distribution Bash entry point that checks for pwsh and dispatches into the repository CLI.'
 'SECURITY.md'='Supported security expectations, sensitive-report guidance and important file-operation boundaries.'
 'START-HERE.html'='Offline user tutorial with task demonstrations, scan-depth simulation, searchable help, CLI walkthrough and safe clipboard fallback.'
 'Sign-Release.ps1'='Optional local Authenticode helper for an existing certificate. Validates thumbprint, validity/private key/EKU/trust, signs EXEs and refreshes hashes. Does not obtain a certificate.'
 'Start-Cli.ps1'='Allowlisted argument dispatcher for help/menu/tutorial/profile/undo or direct named options. Decodes host arguments as data and propagates failure exit codes.'
 'Start-Desktop.ps1'='WPF composition root. Loads markup/modules, binds named controls, restores settings, converts options, owns runspaces/timers and handles operation results/startup/closing.'
 'Start-Unpacker.ps1'='Guided terminal menu. Selects mode/profile/grouping, previews and asks before applying. Calls the shared engine directly.'
 'Undo-Organization.ps1'='Thin public script wrapper for journal restore, including DryRun/ShouldProcess integration.'
 'Unpack-Lms.ps1'='Public extraction script API. Validates enums/ranges, supports legacy aliases, converts flags and gigabytes, implements WhatIf/DryRun and optionally returns structured results.'
 'VERSION'='Three-part product version used by build scripts and release-tag validation. Keep the C# assembly and user-facing release references synchronized.'
 'ZipIntegrity.cs'='Byte-oriented helper compiled by Add-Type. Reads central-directory CRCs and verifies streamed decompressed data while computing SHA-256.'
 'docs/DOWNLOADS.md'='Stable download landing page explaining independent editions, checksums and current signing status.'
 'docs/PROFILES.md'='Profile/CSV format, course routing and syllabus rule examples for users with their own courses.'
 'docs/ROADMAP.md'='Future proposals and priorities; not a list of implemented features.'
 'docs/SIGNING.md'='Signing/provenance policy, maintainer responsibilities and current unsigned/SignPath-preparation status.'
 'docs/SIGNPATH-APPLICATION.md'='Honest application worksheet. Does not submit an application or claim adoption, approval or a personal certificate.'
 'docs/BUILD-IT-YOURSELF.html'='Illustrated engineering handbook: architecture, decisions, examples, data contracts, failure handling, rebuild exercises and glossary. Its conflict simulator is demonstration-only.'
 'docs/CODE-REFERENCE.html'='This generated, searchable public-source inventory. Rebuild with tools/Build-CodeReference.ps1 after source changes; do not edit the generated HTML by hand.'
 'packaging/App.manifest'='Windows application manifest requesting asInvoker privileges and declaring supported Windows compatibility. It does not request elevation or define a DPI-awareness setting.'
 'packaging/LinuxLauncher.sh'='Bash prefix used in the generated standalone Linux file. Checks pwsh, decodes the appended payload into mktemp storage, invokes the CLI and cleans up on exit.'
 'packaging/New-AppIcon.ps1'='Build-time System.Drawing icon creation. Writes the application icon used in both EXEs and the runtime ZIP.'
 'packaging/PortableHost.cs'='Small .NET Framework entry point compiled as console or windowed host. Extracts its own embedded resource, transports arguments as Base64 JSON, starts PowerShell, waits and cleans owned temp storage.'
 'profiles/courses.example.csv'='Public sample course-code/folder/name rows; a template for the CSV importer.'
 'profiles/nust.json'='Optional example course and syllabus mappings. Engine behavior is generic and does not require this institution-specific data.'
 'profiles/syllabus.example.csv'='Public sample filename patterns with week/folder/topic/reason fields, converted to the same JSON rule model.'
 'tests/Run-Tests.ps1'='Windows regression scenarios with synthetic ZIPs/documents: integrity, conflicts, hostile paths, grouping, organization, journals and recovery.'
 'tests/Test-Desktop.ps1'='Runs inside the real desktop UI scope with SmokeTest. Exercises buttons, background workers, picker setup, queue, dialogs, progress, discovery, popup wrapping and minimum-size layout. Optional WPF renders are test artifacts.'
 'tests/Test-Guide.js'='Node built-in tests for offline guide structure and interactions using a lightweight DOM stub. Includes handbook/reference checks; no browser rendering claim.'
 'tests/Test-Cleanup.ps1'='Runs the cleaner in an isolated fake repository with synthetic artifacts. Verifies preview makes no changes, incomplete releases block removal and current/newer/unknown files survive.'
 'tests/Test-Linux.sh'='End-to-end generated Linux shell checks from an independent folder, including paths with spaces, dry-run/apply and error exit behavior.'
 'tests/Test-Portable.ps1'='Portable engine/profile regression fixtures that run under both Windows and Linux PowerShell.'
 'tests/Test-Release.ps1'='Checks packaged desktop startup, CLI argument parsing/extraction, isolated installed-copy startup and runtime cleanup using the actual built EXEs.'
 'tests/fixtures/calculus.csv'='Public filename/expected-destination fixture for Calculus topic and week classification; contains no course document contents.'
 'tools/Build-CodeReference.ps1'='Maintainer documentation generator. Enumerates only nonignored public files, requires purpose/function annotations, parses PowerShell ASTs, escapes source and emits one offline reference page.'
 'tools/Clean-Workspace.ps1'='Preview-first generated-clutter cleanup. Targets only known scratch/old release patterns, verifies current artifacts before removing older packages, checks containment and refuses links.'
}
$functionHelp=@{
 'Assert-PlainPath'='Input: a filesystem path. Walks it and its ancestors, allowing missing components but rejecting reparse points and file-blocked parent directories. Throws before unsafe reads/writes; returns no business data.'
 'Get-SafeRelativePath'='Input: archive/rule path text. Normalizes separators and rejects rooted, empty, dot, traversal, reserved-name and unsupported-character components. Returns a platform-separated relative path or throws.'
 'Get-ContainedPath'='Inputs: trusted root and untrusted relative name. Combines validated components, normalizes the full path, enforces root-with-separator containment and checks links. Returns the allowed absolute destination.'
 'Read-LmsRules'='Input: optional JSON path. Returns an empty general profile or validates Version/Courses/Rules, compiles case-insensitive wildcard matchers, sorts course codes longest-first and creates a per-course rule cache. Invalid profiles stop the operation.'
 'Get-LmsCourse'='Inputs: ZIP stem or folder name and course mappings. Finds an exact folder match or bounded escaped course-code prefix. Returns the matching course or null; never guesses from a loose substring.'
 'Get-LmsCategory'='Input: filename. Recognizes ordered category keywords/numbers after separator normalization. Protects submission/evidence names and returns null when uncertain. No document-content reading occurs.'
 'Get-FileDigest'='Input: existing path. Returns the SHA-256 string using LiteralPath hashing. Used for collision comparison and journal validation; errors propagate.'
 'Get-LmsClassification'='Inputs: filename, course, profile, grouping and LMS context. Tries ordered matching rules, then filename categories/context weeks; transforms lecture grouping and returns Folder/Topic/Reason. Missing weeks/topics stay explicitly unknown.'
 'Get-LmsTarget'='Inputs: proposed target, incoming hash, conflict policy and mutable reservation map. Compares existing or planned content; returns Path/Action/Comparison. Reserves writes, skips identical data and searches numbered names under Rename. Throws on blocking directories.'
 'Copy-LmsEntry'='Inputs: ZipArchiveEntry, optional staging path and expected CRC. Opens streams, delegates streaming integrity/hash work to CopyChecked and disposes both. Preview omits the output stream; Apply uses CreateNew staging files.'
 'Replace-LmsFile'='Inputs: staged source and destination. Rechecks plain paths and attempts atomic File.Replace. Retries IOException at bounded exponential delays while the source remains; all other failures propagate.'
 'Install-LmsFile'='Inputs: staged source, final target and replace flag. Creates the parent, copies into a unique sibling temporary file, then Move/Replace publishes it. Finally removes any owned leftover temporary file. Atomic per file, not per archive.'
 'Invoke-LmsArchive'='Inputs: ZIP FileInfo, normalized options, profile and archive-local reservation map. Routes course, validates metadata/types/limits, hashes and stages all entries, checks internal path conflicts, publishes planned files and optionally deletes the source. Returns counts/details; finally disposes archive and removes owned staging.'
 'Save-LmsJournal'='Inputs: journal object and report path. Serializes JSON to a sibling .tmp and moves/replaces the report. Durable intermediate states allow recovery after interrupted moves; it is not a backup of file bytes.'
 'Invoke-LmsOrganization'='Inputs: scanned files, root, options, profile and reservation map. Handles only eligible loose document extensions, classifies and plans, leaves unknown/colliding sources intact, hashes actual moves and persists Pending/Moved records around File.Move. Returns moved/unclassified counts, journal and details.'
 'Get-LmsScanFiles'='Inputs: filesystem item and depth 0/1. Returns direct files plus allowed immediate child-folder files. Excludes protected/hidden child folders and links. An explicitly selected file is returned directly. Shared by discovery and processing.'
 'Find-LmsArchives'='Exported read-only discovery API. Inputs: path and validated depth. Resolves a filesystem item, calls the shared scan and returns ZIP FileInfo objects sorted by full path. Does not open archive contents.'
 'Invoke-LmsUnpacker'='Exported orchestration API. Validates option combinations/root/profile/output, scans, optionally organizes loose files, then processes archives with per-archive reservation copies. Aggregates structured counts/details and logs. Archive errors retain ZIPs; loose-organization errors stop ZIP processing.'
 'Undo-LmsOrganization'='Exported undo API. Reads a Version 1 journal at its original history location, validates contained paths and hashes and builds reverse moves before mutation. Preview prints only; Apply persists Restoring/Undone states. Recognizes recoverable interrupted states and refuses occupied/modified files.'
 'Test-LmsProfile'='Exported validator. Reads rules through the same private validation path used by extraction; returns true on success or throws. Editors/importers use it before publishing a profile.'
 'Get-LmsLaunchFolder'='Inputs: actual EXE path and working directory. Chooses an existing EXE parent, then working directory, then UserProfile. Keeps the embedded temporary runtime out of the user-facing launch location.'
 'Get-LmsPickerFolder'='Inputs: remembered location and launch folder. Returns the first existing directory, then UserProfile fallback. Used independently for folder and ZIP dialogs.'
 'Get-LmsStartupSelection'='Inputs: explicit path, launch folder and remembered selection. Returns initial Path and ordered unique Candidates. Explicit input is the only candidate when supplied; otherwise launch ZIP discovery can take priority over memory.'
 'Add-LmsStartShortcut'='Inputs: EXE and optional install/shortcut paths. Copies to a stable per-user Programs location with temporary publication, creates a WScript.Shell shortcut to that copy and releases COM objects. Returns installed target; tests override locations.'
 'Set-DesktopHelp'='Builds the named-control help dictionary, creates explicitly styled wrapping ToolTips, adds AutomationProperties.HelpText and configures delay/duration/disabled-control help. UI-only, called after named controls exist.'
 'Get-WorkspaceHint'='Input: saved workspace. Produces a multiline summary of folder, queue count, task, output and retention for item hover help. Does not touch documents.'
 'Update-WorkspaceHints'='Adds transient Hint fields to in-memory saved workspaces, falling back to a readable message for invalid data. Hints are omitted from persisted preferences.'
 'Remember-PickerSelection'='Inputs: Folder/Zip kind and accepted path. Derives a directory, updates only that picker memory and saves preferences outside SmokeTest. Selection alone is enough to remember a location.'
 'New-InputFolderDialog'='Creates a WinForms FolderBrowserDialog with the independent remembered/launch starting folder and no new-folder action. Caller shows and disposes it; this function does not show a window.'
 'New-InputZipDialog'='Creates a multiselect WPF OpenFileDialog restricted to ZIPs and seeded with the independent ZIP-folder memory. Caller handles accepted selection.'
 'Request-ZipDiscovery'='Inputs: optional startup candidates and Force. Increments request version, snapshots current paths/depth and queues a debounced scan. SmokeTest suppresses incidental scans unless forced. Does not perform extraction.'
 'Read-DiscoveryResult'='Input: current-version worker result. Optionally changes startup selection under a reentrancy guard, binds discovered rows/counts and updates scope help. Selects the archive tab only if no plan is currently shown and no work is active.'
 'Set-SelectedPaths'='Input: ordered selected paths. Replaces the main selection and additional queue, deduplicates additional entries and invalidates old preview. Empty selections do nothing.'
 'Update-ReviewFilter'='Sets or clears the result CollectionView predicate for unclassified rows. It filters presentation only; it does not remove actions from the engine plan.'
 'Get-WorkspaceSnapshot'='Input: name. Returns current UI paths, queue, profile/task/group indices, output and retention/scan settings as a serializable object. It stores references to files, not copies of materials.'
 'Restore-Workspace'='Input: saved object. Validates selectable indices, restores paths/options/queue and invalidates preview. Missing external paths are checked later; it does not silently recreate them.'
 'Edit-SelectedProfile'='Input: optional seed rule. Resolves the chosen profile, opens the editor and selects the newly saved copy, then invalidates preview. Errors are handled by the invoking UI event.'
 'Edit-Queue'='Input: Remove/First/Up/Down. Mutates selected additional-input order, swaps with the main path when promoted and invalidates preview. Removing an entry never deletes its file.'
 'Set-FeedbackStyle'='Input: state kind. Applies normal-mode feedback colors for ready/working/success/cancel/error; exits without overrides in Windows high-contrast mode.'
 'Reset-Feedback'='Resets the title, taskbar, progress and result-folder action when a new plan is required. Does not erase user files or settings.'
 'Start-Feedback'='Inputs: operation/options. Starts a stopwatch, remembers retention for this run, immediately displays preparation/indeterminate progress and gives Preview/Apply/Undo distinct titles.'
 'Update-Feedback'='Reads shared progress at a throttled interval. Displays phase, queue/ZIP/entry counts and elapsed time; updates taskbar progress. Cancellation gets a separate stopping state. Percent is phase-local.'
 'Complete-Feedback'='Input: result. Stops elapsed tracking and selects preview, no-work, cancellation, undo or success feedback. Reports retention accurately and exposes the result-folder action after actual completion.'
 'Stop-FeedbackWithError'='Stops time tracking, displays partial-work/retained-archive guidance, hides success actions and sets the taskbar error state. It does not pretend failed work was rolled back.'
 'Show-Problem'='Input: message. Sets persistent status and displays an owner-bound warning dialog for a user-action error.'
 'Update-Hints'='Synchronizes task/group/default explanations, queue count, organization-only controls and applicable result columns. Does not execute a plan.'
 'Invalidate-Preview'='When idle, clears current preview/undo state, disables Apply, resets feedback and refreshes hints/discovery. Called by relevant setting/path/queue changes; busy operations keep their snapshot.'
 'Get-Options'='Reads/validates current UI choices and maps task indices to engine parameters plus QueuePaths. Rejects missing inputs, wrong file types and unsupported loose-only input choices. Returns a hashtable snapshot.'
 'Set-Busy'='Input: boolean. Changes editability, preview/apply/cancel/open actions and progress visibility consistently while preserving relevant classification enablement. All controls remain on the UI dispatcher thread.'
 'Save-Preferences'='Persists last path, independent picker memories and workspaces to LocalAppData JSON, excluding generated Hint fields. A save failure is reported in activity rather than changing extraction results.'
 'Start-Work'='Inputs: operation, options and optional undo path. Initializes shared progress, starts feedback, disables mutations and begins a separate PowerShell runspace. Its script rejects overlapping scopes, processes a shared collision plan and stops the queue on error/cancel.'
 'Read-Activity'='Updates progress and appends only new worker information-stream entries using a retained cursor. Called by the dispatcher timer, not the background engine.'
 'Test-HistoryPlainPath'='Input: candidate history path. Returns false if it or an existing ancestor is a link/reparse point; supports safe read-only journal indexing.'
 'Get-OrganizationHistory'='Input: selected paths/queue. Deduplicates history locations, lists at most 500 recent records per location, rejects oversized/linked/malformed records and returns status rows. Availability is provisional until engine undo validation.'
 'Show-HistoryDialog'='Inputs: owner, paths and optional test Inspect callback. Builds the real WPF record picker, supports selecting another root and returns the chosen report path. Test hook inspects the dialog without displaying it.'
 'Save-VisualProfile'='Inputs: new destination and course/rule rows. Serializes a temporary profile, validates through the shared engine and copies without overwrite. Finally deletes its owned temporary JSON.'
 'Show-ProfileEditor'='Inputs: owner, current profile, optional seed and test Inspect callback. Creates course/rule DataTables, binds grids, validates and saves a new copy. Returns its selected output path; errors remain visible in the editor.'
 'Read-Choice'='Inputs: prompt, allowed values and default. Repeats until valid, accepts Enter as default and turns Q into cooperative menu cancellation. Used by the guided CLI, not direct option parsing.'
 'CreateTable'='Private C# helper. Precomputes 256 CRC-32 lookup values using the reversed 0xEDB88320 polynomial so the streaming loop updates CRC efficiently.'
 'ReadExactly'='Private C# helper. Reads the requested metadata byte count and throws on truncation rather than letting partial arrays appear valid.'
 'ReadChecksums'='C# public helper. Locates ZIP/ZIP64 end and central-directory records, checks bounds/limits, rejects split/encrypted/unsupported compression and returns CRC values in directory order. Does not decompress entries.'
 'CopyChecked'='C# public helper. Streams 81,920-byte chunks, optionally writes output, enforces expected size, computes CRC-32 and SHA-256, rejects mismatches and returns a hex SHA-256 string. Disposes its hash algorithm; caller owns streams.'
 'Main'='C# host entry point. Extracts embedded App.zip into a unique contained temp root, launches fixed PowerShell script with Base64-JSON data arguments, waits/propagates exit status, reports startup errors and cleans owned runtime storage. DESKTOP/CLI compile constants choose presentation.'
 'Check-Desktop'='Desktop test assertion: throws a labeled failure when an observable UI condition is false.'
 'Click-Control'='Desktop test helper: raises a real WPF Button.Click routed event on a named control, exercising its actual handler without mouse automation.'
 'Wait-Desktop'='Desktop test helper: pumps dispatcher frames until background work finishes or a deadline expires. Allows real timer/runspace integration to execute.'
 'Wait-Discovery'='Desktop test helper: pumps dispatcher frames until discovery worker/pending requests settle, with a bounded timeout.'
 'Make-DesktopZip'='Creates a synthetic ZIP entry/content for desktop flow tests and reliably disposes archive/writer resources.'
 'Assert'='Engine-test assertion that throws with a clear message. Test-Case catches it to count failures.'
 'New-Case'='Creates a unique per-scenario directory under the test run root, isolating fixtures from one another and from user materials.'
 'Write-File'='Engine-test fixture helper that creates a parent directory and writes synthetic content at a literal path.'
 'New-Zip'='Engine-test fixture helper that turns an entry-name/content dictionary into a ZIP; hostile names are deliberate test data.'
 'Test-Case'='Runs an engine scenario scriptblock, records pass/failure and prints a named diagnostic so the suite can report aggregate outcomes.'
 'Assert-Release'='Packaged-release assertion with a labeled error. Used to fail builds when actual EXE behavior differs from the contract.'
 'Invoke-DesktopCheck'='Launches the packaged desktop startup-verification mode as a hidden process, waits with a timeout and requires a successful exit. No normal interactive app window is requested.'
 'Assert-Portable'='Portable-suite assertion that works without Windows-only testing libraries.'
 'Make-PortableZip'='Creates synthetic ZIP entries for cross-platform engine tests using .NET compression APIs.'
 'Assert-CleanupPath'='Cleanup guard. Resolves a candidate inside the repository, checks ancestors and walks directory children one level at a time to reject links before recursion. Returns only a validated absolute target.'
 'Assert-Cleanup'='Cleanup-test assertion. Checks observable preservation/deletion outcomes in a synthetic repository, never in real course materials.'
 'ConvertTo-ReferenceHtml'='Documentation helper: HTML-encodes any source/annotation text before insertion. Source code is shown as inert text, not interpreted as markup.'
 'Get-ReferenceId'='Documentation helper: derives a predictable, readable anchor from a public relative filename for internal source and function links.'
 'byId'='User-guide JavaScript convenience lookup by element ID. Keeps demo event handlers short; does not access the filesystem.'
 'renderScan'='User-guide simulation: shows depth-0/depth-1 discovery examples and announces the count. It uses fixed example filenames, not real directory access.'
 'renderExample'='User-guide simulation: transforms example output trees and retention labels for selected mode/grouping/Keep ZIP choices.'
 'renderLesson'='User-guide CLI lesson renderer: displays the selected step, command and explanations and optionally announces the transition.'
 'renderConflict'='Developer-handbook simulator: renders Duplicate/Skip/Rename/Overwrite and Keep/Delete consequences from three selectors. It never changes actual files.'
 'node'='Guide-test DOM stub factory. Supplies text/value/attributes, event registration and async event firing sufficient for the offline example scripts. Not a browser layout engine.'
 'checkOfflinePage'='Guide-test structural check for unique IDs, valid internal anchors and absent remote assets in handbook/reference pages.'
}
function ConvertTo-ReferenceHtml([string]$Text) { [Net.WebUtility]::HtmlEncode($Text) }
function Get-ReferenceId([string]$Path) { 'file-' + ($Path -replace '[^A-Za-z0-9_-]','-') }
Push-Location $root
try {
    $files=@(& git -c core.quotepath=false ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw 'Generate this reference from a Git checkout.' }
    $files=@(($files + 'docs/CODE-REFERENCE.html') | Sort-Object -Unique)
    # Local-only project memory is deliberately excluded even if accidentally staged.
    $files=@($files | Where-Object { $_ -notin @('AGENT.md','AGENTS.md') })
    $version=(Get-Content -LiteralPath VERSION -Raw).Trim()
    $cards=[Text.StringBuilder]::new(); $symbols=0
    foreach ($file in $files) {
        if (-not $fileHelp.ContainsKey($file)) { throw "Add a public-file description before generating: $file" }
        $id=Get-ReferenceId $file
        $null=$cards.Append('<article data-entry id="'+$id+'"><h2>'+ (ConvertTo-ReferenceHtml $file)+'</h2><p>'+(ConvertTo-ReferenceHtml $fileHelp[$file])+'</p>')
        $source=if ($file -eq 'docs/CODE-REFERENCE.html') { '' } else { [IO.File]::ReadAllText((Join-Path $root $file)).Replace("`r`n","`n") }
        $functions=@()
        if ($file -match '\.ps(m)?1$') {
            $tokens=$null; $parseErrors=$null
            $ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$parseErrors)
            if ($parseErrors.Count) { throw "PowerShell parse error in $file" }
            $functions=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]},$true) | ForEach-Object { [pscustomobject]@{Name=$_.Name; Line=$_.Extent.StartLineNumber} })
        } elseif ($file -match '\.cs$') {
            $functions=@([regex]::Matches($source,'(?m)^\s*(?:public|private|internal)\s+static\s+[\w\[\]]+\s+(\w+)\(') | ForEach-Object { [pscustomobject]@{Name=$_.Groups[1].Value; Line=($source.Substring(0,$_.Index) -split "`n").Count} })
        } elseif ($file -match '\.(html|js)$') {
            $functions=@([regex]::Matches($source,'(?m)^\s*(?:function\s+(\w+)\(|const\s+(\w+)\s*=\s*(?:\(\)|\w+)\s*=>)') | ForEach-Object {
                [pscustomobject]@{Name=$(if($_.Groups[1].Success){$_.Groups[1].Value}else{$_.Groups[2].Value}); Line=($source.Substring(0,$_.Index) -split "`n").Count}
            })
        }
        $includeSource=$file -match '\.(ps1|psm1|cs|xaml|sh|bat|json|csv|yml|js|manifest)$' -or $file -in @('.gitignore','.gitattributes','VERSION')
        foreach ($fn in $functions) {
            if (-not $functionHelp.ContainsKey($fn.Name)) { throw "Add a function explanation: $file / $($fn.Name)" }
            $symbols++
            $null=$cards.Append('<div class="symbol"><h3><code>'+(ConvertTo-ReferenceHtml $fn.Name)+'</code></h3><p>'+(ConvertTo-ReferenceHtml $functionHelp[$fn.Name])+'</p><small>Declared at line '+$fn.Line+'</small></div>')
        }
        if (-not $functions.Count) { $null=$cards.Append('<p class="muted">No named functions: behavior is defined by top-level statements, configuration, markup or prose. See the file purpose above.</p>') }
        if ($includeSource) {
            $null=$cards.Append('<details><summary>Read the full source ('+($source -split "`n").Count+' lines)</summary><pre><code>'+(ConvertTo-ReferenceHtml $source)+'</code></pre></details>')
        } elseif ($file -ne 'docs/CODE-REFERENCE.html') {
            $url='../'+$file
            $null=$cards.Append('<p><a href="'+(ConvertTo-ReferenceHtml $url)+'">Open this document</a></p>')
        }
        $null=$cards.Append('</article>')
    }
    $template=@'
<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>LMS Unpacker — every public file and function</title><style>
*{box-sizing:border-box}body{margin:0;background:#f5f4ee;color:#18332f;font:16px/1.65 system-ui,Segoe UI,sans-serif}header{padding:40px max(24px,calc((100vw - 1060px)/2));background:#173e34;color:white}header a{color:#d5f8e7}h1{font-size:clamp(28px,4vw,44px);line-height:1.2}main{max-width:1108px;margin:auto;padding:24px}h2{font-size:23px;overflow-wrap:anywhere}h3{font-size:18px;margin:0 0 6px}a{color:#075d4c}a:focus-visible,input:focus-visible,summary:focus-visible{outline:3px solid #a24200;outline-offset:3px}label{font-weight:700;display:block}input{font:inherit;width:100%;padding:12px;margin:8px 0;border:1px solid #73887f;border-radius:6px}.search{background:#f5f4ee;padding:12px 0;border-bottom:1px solid #cbd6d0}article{border:1px solid #cbd6d0;background:white;border-radius:12px;padding:24px;margin:24px 0;scroll-margin-top:20px}.symbol{border-left:3px solid #a8cdb9;padding:12px 18px;margin:16px 0;background:#f4f8f5}.symbol p{margin:5px 0}code{font-family:Consolas,monospace;overflow-wrap:anywhere;font-size:.9em}small,.muted{color:#48645e}summary{cursor:pointer;font-weight:650;padding:12px 0}pre{background:#18332f;color:#eaf5f0;padding:18px;overflow:auto;line-height:1.5;font-size:13px;border-radius:8px;max-height:650px}pre code{overflow-wrap:normal;font-size:inherit}[hidden]{display:none!important}footer{padding:30px;text-align:center;color:#48645e}@media print{.search{display:none}pre{max-height:none;white-space:pre-wrap;background:#eee;color:black}article{break-inside:auto}header{background:white;color:black}header a{color:black}}
</style></head><body><header><p>LMS Unpacker · __VERSION__ · Source companion</p><h1>Every public file.<br>Every named function.</h1><p>__FILES__ files · __SYMBOLS__ named functions/methods · Offline source snapshots</p><p><a href="BUILD-IT-YOURSELF.html">Read the illustrated handbook first</a> · <a href="../START-HERE.html">User tutorial</a></p></header><main><div class="search"><label for="search">Find a file, function or behavior</label><input id="search" type="search" placeholder="Try CRC, workspace, Invoke-LmsArchive or release" autocomplete="off"><p id="count" role="status" aria-live="polite"></p></div><p>Each file card explains its responsibility. Function entries explain inputs, outputs, side effects and failure behavior. Expand implementation files to read complete source, including event handlers and top-level code. File search includes source text. Ignored local notes and generated binaries are excluded.</p><div id="entries">__CARDS__</div><noscript>Search needs JavaScript; every file and function is still readable below.</noscript></main><footer>Generated by tools/Build-CodeReference.ps1. Update annotations and regenerate after changing source. Source text is HTML-escaped; no external assets or analytics.</footer><script>
'use strict';
const entries=Array.from(document.querySelectorAll('[data-entry]'));
const input=document.getElementById('search');
input.addEventListener('input',()=>{const query=input.value.trim().toLowerCase();let count=0;for(const entry of entries){entry.hidden=!entry.textContent.toLowerCase().includes(query);if(!entry.hidden)count++;}document.getElementById('count').textContent=count?count+' files match. Expand a source block to inspect implementation.':'No matches. Try a shorter function name or a behavior such as undo.';});
document.getElementById('count').textContent=entries.length+' files. Search by name or behavior.';
</script></body></html>
'@
    $output=$template.Replace('__VERSION__',$version).Replace('__FILES__',[string]$files.Count).Replace('__SYMBOLS__',[string]$symbols).Replace('__CARDS__',$cards.ToString())
    [IO.File]::WriteAllText((Join-Path $root 'docs/CODE-REFERENCE.html'),$output.Replace("`r`n","`n"),[Text.UTF8Encoding]::new($false))
    Write-Host "Generated reference: $($files.Count) files, $symbols named functions/methods."
} finally { Pop-Location }
