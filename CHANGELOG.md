# Changelog

## 1.4.0

- Discover ZIPs beside the portable EXE and in immediate course folders on startup;
  fall back to a remembered location, while respecting explicit launch inputs.
- Add background filename discovery, a ZIPs found tab, Rescan, Use app folder,
  and selection of discovered archives for a narrower preview.
- Start first-use folder and ZIP pickers beside the app and remember their locations
  independently, including selections made before extraction. Migrate old preferences.
- Group advanced extraction options, saved workspaces, queues and app settings into
  separate sections. Show organization tools and conflict columns only when relevant.
- Add descriptive hover tooltips and accessibility help text, including saved-workspace details.
- Expand the offline guide with interactive scan depth, desktop orientation, searchable
  option help, startup behavior, keyboard use and recovery explanations.
- Share scan rules between discovery and processing, with one-level boundaries and
  existing protection for working folders and filesystem links.

## 1.3.1

- Make work immediately visible with a prominent progress panel, current file and phase,
  input/ZIP counts, elapsed time, and Windows taskbar progress.
- Keep a completion panel with extracted/skipped/organized counts, ZIP retention outcome,
  and an Open result folder action. Distinguish preview, cancellation and errors.
- Report verified-file publication progress as well as archive-reading progress.
- Add desktop checks for immediate, in-progress and terminal feedback states.

## 1.3.0

- Add organization history discovery with record status and validated undo previews.
- Explain identical and different content conflicts, including earlier queued outputs,
  with source archive, incoming size and SHA-256 details in the desktop and CLI.
- Reorder, promote and remove queued inputs; invalidate previews when order changes.
- Publish download, privacy, contribution and code-signing policies with honest unsigned status.
- Add maintainer application guidance and community issue templates; update the offline guide.
- Preserve default skip-existing and delete-successful-ZIP behavior.

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
