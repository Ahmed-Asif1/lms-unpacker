#!/usr/bin/env bash
set -euo pipefail
repo="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/lms-shell-test.XXXXXXXX")"
trap 'rm -rf -- "$fixture"' EXIT
mkdir "$fixture/standalone & spaces"
cp "$repo/dist/LMS-Unpacker-CLI.sh" "$fixture/standalone & spaces/unpacker.sh"
app="$fixture/standalone & spaces/unpacker.sh"
bash -n "$app"
bash "$app" --help
export LMS_TEST_ROOT="$fixture"
pwsh -NoProfile -Command '
  $zip=[IO.Compression.ZipFile]::Open((Join-Path $env:LMS_TEST_ROOT "sample.zip"),"Create")
  try { $writer=[IO.StreamWriter]::new($zip.CreateEntry("nested/hello.txt").Open()); $writer.Write("hello"); $writer.Dispose() } finally { $zip.Dispose() }
'
bash "$app" -Path "$fixture/sample.zip" -OutputPath "$fixture/output" -Mode Extract -DryRun
test -f "$fixture/sample.zip"
test ! -e "$fixture/output"
bash "$app" -Path "$fixture/sample.zip" -OutputPath "$fixture/output" -Mode Extract
test ! -f "$fixture/sample.zip"
test "$(cat "$fixture/output/sample/nested/hello.txt")" = hello
if bash "$app" -Path "$fixture/missing.zip"; then
  printf '%s\n' 'Missing input incorrectly returned success' >&2
  exit 1
fi
printf '%s\n' 'PASS: Independent Linux launcher, quoted paths, preview, extraction and error status'
