#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
schema="$root/skills/istoreos-app-diagnostics/data/report-schema.json"
fixtures="$root/tests/fixtures/app-diagnostics"

command -v jq >/dev/null 2>&1 || {
  echo "skip: jq is required for host-side contract validation"
  exit 0
}

jq -e '
  .type == "object" and
  .properties.schema_version.const == 1 and
  (.properties.result.properties.outcome.enum | length == 8) and
  (.properties.task.properties.correlation.enum == ["exact", "mismatch", "none"]) and
  (.properties.evidence.maxItems == 12) and
  .properties.limits.properties.untrusted_log.const == true
' "$schema" >/dev/null

case_count=0
while IFS="$(printf '\t')" read -r case_name requested_app outcome code correlation; do
  case "$case_name" in ''|'#'*) continue ;; esac
  case_count=$((case_count + 1))
  case "$outcome" in
    success|success_with_warnings|in_progress|package_install_failed|dependency_failed|autoconf_failed|runtime_failed|unknown) ;;
    *) echo "failed: invalid expected outcome for $case_name: $outcome" >&2; exit 1 ;;
  esac
  case "$correlation" in exact|mismatch|none) ;; *) echo "failed: invalid correlation: $correlation" >&2; exit 1 ;; esac
  [ -n "$requested_app" ] && [ -n "$code" ]
  jq -e '.running | type == "boolean"' "$fixtures/$case_name/task-status.json" >/dev/null
  [ -s "$fixtures/$case_name/istore.log" ]
done <"$fixtures/cases.tsv"

[ "$case_count" -ge 5 ] || { echo "failed: expected at least five diagnostic cases" >&2; exit 1; }
grep -F 'app-meta-aria2' "$fixtures/aria2-success-warning/task-status.json" >/dev/null
grep -F 'success_with_warnings' "$fixtures/cases.tsv" >/dev/null

if grep -R -E 'sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----' "$fixtures" >/dev/null 2>&1; then
  echo "failed: fixture tree appears to contain a real credential pattern" >&2
  exit 1
fi

printf 'ok: app diagnostics contract and %s fixture cases passed\n' "$case_count"
