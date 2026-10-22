#!/usr/bin/env bash
# Self-contained application payload; requires an installed PowerShell 7 runtime.
set -euo pipefail
if ! command -v pwsh >/dev/null 2>&1; then
  printf '%s\n' 'LMS Unpacker requires PowerShell 7 (pwsh).' 'Install it using the official instructions: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux' >&2
  exit 127
fi
runtime="$(mktemp -d "${TMPDIR:-/tmp}/lms-unpacker.XXXXXXXX")"
trap 'rm -rf -- "$runtime"' EXIT
awk 'payload { print } /^__LMS_PAYLOAD__$/ { payload=1 }' "$0" | base64 --decode > "$runtime/app.zip"
cat > "$runtime/launch.ps1" <<'POWERSHELL'
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$LaunchArguments)
$ErrorActionPreference='Stop'
try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $PSScriptRoot 'app.zip'),(Join-Path $PSScriptRoot 'app'))
    & (Join-Path $PSScriptRoot 'app/Start-Cli.ps1') @LaunchArguments
    exit $LASTEXITCODE
} catch { Write-Error $_; exit 1 }
POWERSHELL
pwsh -NoLogo -NoProfile -File "$runtime/launch.ps1" "$@"
exit $?
__LMS_PAYLOAD__
