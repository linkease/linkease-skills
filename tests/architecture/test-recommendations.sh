#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)"

fail() {
  echo "failed: $*" >&2
  exit 1
}

for pack_id in windows macos; do
  catalog="$root/components/system-packs/$pack_id/recommendations.json"
  [ -f "$catalog" ] || fail "$pack_id recommendations are missing"
  jq -e '
    .schemaVersion == 1 and
    (.catalogVersion | type == "string" and length > 0) and
    (.recommendations | length > 0) and
    ([.recommendations[].id] | length == (unique | length)) and
    all(.recommendations[];
      (.id | test("^[a-z0-9][a-z0-9.-]*$")) and
      (.title | type == "string" and length > 0) and
      (.prompt | type == "string" and length > 0) and
      (.category | IN("common", "apps", "network", "storage", "maintenance", "advanced")) and
      (.executionIntent | IN("read_only", "may_modify", "heavy_write")) and
      (.workspaceRequirement | IN("none", "durable")))
  ' "$catalog" >/dev/null || fail "$pack_id recommendation contract is invalid"

  jq -r '.recommendations[] | select(.skill != null) | .skill' "$catalog" |
  while IFS= read -r skill; do
    [ -f "$root/components/system-packs/$pack_id/skills/$skill/SKILL.md" ] ||
      fail "$pack_id recommendation references missing skill $skill"
  done

  if jq -r '.recommendations[] | (.requires // [])[]' "$catalog" |
    grep -E '^(ssh|winrm|helper|remote-control)(:|$)' >/dev/null; then
    fail "$pack_id recommendations depend on a Transport or Install Preset"
  fi
done

echo "System Pack recommendations: PASS"
