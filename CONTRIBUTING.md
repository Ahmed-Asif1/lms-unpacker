# Contributing

Start with a small issue describing the problem, expected behavior and an example made
from synthetic files. Search existing issues first. Discuss substantial engine, interface
or dependency changes before implementing them. The [roadmap](docs/ROADMAP.md) lists
priorities, not delivery promises.

## Development

The main repository is [GitHub](https://github.com/Ahmed-Asif1/lms-unpacker); GitLab is
a source mirror. Submit a pull request against `main` on GitHub. Contributions are under
the repository's MIT license. Maintain respectful, specific discussions about the work.

On Windows, run the checks relevant to your change:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Run-Tests.ps1
pwsh -NoProfile -File tests/Run-Tests.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File Start-Desktop.ps1 -SmokeTest
pwsh -NoProfile -File tests/Test-Portable.ps1
```

On Linux, with PowerShell 7 installed:

```bash
pwsh -NoProfile -File tests/Test-Portable.ps1
pwsh -NoProfile -File Build-Linux.ps1
bash tests/Test-Linux.sh
```

Synthetic test fixtures are created under `tests/.runs`. Tests must not touch real course
folders. Packaging checks verify the independent downloads. Pure documentation edits need
link/content review rather than unrelated new tests. Describe what you verified in the PR.

## Preserve user expectations

- Preserve the defaults: skip existing names and delete successfully processed ZIPs,
  including deliberate skips. Preview must not mutate user files.
- Do not weaken path containment, link rejection, archive limits, integrity checks or
  undo validation. Add focused regression coverage when changing those behaviors.
- Keep ordinary unzip independent of course profiles. Profiles must work for arbitrary
  courses; uncertain syllabus dates should remain uncertain in the UI.
- Preserve keyboard access and clear labels. Include manual accessibility observations
  for UI changes, and distinguish automated checks from screen-reader testing.
- Keep runtime behavior offline. Any proposed network functionality needs explicit design
  discussion and corresponding privacy documentation before implementation.
- Never commit personal downloads, textbooks, student information, credentials, private
  keys, local settings, screenshots with private paths, or generated executables.

## Review and releases

The maintainer reviews contributions from external contributors before merging, including
changes to CI and packaging. Releases must come from version tags and pass the automated
Windows/Linux checks. Signing keys and release credentials do not belong in source or
pull-request jobs. Any future SignPath signing request requires manual maintainer approval.
See the [code signing policy](docs/SIGNING.md) and [SECURITY.md](SECURITY.md).
