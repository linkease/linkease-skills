#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
catalog="$root/skills/istoreos-app-diagnostics/data/first-party-apps.jsonl"
lookup="$root/skills/istoreos-app-diagnostics/scripts/catalog.sh"
command -v jq >/dev/null 2>&1 || { echo 'skip: jq required'; exit 0; }

lines="$(wc -l <"$catalog" | tr -d ' ')"
unique="$(jq -sr 'map(.id) | unique | length' "$catalog")"
[ "$lines" -ge 60 ] && [ "$lines" = "$unique" ]
jq -se 'map(.id) == (map(.id) | sort)' "$catalog" >/dev/null
jq -e 'select(.id == "fastnet") | .autoconf == true and .luci == true' "$catalog" >/dev/null
jq -e 'select(.type == "docker" and .istorec == true)' "$catalog" >/dev/null

"$lookup" fastnet | grep -F "catalog_match$(printf '\t')true" >/dev/null
"$lookup" app-not-in-index | grep -F "catalog_match$(printf '\t')false" >/dev/null

printf 'ok: bundled app diagnostics catalog passed (%s apps)\n' "$lines"
