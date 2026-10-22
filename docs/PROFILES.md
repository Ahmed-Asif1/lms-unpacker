# Your courses and syllabus

Organization works without a profile: filenames identify assignments, quizzes, books,
course outlines, labs, practice sheets and lectures. A profile adds your course names,
ZIP routing and syllabus topic rules. It is optional, local, and reusable each semester.
The tool does not upload documents or require an LMS login.

The desktop also has **Edit courses and syllabus**: edit two labeled tables, then save a validated profile copy. In a preview, **Show only unclassified files** and **Add rule for selected file** can seed a new rule. The rule starts as an exact filename match; broaden its pattern deliberately for future downloads.

## Build a profile using CSV

In the desktop app, select an Organize task and click **Import profile from CSV**.
Choose a courses CSV, optionally a syllabus CSV, and a new JSON filename. The generated
profile is selected automatically. The independent CLI provides the same builder with
`LMS-Unpacker-CLI.exe --profile`. Open the embedded visual guide to download sample CSVs.
The source-script command below is an alternative for the modular package.

1. Copy `profiles/courses.example.csv` and `profiles/syllabus.example.csv` to your own files.
2. Edit them in a text editor or spreadsheet application, saving as **UTF-8 CSV**.
3. List each course in the courses file:

```csv
Code,Folder,Name
BIO-101,Biology,Introduction to Biology
ENG-201,Writing,Academic Writing
```

`Code` is the prefix of the LMS download, such as `BIO-101` in
`BIO-101-F26_20261021.zip`. Codes can contain letters, digits and hyphens.
`Folder` is the name you want on disk: one folder name, not a nested path.
`Name` is a human-readable label. Codes and folders must be unique.

4. Turn relevant syllabus topics into filename patterns:

```csv
Code,Week,Pattern,Folder,Topic,Reason
BIO-101,1,*cell structure*,,Cells,Week 1 in my syllabus
BIO-101,2,*photosynthesis*,,Photosynthesis,Week 2 in my syllabus
BIO-101,,*reading list*,Course Info,,Reference list
ENG-201,1,*essay structure*,,Essay structure,Week 1 in my syllabus
ENG-201,,*rubric*,Assignments,,Assignment reference
```

`Pattern` matches filenames, case-insensitively: `*` means any text, `?` one character.
It uses PowerShell wildcard syntax, not a regular expression. Quote CSV values containing commas.
`Week` creates `Lectures/Week 01` etc. An explicit `Folder` overrides `Week`.
Keep the header, including both Week and Folder columns.
`Topic` and `Reason` are optional columns. Topic is a single folder name for topic
grouping; Reason explains the match in the preview. For a range, leave Week empty and
use `Lectures/Weeks 02-03` in Folder. For a known topic without an evidenced week, use
`Lectures/Unscheduled` and supply its Topic.

5. Generate and preview:

```powershell
.\New-CourseProfile.ps1 -CoursesCsv .\courses.csv -SyllabusCsv .\syllabus.csv -OutputPath .\my-courses.json
.\Unpack-Lms.ps1 -Path C:\Courses -Mode Organize -GroupBy Week -RulesPath .\my-courses.json -OrganizeExisting -DryRun
```

Omit `-SyllabusCsv` if you only want course-code routing. Select the resulting JSON
in the launcher under **My JSON profile**. Remove `-DryRun` to apply a CLI preview.

## Matching and grouping

- Rules run in listed order; the first matching rule wins. Put specific patterns first.
- Spaces, underscores and hyphens are treated alike in simple patterns, so
  `*cell structure*` also matches `cell_structure.pdf`. Patterns using wildcard character
  classes (`[...]`) retain literal punctuation handling.
- Rules override built-in categories. Avoid broad rules such as `*` unless intentional.
- Rules match a course code when a profile recognizes the containing course folder or ZIP prefix.
  Without a matching course, they match the containing folder's name.
- `-GroupBy Week` uses an explicit filename week, an LMS `Week 7` section, or your profile's topic rules.
- `-GroupBy Category` collapses `Lectures/Week NN` destinations to `Lectures`.
- `-GroupBy Topic` uses the rule's Topic under `Lectures`. Lectures without a matching
  topic use `Lectures/Unsorted topics`; no topic is guessed from lecture numbers.
- Week grouping puts lectures with no known week in `Lectures/Unscheduled`.
- A lecture number is not a week number. Dates such as `19 October - 25 October` are not converted
  into weeks: semester starts, breaks and different course schedules make that unreliable.
- Unknown files stay where they are. Unknown ZIP courses unpack beside their ZIP;
  classified entries can still go into categories there.
- Existing loose files are organized within their containing course folder. They are never
  guessed into a different course based on topic keywords.
- If a ZIP course code conflicts with its containing course folder, that ZIP is retained with an error.

The program does not read PDF/Word syllabi or infer their meaning. Use your syllabus to
write a small set of explicit patterns; no full transcription is required. Preview to check
ambiguous topics before applying. Several courses can teach the same topic in different weeks.

## Edit JSON directly

```json
{
  "Version": 1,
  "Courses": [{ "Code": "BIO-101", "Folder": "Biology", "Name": "Biology" }],
  "Rules": [{ "Course": "BIO-101", "Pattern": "*photosynthesis*", "Folder": "Lectures/Week 02", "Topic": "Photosynthesis", "Reason": "Week 2 in my syllabus" }]
}
```

`Course` also supports wildcards, including `*` for all courses. Rule output folders are
relative to the course directory. Parent traversal, absolute paths and Windows reserved
names are rejected. Use a new filename when regenerating a profile; the builder never
silently replaces one.

## Included NUST profile

`profiles/nust.json` maps CS-110, CS-117, CS-123, HU-131, MATH-101 and MATH-125 to
the supplied course folder names. It includes a conservative subset of topic rules from
the Fall 2026 schedule. It is a starting point, not an official syllabus, and is never
enabled by default. Review and adapt it for another semester. It contains no student
identifiers, submissions or course documents.

The Calculus mapping covers the 42 supplied filenames, including files without week
labels. Limits span Weeks 02-03; combined extrema/concavity spans Weeks 04-05. Area
between curves has a topic but no evidenced week, so it remains Unscheduled in weekly
mode. These rules describe the supplied syllabus, not verified teaching dates.
