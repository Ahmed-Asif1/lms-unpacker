# LMS Unpacker

Turn messy LMS ZIP downloads into usable course folders. An offline Windows desktop
app and Windows/Linux CLI with three jobs: **flatten downloads**, **just unzip**, or **organize courses**.

[Downloads](docs/DOWNLOADS.md) · [Privacy policy](PRIVACY.md) ·
[Code signing policy](docs/SIGNING.md) · [Contributing](CONTRIBUTING.md) · [Roadmap](docs/ROADMAP.md)

**Defaults: flatten, skip existing filenames, delete successfully processed ZIPs.**
When a filename already exists, its incoming version is discarded even if its content
is different. Choose **Rename** to keep both versions, or **Keep ZIP** to retain the
archive. Errors keep the affected ZIP for recovery.

## Start here

Get the desktop or CLI executable from [GitHub Releases](https://github.com/Ahmed-Asif1/lms-unpacker/releases).
Download one EXE for the edition you want; the automatically generated Source code ZIP
is the repository snapshot. Executables and their SHA-256 files are separate release assets.

**Choose one file. Each edition works independently.**

| Download | How to use it |
| --- | --- |
| **LMS-Unpacker.exe** — desktop app | Double-click; choose or drop a ZIP/folder; preview; apply |
| **LMS-Unpacker-CLI.exe** — terminal edition | Run without arguments for a guided menu, or use named options |
| **LMS-Unpacker-CLI.sh** — Linux CLI | `bash LMS-Unpacker-CLI.sh --help`; requires PowerShell 7 (`pwsh`) |

You can keep either EXE anywhere. Supporting files and the offline guide are embedded;
they are unpacked automatically into a temporary folder and removed on normal exit.
No need to put the program in your course folders or copy paths: the desktop has
**Choose folder**, **Choose ZIP**, drag-and-drop and **Open selected folder**.
It remembers the last successfully processed path locally.

Click **Visual guide** inside the desktop app, or run the CLI with `--tutorial`.
The standalone [START-HERE.html](START-HERE.html) also works offline. Its examples are
simulations and cannot modify your files. Keep the app open while using embedded help.

The desktop shows destinations and reasons, runs work in the background, and requires
a successful preview before Apply. Changing options invalidates the preview. The files
are checked again when applying, so changes made outside the app can affect that run.
The app waits for active work to finish before closing.

### Workspaces, queues and destinations

- Open **Saved workspaces and queue**, enter a name, and save the current paths and settings.
- Select a queued path to **Move up**, **Move down**, **Make first** or **Remove selected**.
  The main input runs first; Skip keeps the first content for each destination name.
  Changing the queue requires a fresh preview.
  Select the saved name next time. Saving with the same name updates it; Remove forgets it.
  Paths and settings stay in your local preferences file. Profiles remain at the paths you chose.
- Select multiple ZIPs in **Choose ZIP**, or drop multiple folders/ZIPs into the window.
  To combine folder selections, use **Add current path**, then choose the next folder.
  **Clear queue** removes additional selections. Nested, overlapping scopes are rejected.
- **ZIP output folder** chooses where extracted files go. Blank uses the existing location.
  Course routing and original archive structure still apply. Loose documents are organized
  in place with undo; the output setting is disabled for the loose-only task.
- Preview checks the whole queue, including collisions between inputs. Apply stops on the
  first failed queue item. Completed work remains, and errors retain the affected ZIP.
- **Content comparison** distinguishes identical and different content. Select a row and
  open **Selected file details** for its source archive, incoming size, destination and
  SHA-256 comparison. This also identifies conflicts with earlier planned outputs.
- **History / undo** finds organization records in the selected folders and queue. Choose
  another original folder if needed. Available records are validated in an undo preview;
  changed files and occupied original paths prevent restoration. ZIP deletion and extraction
  cannot be undone here. Completed and unreadable records remain visible with their status.
- A prominent progress panel reports the current queue input, ZIP, phase, file and elapsed
  time, with matching Windows taskbar progress. The bar measures the current phase;
  it can restart for the next archive. A persistent **Done** panel shows counts and whether
  ZIPs were kept or deleted, plus **Open result folder**. Errors and cancellation have
  separate messages. **Cancel safely**
  finishes the current entry read or archive publication before stopping. A completed
  archive may already have been deleted according to your setting. Unprocessed ZIPs remain.
  Cancellation is not rollback; preview again before continuing.

### Edit your courses visually

Choose an Organize task and click **Edit courses and syllabus**. The Courses tab maps
course codes to folders. The Syllabus rules tab matches filenames to categories, weeks
and topics. Add a row at the bottom; select a row and press Delete to remove it.
For example: `BIO-101 | *cell* | Lectures/Week 02 | Cell biology`.
Save to a new JSON filename. The app validates the rules and selects your saved copy.
You can also open and edit a selected custom or example profile; the original stays intact.

After preview, check **Show only unclassified files**, select a row and click
**Add rule for selected file**. This seeds an exact filename rule and its course at the
top of the editor. Set a folder/topic, save, then preview again. Change the pattern to
something like `*cell*` when it should match future downloads. First matching rule wins.
No document contents are uploaded or read to guess syllabus dates.

### Linux

Install PowerShell 7 using [Microsoft's Linux instructions](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux).
The single `.sh` download embeds the application, not the PowerShell runtime. It does not
download or install anything. Bash, `awk`, `base64` and `mktemp` are needed (standard on
common Linux distributions). Run it directly with Bash, without changing permissions:

```bash
bash LMS-Unpacker-CLI.sh -Path "$HOME/Courses" -DryRun
bash LMS-Unpacker-CLI.sh -Path "$HOME/Downloads/course.zip" -Mode Extract -OutputPath "$HOME/Courses"
bash LMS-Unpacker-CLI.sh -Path "$HOME/Courses" -Mode Organize -ExistingOnly -GroupBy Topic -RulesPath /path/to/my-courses.json -DryRun
```

For a source checkout, `bash Run-Unpack.sh` launches the same engine. Linux has the CLI,
profiles, grouping, preview, output selection and undo; the native WPF desktop is Windows-only.
The same conservative ZIP filename rules apply on Linux, including rejecting Windows-reserved
names and links. Do not use this tool to restore Unix permissions, symlinks or special files.
The offline HTML guide needs a desktop browser to open; CLI extraction also works headlessly.

### Start menu (optional)

Click **Add to Start menu**. The app copies its single EXE to
`%LOCALAPPDATA%\Programs\LMS Unpacker` and creates your personal Start menu shortcut.
No admin rights are needed; you can then move/delete the original download.
Close an older installed instance before adding an updated download.
**Remove shortcut** removes the Start menu entry. To remove the installed copy too,
close the app and delete that specific `LMS Unpacker` folder. Preferences are stored
separately in `%LOCALAPPDATA%\LMS Unpacker\preferences.json` and may also be deleted.

On Windows, no installation, administrator access, account, Python or network connection is needed.
Requires Windows 10/11 and Windows PowerShell 5.1 (included with Windows), or PowerShell 7.
The self-contained executables use Windows PowerShell 5.1. The optional source BAT
prefers PowerShell 7 when installed. There are no network dependencies.

The desktop uses native Windows controls with labels, keyboard access keys, visible
focus, system high-contrast colors, resizable panes and a virtualized result table.
Use Tab, Shift+Tab, arrow keys, Space and Enter. Activity/error details can be selected
and copied. Keyboard and scripted flows have been tested; a real screen-reader user
acceptance test has not yet been completed.

The CLI menu works entirely by keyboard: type a choice, press Enter to use a displayed
default, or Q to quit. Output uses plain text with labeled actions, no color-only
meaning, animations or disappearing progress. Paths with spaces and non-English names
are supported. Use terminal zoom and normal text selection as needed. Screen-reader
compatibility is a design goal; a screen-reader user acceptance test is still welcome.

## Choose a mode

| Mode | Result | Best for |
| --- | --- | --- |
| Flatten (default) | Files directly beside their ZIP | Quick LMS cleanup |
| Extract | Original hierarchy inside a folder named after the ZIP | Ordinary unzip, code projects, linked assets |
| Organize | Course categories; optional week or topic folders | A growing library of course materials |

Ordinary unzip works on any supported ZIP, without a profile or syllabus. Nested ZIPs
are extracted as files; they are not recursively opened in the same run.

Organization recognizes **Course Info**, **Assignments**, **Quizzes and Exams**,
**Books**, **Labs**, **Practice**, and **Lectures**. Unknown files stay in place.
Choose **by week** or **by topic** to group lectures. Assignments and other categories
stay separate. An explicit week in a filename or LMS section works without a profile;
a profile can map syllabus topics to weeks and route course-code ZIPs to course folders.

For example, with the optional NUST profile and weekly grouping:

```text
Courses/
  Discrete/
    Lectures/Week 02/week 2.pdf
  Quantitative/
    Assignments/CS123 QR BSCS16AB Assignment No 2.docx
    Lectures/Week 07/CS123 Week7 Lecture19.pptx
```

`MATH-125-...zip` routes to Discrete; `CS-123-...zip` routes to Quantitative.
These mappings are optional and editable. **Other people's courses work too:**
[build a profile from simple course and syllabus CSVs](docs/PROFILES.md), or use the
built-in categories without one. No private student information is needed.

### Calculus without week labels

Choose **Organize loose documents only → NUST Fall 2026 → By topic** (or **By week**).
The included rules cover all 42 supplied Calculus filenames. Examples:

| Filename/topic | By week | By topic |
| --- | --- | --- |
| Composition of Functions | Week 01 | Functions |
| Continuity | Week 02 | Limits and continuity |
| Limits | Weeks 02-03 | Limits and continuity |
| Local extrema and concavity | Weeks 04-05 | Extrema and concavity |
| Area between curves | Unscheduled | Areas between curves |

These are syllabus matches, not claims about the actual delivery date. Ambiguous topics
use ranges or Unscheduled. Books and assignments keep their own categories. Preview
shows why each rule matched. Edit the profile if your instructor's schedule differs.

## Command line

With the single-file CLI, open PowerShell in the folder containing the EXE:

```powershell
.\LMS-Unpacker-CLI.exe --help
.\LMS-Unpacker-CLI.exe --menu "C:\Courses"
.\LMS-Unpacker-CLI.exe -Path "C:\Downloads\materials.zip" -Mode Extract -DryRun
.\LMS-Unpacker-CLI.exe -Path "C:\Courses" -Mode Organize -ExistingOnly -GroupBy Topic -RulesPath NUST -DryRun
.\LMS-Unpacker-CLI.exe --profile
.\LMS-Unpacker-CLI.exe --undo "C:\Courses\.lms-unpacker\history\record.json" -DryRun
```

Named options run directly; remove `-DryRun` only after reviewing the plan. A path to
a custom profile JSON also works for `-RulesPath`. No extra PS1/module files are needed.
For launching problems, see [LAUNCH-HELP.txt](LAUNCH-HELP.txt).

The optional modular ZIP is for script users and maintainers. The equivalent source
commands below run from its extracted app folder. `-Path` selects the material to work
on; it defaults to your current working directory, not the script directory.

```powershell
# Quick unpack: flatten, skip existing names, delete ZIP after success
.\Unpack-Lms.ps1 -Path C:\Courses

# See changes without creating, moving, extracting to disk, or deleting anything
.\Unpack-Lms.ps1 -Path C:\Courses -DryRun

# Just unzip, preserving the internal folder hierarchy
.\Unpack-Lms.ps1 -Path 'C:\Downloads\resources.zip' -Mode Extract

# Keep different versions and retain the original archives
.\Unpack-Lms.ps1 -Path C:\Courses -Conflict Rename -KeepZip

# Organize new ZIP contents by category
.\Unpack-Lms.ps1 -Path C:\Courses -Mode Organize

# NUST course routing and weekly groups; also organize existing loose documents
.\Unpack-Lms.ps1 -Path C:\Courses -Mode Organize -GroupBy Week -RulesPath .\profiles\nust.json -OrganizeExisting -DryRun

# Organize already-extracted documents only, without processing any ZIPs
.\Unpack-Lms.ps1 -Path C:\Courses -Mode Organize -ExistingOnly -DryRun
```

Remove `-DryRun` after reviewing the plan. The CLI runs directly; the guided launcher
always previews and asks whether to apply. `-WhatIf` is also a true preview.
A preview reads/decompresses ZIP data in memory to check integrity and content hashes,
so large archives still take time to inspect; it does not create extraction files or logs.

| Option | Default | Purpose |
| --- | --- | --- |
| `-Mode` | `Flatten` | `Flatten`, `Extract`, or `Organize` |
| `-GroupBy` | `Category` | `Category`, `Week` or `Topic`; only used in Organize mode |
| `-Depth` | `1` | `0` = selected folder only; `1` = include immediate course folders |
| `-Conflict` | `Skip` | `Skip`, `Rename`, or explicit `Overwrite` for ZIP extraction |
| `-KeepZip` | Off | Retain successfully processed archives |
| `-OrganizeExisting` | Off | Also move loose documents; requires Organize mode |
| `-ExistingOnly` | Off | Only move loose documents; requires Organize mode |
| `-RulesPath` | None | Optional JSON course/syllabus profile |
| `-MaxEntries` | `10000` | Maximum entries per ZIP |
| `-MaxExpandedGB` | `2` | Maximum expanded size per ZIP (1-100 GB) |
| `-PassThru` | Off | Return counts, errors, matching details, preview status and undo-record path |

`-SkipExisting` and `-Overwrite` remain as compatibility switches. Do not combine them
with each other or with `-Conflict`. Identical content is detected at the intended
filename (including numbered candidates in Rename mode), not globally across unrelated
files. Organization never overwrites or deletes loose source documents on collisions.

## Existing folders and undo

Only loose files in the selected folder and its immediate course folders are scanned.
The scan never descends into projects or course subfolders. Known working/category
folders are excluded from the one-level scan: Lab, Labs, submission, submissions,
templates, Practice, needed, Syllabi, Lectures, Assignments, Quizzes and Exams, Books,
Course Info, evidence, ScreenShots and node_modules. Hidden folders and links are also
excluded. An explicitly selected folder is still processed; use `-Depth 0` to limit it.

Existing-file organization handles PDF, Word, PowerPoint, Excel, ODT, ODP and EPUB
files. Source code, scripts, images, text notes and project assets are left in place.
ZIP organization handles all contained files, so use Extract for code projects and
materials whose internal links depend on their folders.

Each real organization run writes an undo record under the selected folder's
`.lms-unpacker/history`. Its full path is printed. Keep that record in place.

```powershell
.\Undo-Organization.ps1 -ReportPath 'C:\Courses\.lms-unpacker\history\your-record.json' -DryRun
.\Undo-Organization.ps1 -ReportPath 'C:\Courses\.lms-unpacker\history\your-record.json'
```

The launcher also offers Undo. Undo checks all recorded hashes and original locations
before moving anything; changed or missing files and occupied locations stop the operation.
Empty category folders remain. Undo covers **existing-file moves only**: it does not
restore deleted ZIPs or undo extraction/overwrite. If several runs affect the same files,
undo the newest one first.

## Failure handling and supported ZIPs

- Archive entries are validated and staged before files are published. CRC-32 detects
  damaged entry data; SHA-256 compares file contents. CRC is an integrity check, not a
  security signature.
- Traversal paths, absolute paths, invalid Windows filenames, links/special entries,
  password-protected archives and unsupported compression produce an error and retain
  the ZIP. Stored/Deflate ZIP and ZIP64 metadata are supported; split archives are not.
- Destination junctions/symlinks are rejected. Scans do not follow links.
- File writes use a sibling temporary file and atomic move/replacement. If publishing
  fails partway through an archive, already-written files remain and the ZIP is retained.
  Resolve the issue and rerun; this is not an all-or-nothing transaction across the archive.
- ZIPs are permanently deleted after success, including intentional skips. They do not
  go to the Recycle Bin. Use Keep ZIP if you need a recoverable original.
- Avoid concurrent runs against the same folders. Local NTFS folders are recommended;
  network/sync drives, locked files, disk capacity and Windows path limits can cause errors.
- Exit code `0` means success/no work/cancel; `1` means an error. Within a CLI folder scan, mixed batches continue
  with other ZIPs, then exit `1`. Errors organizing existing files stop ZIP processing.

The EXEs launch their embedded scripts with a process-scoped execution policy;
this does not change your account policy.
Organization-managed machines may prohibit scripts or dynamic .NET compilation; follow
that machine's policy. The app is unsigned and does not contain a Windows installer.

## Develop and share

From a repository checkout (the optional modular runtime ZIP omits build tools/tests):

```powershell
.\tests\Run-Tests.ps1
.\Build-Release.ps1
pwsh -NoProfile -File .\Build-Linux.ps1
```

The test suite uses temporary fixtures inside `tests/.runs`, including malicious ZIP
paths, CRC failures, conflicts, grouping, course profiles, undo, and junctions. It never
uses personal course documents. The release builder runs the engine and real WPF-control
tests, then builds `dist/LMS-Unpacker.exe`, `dist/LMS-Unpacker-CLI.exe`, and the optional
`dist/LMS-Unpacker-1.3.1.zip` from an explicit file list. It checks both standalone
executables, CLI behavior, a shortcut in an isolated test folder, and temporary cleanup.
Each artifact gets a SHA-256 checksum. Existing versioned ZIPs are not overwritten;
the stable EXE filenames are refreshed when a new release is built. GitHub Actions runs tests on Windows PowerShell 5.1
and PowerShell 7, tests the same engine and standalone shell launcher on Ubuntu,
and creates downloadable Windows and Linux build artifacts after they pass.
Matching version tags start the attested draft-release workflow described in the
[code signing policy](docs/SIGNING.md).

Share **one desktop EXE, CLI EXE, or Linux shell file** according to the recipient's platform and preference.
They each contain the app, docs, profiles and MIT license; no course documents, tests,
local paths or private reports are included. The optional modular ZIP must be extracted
as a whole if you choose to use the source BAT/PS1 launchers.

Release binaries are currently unsigned. Functional tests do not guarantee acceptance by
every Windows reputation/security policy. Signing and a screen-reader acceptance pass
remain release-distribution tasks before making broad compatibility claims. A forced
process kill may leave an `lms-unpacker-*` temporary runtime folder; normal exit removes it.
See [profile guidance](docs/PROFILES.md), [code signing policy and release provenance](docs/SIGNING.md), and [release changes](CHANGELOG.md).
See [security and reporting guidance](SECURITY.md). The NUST example is unofficial;
this project is not affiliated with NUST or an LMS provider.
