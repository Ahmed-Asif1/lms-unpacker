# Security

LMS Unpacker is an offline archive utility. It does not request LMS credentials,
contact an LMS, upload files, or download executable components. Its source and
build scripts are available in this repository under the MIT license.

The portable executables unpack their embedded, readable application files to a
temporary directory and launch Windows PowerShell. The desktop hides the console
while displaying its native window. The launch policy applies to that child process;
the app does not change machine policy or disable antivirus protections. The optional
Start menu action copies the app to the current user's Programs folder only when
the user clicks it.

The default operation skips existing filenames and permanently deletes a ZIP after
successful processing, including deliberate skips. Use a preview and choose Keep ZIP
or Rename when needed. Existing-file organization has an undo record; ZIP deletion
and extraction do not. The README documents archive limits and failure behavior.

## Reporting a problem

Use this repository's **Security → Advisories → Report a vulnerability** option when
available. Otherwise, open an issue asking for a private reporting channel without
posting exploit details, credentials, personal documents, or real course archives.
For ordinary bugs, provide the app version, error text and a minimal synthetic example.

Please do not commit or attach private LMS exports, copyrighted course documents,
textbooks, student identifiers, access tokens, signing keys or personal undo records.
Filename-only test fixtures and manually written matching rules contain no document
contents. The optional NUST example is unofficial and does not imply endorsement.

## Downloads

Obtain executables from this repository's GitHub Releases and compare their SHA-256
checksums when needed. Release binaries are currently unsigned. Source can be reviewed
and built locally; a checksum verifies bytes, not publisher identity or a malware verdict.
Do not disable security software to run the app. Report suspected false detections to
the security vendor and include the exact release version and checksum.
