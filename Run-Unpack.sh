#!/usr/bin/env bash
set -euo pipefail
if ! command -v pwsh >/dev/null 2>&1; then
  printf '%s\n' 'LMS Unpacker requires PowerShell 7 (pwsh).' 'Install it using the official instructions: https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-linux' >&2
  exit 127
fi
root="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec pwsh -NoLogo -NoProfile -File "$root/Start-Cli.ps1" "$@"
