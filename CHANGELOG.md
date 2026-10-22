# Changelog

## 1.2.1

- Keep the visual profile editor's Save label readable under Windows PowerShell 5.1's legacy encoding.
- Avoid running a duplicate test workflow on release tags; the release workflow already calls the complete suite.

## 1.2.0

- Add a visual course/syllabus editor and unclassified-file review with reusable rules.
- Add optional ZIP output folders, saved desktop workspaces and multi-input queues.
- Report current file/entry progress and support cancellation at safe boundaries.
- Share collision planning across queued inputs and reject overlapping input scopes.
- Add a standalone Linux shell distribution using the same engine (PowerShell 7 required).
- Add Windows/Linux checks and a tag-based draft release workflow with GitHub build attestations.
- Document free signing options and provide an optional existing-certificate signing helper.
- Preserve skip-existing and delete-successful-ZIP defaults, preview and organization undo.

## 1.1.0

- Ship independent single-file desktop and CLI executables with embedded offline resources.
- Add a native desktop interface with folder/ZIP pickers, drag-and-drop, background work,
  preview destinations and reasons, explicit Apply, undo and locally remembered last path.
- Add optional per-user Start menu installation and shortcut removal.
- Support topic grouping and optional Topic/Reason syllabus columns for any course.
- Map all supplied Calculus filenames conservatively, including week ranges and Unscheduled topics.
- Speed up existing-file previews by avoiding unnecessary content reads when no collision exists.
- Add blocked-parent detection, portable launch help, desktop flow tests and packaged executable checks.
- Update the offline visual tutorial for the desktop, CLI and files without week labels.

## 1.0.1

- Add an offline visual HTML tutorial with interactive folder examples and a five-step launcher walkthrough.
- Include opening instructions, weekly grouping, custom syllabus profiles, keyboard navigation and recovery guidance.
- Bundle the tutorial in the release and point new users to it from the launcher.
- Retry brief I/O failures during atomic file replacement, including undo-record saves.

## 1.0.0

- Default to skipping existing filenames and deleting successfully processed ZIPs.
- Add ordinary unzip, flatten, course categories, and optional weekly grouping.
- Route LMS ZIP course codes using optional, editable profiles.
- Include an optional NUST profile and a CSV profile builder for other courses.
- Add a guided keyboard launcher, explicit previews and undo for existing-file organization.
- Validate archive paths, CRCs, entry counts and expanded sizes before publishing files.
- Keep ZIPs on failures; replace individual files atomically when overwrite is requested.
- Add Windows PowerShell 5.1 / PowerShell 7 integration tests and portable release packaging.

### Migration from the original script

Copy the entire release folder: the script now uses a module and a small C# integrity helper.
The previous default renamed conflicting files; use `-Conflict Rename` to retain that behavior.
`-SkipExisting`, `-Overwrite`, `-KeepZip`, and `-DryRun` remain available.
`Run-Unpack.bat.txt` has been replaced by a working `Run-Unpack.bat` launcher.
