#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)"
catalog="$root/components/system-packs/istoreos/home-prompts.json"

fail() {
  echo "failed: $*" >&2
  exit 1
}

jq -e '
  .version == 5 and
  (.prompts | length == 26) and
  ([.prompts[].id] | length == (unique | length)) and
  ([.prompts[].priority] | length == (unique | length)) and
  all(.prompts[];
    (.id | test("^[a-z0-9][a-z0-9-]*$")) and
    (.category | IN("common", "apps", "network", "storage", "repair", "advanced")) and
    (.priority | type == "number") and
    (.title | type == "string" and length > 0) and
    (.description | type == "string" and length > 0) and
    (.prompt | type == "string" and length > 0) and
    (.risk | IN("low", "medium", "high")) and
    (.executionIntent | IN("read_only", "may_modify", "heavy_write")) and
    (.scope == "device") and
    (.workspaceRequirement | IN("none", "durable")) and
    (.estimatedWriteBytes | type == "number" and . > 0) and
    ((.requiredContext // []) | type == "array"))
' "$catalog" >/dev/null || fail "iStoreOS home prompt contract is invalid"

jq -e '
  ([.prompts[].id] | index("istoreos-backup-restore") == null) and
  ([.prompts[].id] | index("istoreos-backup-config") != null) and
  ([.prompts[].id] | index("istoreos-restore-config") != null) and
  (.prompts[] | select(.id == "istoreos-backup-config") |
    .executionIntent == "heavy_write" and
    (.prompt | contains("不要在这个任务中执行恢复"))) and
  (.prompts[] | select(.id == "istoreos-restore-config") |
    .executionIntent == "heavy_write" and
    (.requiredContext == ["backup_location", "restore_scope"]))
' "$catalog" >/dev/null || fail "backup and restore prompts are not safely separated"

jq -e '
  [
    .prompts[] |
    select(.requiredContext != null) |
    select(.prompt | contains("请先向我询问") | not)
  ] | length == 0
' "$catalog" >/dev/null || fail "a contextual prompt does not require clarification"

jq -e '
  ([.prompts[] | select(.executionIntent == "read_only") | .id] | sort) ==
  ([
    "istoreos-app-search",
    "istoreos-ask-anything",
    "istoreos-disk-sleep",
    "istoreos-dns-abnormal",
    "istoreos-health-check",
    "istoreos-source-introspect",
    "istoreos-speed-slow",
    "kaiplus-self-check"
  ] | sort) and
  all(.prompts[] | select(.executionIntent == "read_only");
    (.risk == "low") and (.workspaceRequirement == "none"))
' "$catalog" >/dev/null || fail "read-only prompt allowlist or resource contract changed"

echo "iStoreOS home prompt contract: PASS"
