#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
fetch="$root/skills/istoreos-app-search/scripts/fetch-store.sh"
first_party="$root/skills/istoreos-app-diagnostics/data/first-party-apps.jsonl"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

"$fetch" >"$tmp/store.jsonl"
store_count="$(wc -l <"$tmp/store.jsonl" | tr -d ' ')"
first_party_count="$(wc -l <"$first_party" | tr -d ' ')"
[ "$store_count" -gt "$first_party_count" ] || {
  echo "failed: Store catalog ($store_count) is not larger than first-party index ($first_party_count)" >&2
  exit 1
}
printf 'ok: live Store catalog contains %s apps; first-party source index contains %s\n' "$store_count" "$first_party_count"
