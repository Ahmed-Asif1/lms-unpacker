# Code signing policy

Current status: Windows binaries are unsigned unless a release explicitly states otherwise.
No certificate provider has approved or sponsored this project yet. The app works offline;
it has no telemetry, login, updater or runtime downloads. Optional Start menu installation
is initiated by the user and can be removed as described in the README.

## Maintainer responsibilities

LMS Unpacker is independently maintained. The current author/committer, reviewer of
external contributions, and prospective signing approver is
[Ahmed-Asif1 (Muhammad Ahmed Asif)](https://github.com/Ahmed-Asif1).
The GitLab mirror is maintained under [ahmed007asif](https://gitlab.com/ahmed007asif).
Contributions from non-committers require maintainer review before merging. Build and
workflow changes receive the same review attention as application code.

Before using SignPath, all people with signing or source-repository access must enable
multi-factor authentication. This is a requirement, not a claim that anyone's account
configuration has been verified here. Every SignPath release signing request will require
manual approval by the maintainer; passing CI alone will not approve signing.

The application does not transmit user data to a signing service. Local settings and
history are described in the [privacy policy](../PRIVACY.md). Downloads and their current
signature status are listed on the [download page](DOWNLOADS.md).

## Application status and provider credit

We are preparing an application to the SignPath Foundation. Approval has not been received,
and current Windows downloads remain unsigned. After approval and verified integration,
eligible release pages will carry the credit: "Free code signing provided by SignPath.io,
certificate by SignPath Foundation." That sentence describes the planned credit, not
the status of current releases. We will not use provider badges or claim sponsorship early.

## Free options

**SignPath Foundation** offers free signing for eligible open-source projects. Read its
[conditions](https://signpath.org/terms) and [application](https://signpath.org/apply).
An application needs a maintained, documented, already-released open-source project and
an approved build/signing process. Approval is not automatic. Its certificate identifies
SignPath Foundation as publisher; it is not a free personal certificate in your own name.
After approval, integrate the provider's signing step into the release build **before**
generating SHA-256 files and GitHub attestations. Do not add a provider badge or claim
signed releases before that integration and approval exist.

A **self-signed development certificate** is free but is not publicly trusted. It can
identify your test builds on machines you explicitly configure for development; it will
not make other people's Windows installations trust them. Do not ask users to install
your certificate as a root or disable protection to run the app.

For a private development certificate, Windows PowerShell provides:

```powershell
$devCert = New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=LMS Unpacker Development' -CertStoreLocation Cert:\CurrentUser\My
$devCert.Thumbprint
```

This creates a key in your personal certificate store, not a publicly trusted identity.
No script here installs certificates into trusted-root stores or exports private keys.
Certificate creation and trust changes are not performed by the application.

## Sign with your existing developer certificate

Use Windows PowerShell 5.1 to list public metadata for code-signing certificates:

```powershell
Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object Subject, Thumbprint, NotAfter, HasPrivateKey
```

Build the release, then sign both EXEs using the certificate thumbprint:

```powershell
.\Sign-Release.ps1 -Thumbprint YOUR_CERTIFICATE_THUMBPRINT
# For private testing with an untrusted/self-signed certificate only:
.\Sign-Release.ps1 -Thumbprint YOUR_CERTIFICATE_THUMBPRINT -AllowUntrustedForTesting
```

The helper validates certificate usage, validity and private-key availability. Optionally
supply `-TimestampServer` with your signing provider's supported Authenticode timestamp
URL. It refreshes checksums after signing. Without a timestamp, signatures may stop
validating after certificate expiry. Provider-managed/HSM keys may need the provider's
own tooling rather than this helper. Keep keys and PFX passwords out of Git and logs.

Signing changes the bytes. A local signature does **not** inherit an attestation for an
unsigned CI build. Public release signing must occur in the authenticated build before
attestation; never replace attested release assets with different local builds.

## GitHub release provenance

`release.yml` runs only on a matching `vVERSION` tag (or a manual run selected on that tag).
It waits for Windows and Linux tests, builds from that commit, attests the final downloads,
verifies the attestations and checksums, then creates a **draft** GitHub Release. Review
the draft and publish it yourself. Existing releases are not overwritten on reruns.
Third-party Actions are pinned to full commit hashes and Dependabot proposes updates.
Pull-request test jobs receive no signing/release permissions or project secrets.

After testing and committing a version, a maintainer can start the release with:

```bash
git tag v1.3.1
git push origin v1.3.1
```

Users can verify a downloaded artifact using the GitHub CLI:

```bash
gh attestation verify LMS-Unpacker.exe --repo Ahmed-Asif1/lms-unpacker
```

[Attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations)
prove build origin, not that software is harmless. They are separate from Windows
Authenticode signatures. [SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation)
may warn even for a new signed build. Neither mechanism guarantees an account will
never be flagged or suspended by GitHub.
