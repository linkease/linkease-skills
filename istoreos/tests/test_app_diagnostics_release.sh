#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
skill="$root/skills/istoreos-app-diagnostics"
fixtures="$root/tests/fixtures/app-diagnostics"
export ISTORE_STORE_RESPONSE_FILE="$root/tests/fixtures/store-catalog.json"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

sh "$root/drills/profile-smoke.sh"

for script in "$skill"/scripts/*.sh "$root"/tests/test_app_diagnostics_*.sh; do
  [ -x "$script" ] || { echo "failed: executable bit missing: $script" >&2; exit 1; }
  sh -n "$script"
done

ISTORE_DIAG_ROOT="$fixtures/aria2-success-warning/rootfs" \
ISTORE_DIAG_TASK_STATUS_FILE="$fixtures/aria2-success-warning/task-status.json" \
ISTORE_DIAG_LOG_FILE="$fixtures/aria2-success-warning/istore.log" ISTORE_DIAG_NOW=1789173400 \
  "$skill/scripts/inspect.sh" aria2 >"$tmp/default.json"
ISTORE_DIAG_ROOT="$fixtures/malicious-secrets/rootfs" \
ISTORE_DIAG_TASK_STATUS_FILE="$fixtures/malicious-secrets/task-status.json" \
ISTORE_DIAG_LOG_FILE="$fixtures/malicious-secrets/istore.log" ISTORE_DIAG_NOW=1789173400 \
  "$skill/scripts/inspect.sh" alist --detail all >"$tmp/detail.json"

[ "$(wc -c <"$tmp/default.json")" -le 8192 ] || { echo 'failed: default report exceeds 8 KiB' >&2; exit 1; }
[ "$(wc -c <"$tmp/detail.json")" -le 32768 ] || { echo 'failed: detail report exceeds 32 KiB' >&2; exit 1; }
[ "$(wc -c <"$skill/data/first-party-apps.jsonl")" -le 16384 ] || { echo 'failed: compact first-party app index exceeds 16 KiB' >&2; exit 1; }

if grep -R -E 'sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' "$skill" "$root/tests" >/dev/null 2>&1; then
  echo 'failed: possible credential material found in diagnostic sources' >&2
  exit 1
fi

if [ -n "${ISTOREOS_APP_HUB_ROOT:-}" ]; then
  make -C "$ISTOREOS_APP_HUB_ROOT" apps-diagnostics-check
  cmp "$ISTOREOS_APP_HUB_ROOT/docs/app-diagnostics.jsonl" "$skill/data/first-party-apps.jsonl" >/dev/null || {
    echo 'failed: skill app index differs from istoreos-app-hub output' >&2
    exit 1
  }
fi

printf 'ok: app diagnostics release gate passed\n'
