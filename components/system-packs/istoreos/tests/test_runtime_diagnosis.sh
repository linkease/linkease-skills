#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
check() {
  printf '%s\n' "$2" >"$tmp/evidence"
  sh "$pack/skills/istoreos-mise-runtime/scripts/diagnose.sh" "$tmp/evidence" >"$tmp/result"
  grep -F "diagnosis=$1:" "$tmp/result"
}
check pip-launcher-realpath 'pip: realpath: not found'
check precompiled-unavailable 'no compatible precompiled python archive'
check source-build 'python-build configure: error: no acceptable C compiler found in $PATH'
check venv-not-active 'VIRTUAL_ENV missing: venv not activated'
check integrity-or-tls 'download failed: TLS certificate verification'
check version-selection 'selected python 3.9.9 unexpectedly'
check version-selection 'requested version invalid'
check download 'python-build download failed: connection timed out'
check unclassified 'backend exited 19 without diagnostic output'
echo 'ok: runtime diagnoses distinguish launcher, selection, build, environment and network evidence'
