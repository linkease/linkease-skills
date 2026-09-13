#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
fixtures="$root/tests/fixtures/app-diagnostics"
inspect="$root/skills/istoreos-app-diagnostics/scripts/inspect.sh"
schema="$root/skills/istoreos-app-diagnostics/data/report-schema.json"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
command -v jq >/dev/null 2>&1 || { echo 'skip: jq required'; exit 0; }
export ISTORE_STORE_RESPONSE_FILE="$root/tests/fixtures/store-catalog.json"

run_case() {
  case_name="$1"; requested="$2"
  ISTORE_DIAG_ROOT="$fixtures/$case_name/rootfs" \
  ISTORE_DIAG_TASK_STATUS_FILE="$fixtures/$case_name/task-status.json" \
  ISTORE_DIAG_LOG_FILE="$fixtures/$case_name/istore.log" ISTORE_DIAG_NOW=1789173400 \
    "$inspect" "$requested"
}

run_case aria2-success-warning aria2 >"$tmp/aria2.json"
jq -e '
  .schema_version == 1 and .requested_app == "aria2" and
  .result.outcome == "success_with_warnings" and
  .device.package_installed == true and .device.meta_present == true and
  .device.autoconf_present == true and .device.init_script_present == true and
  .device.config_present == true and .limits.historical_log_available == true
' "$tmp/aria2.json" >/dev/null
jq -e 'any(.evidence[]; .code == "STORE_CATALOG_MATCH" and (.message | contains("scope=all")))' "$tmp/aria2.json" >/dev/null
[ "$(wc -c <"$tmp/aria2.json")" -lt 8192 ]

run_case mismatch aria2 >"$tmp/mismatch.json"
jq -e '.task.correlation == "mismatch" and .limits.historical_log_available == false and .result.outcome == "unknown"' "$tmp/mismatch.json" >/dev/null

ISTORE_DIAG_ROOT="$tmp/no-history" ISTORE_DIAG_TASK_STATUS_FILE=/dev/null ISTORE_DIAG_LOG_FILE=/dev/null \
  "$inspect" aria2 >"$tmp/no-history.json"
jq -e '.task.correlation == "none" and .task.package == null and .limits.historical_log_available == false' "$tmp/no-history.json" >/dev/null

# A zero exit without an installed package is not success.
empty_root="$tmp/empty-root"
mkdir -p "$empty_root/usr/lib/opkg"
: >"$empty_root/usr/lib/opkg/status"
ISTORE_DIAG_ROOT="$empty_root" \
ISTORE_DIAG_TASK_STATUS_FILE="$fixtures/aria2-success-warning/task-status.json" \
ISTORE_DIAG_LOG_FILE="$fixtures/aria2-success-warning/istore.log" ISTORE_DIAG_NOW=1789173400 \
  "$inspect" aria2 >"$tmp/not-installed.json"
jq -e '.result.outcome == "package_install_failed" and .result.primary_code == "APP_NOT_INSTALLED"' "$tmp/not-installed.json" >/dev/null

# Installed package plus autoconf script, but its requested data path disappeared.
missing_path_root="$tmp/missing-path-root"
mkdir -p "$missing_path_root/usr/lib/opkg/meta" "$missing_path_root/usr/libexec/istorea"
cp "$fixtures/aria2-success-warning/rootfs/usr/lib/opkg/status" "$missing_path_root/usr/lib/opkg/status"
cp "$fixtures/aria2-success-warning/rootfs/usr/lib/opkg/meta/aria2.json" "$missing_path_root/usr/lib/opkg/meta/aria2.json"
cp "$fixtures/aria2-success-warning/rootfs/usr/libexec/istorea/aria2.sh" "$missing_path_root/usr/libexec/istorea/aria2.sh"
ISTORE_DIAG_ROOT="$missing_path_root" \
ISTORE_DIAG_TASK_STATUS_FILE="$fixtures/aria2-success-warning/task-status.json" \
ISTORE_DIAG_LOG_FILE="$fixtures/aria2-success-warning/istore.log" ISTORE_DIAG_NOW=1789173400 \
  "$inspect" aria2 >"$tmp/missing-path.json"
jq -e '.result.outcome == "autoconf_failed" and .result.primary_code == "TARGET_PATH_UNAVAILABLE"' "$tmp/missing-path.json" >/dev/null

# Basic schema contract without adding a host json-schema dependency.
jq -e --slurpfile schema "$schema" '
  .schema_version == $schema[0].properties.schema_version.const and
  ([.result.outcome] - $schema[0].properties.result.properties.outcome.enum | length == 0) and
  ([.task.correlation] - $schema[0].properties.task.properties.correlation.enum | length == 0) and
  (.evidence | length <= $schema[0].properties.evidence.maxItems)
' "$tmp/aria2.json" >/dev/null

ISTORE_DIAG_ROOT="$fixtures/aria2-success-warning/rootfs" \
ISTORE_DIAG_TASK_STATUS_FILE="$fixtures/aria2-success-warning/task-status.json" \
ISTORE_DIAG_LOG_FILE="$fixtures/aria2-success-warning/istore.log" ISTORE_DIAG_NOW=1789173400 \
  "$inspect" aria2 --detail autoconf >"$tmp/detail.json"
jq -e '.detail.phase == "autoconf" and (.detail.log_excerpt | contains("Auto configure aria2"))' "$tmp/detail.json" >/dev/null
[ "$(wc -c <"$tmp/detail.json")" -lt 32768 ]
if jq -r '.detail.log_excerpt' "$tmp/detail.json" | grep -F 'Installing app-meta' >/dev/null; then
  echo 'failed: autoconf detail leaked unrelated package-phase rows' >&2
  exit 1
fi

printf 'ok: app diagnostics device reconstruction and inspect report passed\n'
