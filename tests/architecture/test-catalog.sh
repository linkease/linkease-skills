#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)"
catalog="$root/catalog.json"

fail() {
  echo "failed: $*" >&2
  exit 1
}

command -v jq >/dev/null 2>&1 || fail "jq is required for catalog validation"
jq -e '.schemaVersion == 1 and .defaultPolicy.installAll == false' "$catalog" >/dev/null || fail "invalid catalog policy"

duplicates="$(jq -r '.presets[].id' "$catalog" | sort | uniq -d)"
[ -z "$duplicates" ] || fail "duplicate preset ids: $duplicates"

duplicates="$(jq -r '.presets[] | [.platform, .mode] | @tsv' "$catalog" | sort | uniq -d)"
[ -z "$duplicates" ] || fail "duplicate platform/mode presets: $duplicates"

jq -e '.presets[] | (.aliases | length > 0)' "$catalog" >/dev/null || fail "every preset needs aliases"

jq -r '.presets[] | [.id, .path, .skillsRoot] | @tsv' "$catalog" |
while IFS="$(printf '\t')" read -r id path skills_root; do
  case "$path/$skills_root" in
    /*|*/../*|../*|*/..) fail "unsafe preset path for $id" ;;
  esac
  [ -d "$root/$path/$skills_root" ] || fail "missing skills root for $id: $path/$skills_root"
done

for expected in 'istoreos\ton-device\tistoreos-on-device' 'istoreos\tremote-control\tistoreos-remote-control'; do
  platform="$(printf '%b' "$expected" | cut -f1)"
  mode="$(printf '%b' "$expected" | cut -f2)"
  id="$(printf '%b' "$expected" | cut -f3)"
  actual="$(jq -r --arg platform "$platform" --arg mode "$mode" '[.presets[] | select(.platform == $platform and .mode == $mode) | .id] | if length == 1 then .[0] else "" end' "$catalog")"
  [ "$actual" = "$id" ] || fail "cannot uniquely resolve $platform/$mode"
done

grep -F 'Never install every platform by default.' "$root/AGENTS.md" >/dev/null || fail "AGENTS.md lacks safe default"

echo "ok: catalog contracts passed"
