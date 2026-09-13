#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
fixture="$root/tests/fixtures/store-catalog.json"
fetch="$root/skills/istoreos-app-search/scripts/fetch-store.sh"
search="$root/skills/istoreos-app-search/scripts/search.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
command -v jq >/dev/null 2>&1 || { echo 'skip: jq required'; exit 0; }

ISTORE_STORE_RESPONSE_FILE="$fixture" "$fetch" >"$tmp/apps.jsonl"
[ "$(wc -l <"$tmp/apps.jsonl" | tr -d ' ')" = 5 ]
jq -se 'map(.name) | index("aria2") != null and index("alist") != null' "$tmp/apps.jsonl" >/dev/null

ISTORE_STORE_RESPONSE_FILE="$fixture" "$search" aria2 3 >"$tmp/aria2.json"
jq -e 'length == 1 and .[0].name == "aria2" and .[0].compatibility == "store-filtered" and (.[] | has("score") | not)' "$tmp/aria2.json" >/dev/null

ISTORE_STORE_RESPONSE_FILE="$fixture" "$search" docker 3 >"$tmp/docker.json"
jq -e '.[0].name == "alist" and .[0].type_hint == "docker"' "$tmp/docker.json" >/dev/null

ISTORE_STORE_RESPONSE_FILE="$fixture" "$search" 服务 2 >"$tmp/services.json"
jq -e 'length <= 2 and any(.[]; .name == "cups")' "$tmp/services.json" >/dev/null
[ "$(wc -c <"$tmp/services.json")" -lt 4096 ]

ISTORE_STORE_RESPONSE_FILE="$fixture" "$search" '家庭照片自动备份' 3 >"$tmp/photos.json"
jq -e 'length >= 1 and .[0].name == "immich" and .[0].ownership == "first-party" and (.[] | has("fit"))' "$tmp/photos.json" >/dev/null

ISTORE_STORE_RESPONSE_FILE= \
ISTORE_STORE_API='http://127.0.0.1:1/unavailable' \
ISTORE_AI_HELPER_BASE='http://127.0.0.1:1' \
ISTORE_STORE_TIMEOUT=1 "$search" fastnet 3 >"$tmp/offline.json"
jq -e 'length == 1 and .[0].name == "fastnet" and .[0].catalog_source == "first-party-offline"' "$tmp/offline.json" >/dev/null

printf 'ok: full Store catalog fetch and local Top-N search passed\n'
