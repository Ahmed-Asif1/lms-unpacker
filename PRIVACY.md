# Privacy policy

Effective date: 22 October 2026

LMS Unpacker is an offline, open-source utility maintained by
[Ahmed-Asif1](https://github.com/Ahmed-Asif1). It does not send your documents,
filenames, settings or usage information to the maintainer or a signing provider.
It has no accounts, telemetry, advertising, analytics, automatic crash reporting,
cloud processing, background updater or runtime downloads.

## Files processed on your computer

The app reads the folders, ZIP archives and course profiles you select. It reads file
contents to extract archives, check integrity, compare collisions and protect undo
operations. All of this processing happens locally. Organization rules match filenames
and profile entries; the app does not upload or automatically interpret your syllabus.
Choosing a network drive or a cloud-synced folder can cause your operating system or
sync provider to transfer files under that provider's settings.

## Local settings, history and temporary files

- The Windows desktop saves the last successful folder and named workspaces in
  `%LOCALAPPDATA%\LMS Unpacker\preferences.json`. Workspaces can contain selected paths,
  queued paths, output locations, profile paths and your selected options.
- Saved course profiles remain in the JSON files you choose. They can contain course
  codes, topic names, filename patterns and notes.
- Existing-file organization writes undo records to `.lms-unpacker/history` beneath
  the selected folder. Records contain file paths, content hashes and move states.
- The activity view and CLI output contain paths and diagnostic messages. They are not
  automatically sent anywhere. If you redirect CLI output to a file, you control that file.
- Portable builds extract their embedded program into a temporary `lms-unpacker-*`
  directory. Archive processing can stage contents in `lms-unpack-*` directories.
  Normal completion cleans up temporary files; an interrupted process can leave them behind.
- The optional Start menu action copies the Windows app to
  `%LOCALAPPDATA%\Programs\LMS Unpacker` and creates a per-user shortcut. It does not
  register an account or send installation information to us.

Local settings and records are not encrypted by this application. Other software or
people with access to your user account may be able to read them.

## Your choices and deletion

Use the workspace Remove button to forget a saved workspace. Close the app before
deleting `preferences.json` to reset all remembered desktop settings. You can delete
your profile files and undo records yourself; removing an undo record removes that
operation's recovery instructions. These records cannot restore deleted ZIPs.
For app and shortcut removal, see the [README](README.md#start-menu-optional).

The default extraction behavior permanently deletes successfully processed ZIPs,
including deliberately skipped incoming files. Choose Keep ZIP when you want to retain
them. This is local file management, not a data-retention service operated by us.

## Websites, support and signing

Downloading from [GitHub](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement)
or [GitLab](https://about.gitlab.com/privacy/) uses those services, subject to their
policies. Opening an external documentation link uses your browser and the destination
website's policy. The bundled visual tutorial itself uses no analytics or remote assets.

If you voluntarily submit an issue, comment or attachment, that platform and the
maintainer receive what you submit. Public issues are visible to others. Use synthetic
examples and remove personal paths, student details, course documents and credentials.
See [SECURITY.md](SECURITY.md) for reporting security concerns.

Code signing and build attestation, when used, concern the application's build artifacts;
the running app does not send user files to a signing service. Signing status is disclosed
in the [code signing policy](docs/SIGNING.md).

For a privacy question, open a project issue requesting a private contact channel without
including sensitive details. Future changes to this policy will be recorded in Git history.
