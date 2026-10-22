# Download LMS Unpacker

LMS Unpacker is a free, MIT-licensed, offline ZIP extractor and course organizer.
Use it for ordinary extraction, removing LMS wrapper folders, or organizing materials
by course, category, week or topic. No LMS account or institution-specific setup is required.

**[Open the official release downloads](https://github.com/Ahmed-Asif1/lms-unpacker/releases/latest)**

| Download | Platform and use |
| --- | --- |
| `LMS-Unpacker.exe` | Windows desktop app: double-click, choose files, preview and apply. |
| `LMS-Unpacker-CLI.exe` | Independent Windows command-line app with a guided menu. |
| `LMS-Unpacker-CLI.sh` | Independent Linux launcher; run with Bash. Requires installed PowerShell 7. |
| `LMS-Unpacker-VERSION.zip` | Optional modular runtime for users who prefer the source launchers. |

Choose one edition. The standalone downloads embed their application support files.
The automatically generated Source code archives contain the repository snapshot.
See the [README](../README.md) for requirements, commands, keyboard operation and uninstall instructions.

## Before extracting

Defaults are **flatten, skip existing filenames and permanently delete successfully
processed ZIPs**, including incoming files deliberately skipped because a name exists.
Preview first. Keep ZIP retains archives; Rename retains differing incoming versions.
Errors retain the affected ZIP, but completed file writes can remain. Only loose-document
organization has undo; extraction and ZIP deletion do not.

## Code signing policy

**Current Windows downloads are unsigned. We are preparing an application to the
[SignPath Foundation](https://signpath.org/) for free open-source code signing.**
There is no approval, sponsorship or SignPath-signed release to claim at this time.
After approval and integration, eligible signed releases will identify the provider
and certificate explicitly. See the [code signing policy](SIGNING.md) for responsible
maintainers, build provenance and the approval process, and the [privacy policy](../PRIVACY.md)
for local data handling.

GitHub build attestations establish build origin and are separate from Windows code
signatures. Each download has a SHA-256 sidecar. To verify provenance with the GitHub CLI:

```bash
gh attestation verify LMS-Unpacker.exe --repo Ahmed-Asif1/lms-unpacker
```

Do not disable security protections to run a download. For an unexpected detection,
follow the [security reporting guidance](../SECURITY.md).

## Source and feedback

- [Main source repository](https://github.com/Ahmed-Asif1/lms-unpacker)
- [GitLab source mirror](https://gitlab.com/ahmed007asif/lms-unpacker)
- [Build and test runs](https://github.com/Ahmed-Asif1/lms-unpacker/actions)
- [Bug reports](https://github.com/Ahmed-Asif1/lms-unpacker/issues)

The project is independent and is not affiliated with a university or LMS provider.
