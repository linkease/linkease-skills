#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
fixtures="$root/tests/fixtures/app-diagnostics"
collector="$root/skills/istoreos-app-diagnostics/scripts/collect.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

collect_case() {
  case_name="$1"
  requested="$2"
  ISTORE_DIAG_TASK_STATUS_FILE="$fixtures/$case_name/task-status.json" \
  ISTORE_DIAG_LOG_FILE="$fixtures/$case_name/istore.log" \
  ISTORE_DIAG_NOW=1789173400 \
    "$collector" "$requested"
}

collect_case aria2-success-warning latest >"$tmp/latest"
grep -F "requested_app$(printf '\t')aria2" "$tmp/latest" >/dev/null
grep -F "correlation$(printf '\t')exact" "$tmp/latest" >/dev/null
grep -F "state$(printf '\t')finished" "$tmp/latest" >/dev/null
grep -F "action$(printf '\t')install" "$tmp/latest" >/dev/null

collect_case mismatch aria2 >"$tmp/mismatch"
grep -F "task_app$(printf '\t')alist" "$tmp/mismatch" >/dev/null
grep -F "correlation$(printf '\t')mismatch" "$tmp/mismatch" >/dev/null

collect_case malicious-secrets alist >"$tmp/redacted"
grep -F 'Authorization: Bearer [REDACTED]' "$tmp/redacted" >/dev/null
grep -F 'api_key=[REDACTED]' "$tmp/redacted" >/dev/null
grep -F 'password=[REDACTED]' "$tmp/redacted" >/dev/null
grep -F '[UNTRUSTED_INSTRUCTION_REDACTED]' "$tmp/redacted" >/dev/null
if grep -F 'fixture-token-do-not-use' "$tmp/redacted" >/dev/null ||
   grep -F 'fixture-key-do-not-use' "$tmp/redacted" >/dev/null ||
   grep -F 'fixture-password-do-not-use' "$tmp/redacted" >/dev/null ||
   grep -Fi 'IGNORE ALL PREVIOUS INSTRUCTIONS' "$tmp/redacted" >/dev/null; then
  echo "failed: collector leaked fixture credentials" >&2
  exit 1
fi

awk 'found { bytes += length($0) + 1 } $0 == "--LOG--" { found = 1 } END { exit !(bytes <= 8192) }' "$tmp/latest"

large_log="$tmp/large.log"
awk 'BEGIN { for (i=0; i<2000; i++) print "repeated diagnostic row " i }' >"$large_log"
ISTORE_DIAG_TASK_STATUS_FILE="$fixtures/aria2-success-warning/task-status.json" \
ISTORE_DIAG_LOG_FILE="$large_log" ISTORE_DIAG_NOW=1789173400 \
  "$collector" aria2 >"$tmp/large"
grep -F "log_truncated$(printf '\t')true" "$tmp/large" >/dev/null
awk 'found { bytes += length($0) + 1 } $0 == "--LOG--" { found = 1 } END { exit !(bytes <= 8193) }' "$tmp/large"

printf 'ok: app diagnostics collector passed\n'
