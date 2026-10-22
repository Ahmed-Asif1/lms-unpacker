# Roadmap

These are proposed improvements, not completed features or promised release dates.
The current release already has a visual profile editor, ZIP output selection,
saved workspaces, unclassified review, editable queues, conflict content comparisons,
organization history with undo previews and a Linux CLI.

## Release readiness

- Seek trusted code signing; disclose unsigned builds until a provider approves and integration is verified.
- Complete manual Narrator/NVDA, keyboard-only, high-contrast and 200% display-scaling acceptance tests.
- Add synthetic screenshots and an example download walkthrough without personal course documents.

## Everyday file management

- Extend conflict review with timestamps and per-file decisions (current review shows incoming size and content comparison).
- Profile rule reordering, test-filename preview and overlapping-rule explanations.
- Search/filter previews and select individual files for extraction.
- Resume or retry failed queue items from a saved run report.
- Optional recoverable ZIP deletion, while preserving the current permanent-delete default.
- Workspace export/import with explicit path remapping on another computer.

## Larger improvements

- GitLab CI and release distribution with verified artifact provenance.
- Reviewed syllabus import from PDF/DOCX, with uncertain mappings shown for user approval.
- Search and open organized materials from a course-library view.
- Evaluate a compiled engine and cross-platform GUI to remove runtime setup requirements.

Prioritize signing, accessibility, conflict review and recovery before expanding the
format list or adding network services. Report bugs and proposals through project issues.
