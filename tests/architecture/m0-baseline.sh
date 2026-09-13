#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)"
inventory="$root/tests/architecture/m0-istoreos-inventory.tsv"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/linkease-skills-m0.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  echo "failed: $*" >&2
  exit 1
}

collect_names() {
  base="$1"
  for path in "$base"/*; do
    [ -f "$path/SKILL.md" ] || continue
    basename "$path"
  done
}

[ -f "$inventory" ] || fail "missing inventory: $inventory"

{
  collect_names "$root/istoreos/skills"
  collect_names "$root/remote-control-istoreos"
} | sort -u >"$tmp/discovered"

awk -F '\t' 'NR > 1 { print $1 }' "$inventory" | sort -u >"$tmp/recorded"
diff -u "$tmp/discovered" "$tmp/recorded" >/dev/null || {
  diff -u "$tmp/discovered" "$tmp/recorded" >&2 || true
  fail "M0 inventory does not cover every iStoreOS skill"
}

awk -F '\t' '
  NR == 1 {
    if ($0 != "skill\tlocal\tremote\tbaseline_relation\tmigration_decision") exit 1
    next
  }
  NF != 5 || $1 == "" || ($2 != "yes" && $2 != "no") ||
    ($3 != "yes" && $3 != "no") || $4 == "" || $5 == "" { exit 1 }
' "$inventory" || fail "invalid M0 inventory format"

sh "$root/istoreos/drills/profile-smoke.sh"
sh "$root/remote-control-istoreos/drills/profile-smoke.sh"
sh -n "$root/install.sh" "$root/package.sh"

local_count="$(collect_names "$root/istoreos/skills" | wc -l | tr -d ' ')"
remote_count="$(collect_names "$root/remote-control-istoreos" | wc -l | tr -d ' ')"
local_body_bytes="$(wc -c "$root"/istoreos/skills/*/SKILL.md | awk 'END { print $1 }')"
remote_body_bytes="$(wc -c "$root"/remote-control-istoreos/*/SKILL.md | awk 'END { print $1 }')"
diverged_count="$(awk -F '\t' '$4 == "diverged" { count++ } END { print count + 0 }' "$inventory")"

printf '%s\n' \
  "M0 recorded baseline: PASS" \
  "current_local_skill_count=$local_count" \
  "current_remote_extension_count=$remote_count" \
  "current_local_skill_body_bytes=$local_body_bytes" \
  "current_remote_extension_body_bytes=$remote_body_bytes" \
  "recorded_diverged_skill_count=$diverged_count"
