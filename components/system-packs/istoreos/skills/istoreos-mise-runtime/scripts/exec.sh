#!/bin/sh
# Feed a complete program to the shell-only mise-exec entrypoint.
set -eu
program="${1:-}"
[ -n "$program" ] && [ -f "$program" ] || { echo 'usage: exec.sh PROGRAM_FILE [ARG...]' >&2; exit 2; }
program="$(CDPATH= cd -- "$(dirname "$program")" && pwd -P)/$(basename "$program")"
shift
system_root="${ISTORE_SYSTEM_ROOT:-}"
if [ ! -f "$system_root/etc/openwrt_release" ] && ! grep -Eiq '^(ID|ID_LIKE)=.*(openwrt|istoreos)' "$system_root/etc/os-release" 2>/dev/null; then
  echo 'failed: unsupported-system: mise-exec belongs to the iStore/OpenWrt integration, not Ubuntu' >&2
  exit 4
fi
command -v mise-exec >/dev/null 2>&1 || { echo 'failed: integrated mise-exec is missing; inspect the system package' >&2; exit 4; }
command -v uci >/dev/null 2>&1 || { echo 'failed: UCI runtime integration is missing' >&2; exit 4; }
runtime_dir="$(uci -q get mise.main.runtime_dir)" || { echo 'failed: runtime directory is not configured; use system integration setup' >&2; exit 4; }
case "$runtime_dir" in /*) ;; *) echo 'failed: configured runtime directory must be absolute' >&2; exit 4 ;; esac
[ -d "$runtime_dir" ] && [ -w "$runtime_dir" ] || { echo 'failed: runtime directory is unavailable or not writable; inspect its mount' >&2; exit 4; }
# The program and its arguments are serialized without eval or shell substitution.
payload="$(mktemp "${TMPDIR:-/tmp}/istore-runtime.XXXXXX")"
trap 'rm -f "$payload"' EXIT HUP INT TERM
quote() { printf "'"; printf '%s' "$1" | sed "s/'/'\\\\''/g"; printf "'"; }
{
  printf 'set --'
  for arg in "$@"; do printf ' '; quote "$arg"; done
  printf '\nexport ISTORE_RUNTIME_ENTERED=1\nexec sh '
  quote "$program"
  printf ' "$@"\n'
} >"$payload"
status=0
mise-exec <"$payload" || status=$?
exit "$status"
