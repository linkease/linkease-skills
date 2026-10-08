#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
smoke="$pack/skills/istoreos-download-acceleration/scripts/smoke.sh"
if sh "$smoke" pip 3.13.7 "$tmp/unapproved" >"$tmp/out" 2>&1; then exit 1; fi
[ ! -e "$tmp/unapproved" ]
grep -F authorization "$tmp/out"
if KAIPLUS_CONFIRMED=1 sh "$smoke" pip latest "$tmp/bad-version" >"$tmp/out" 2>&1; then exit 1; fi
[ ! -e "$tmp/bad-version" ]
grep -F 'complete installed version' "$tmp/out"
mkdir "$tmp/existing"
echo preserve >"$tmp/existing/sentinel"
if KAIPLUS_CONFIRMED=1 sh "$smoke" npm 24.21.0 "$tmp/existing" >"$tmp/out" 2>&1; then exit 1; fi
grep -F 'new directory' "$tmp/out"
grep -Fx preserve "$tmp/existing/sentinel"
sh -n "$smoke"
echo 'ok: smoke examples require authorization and an isolated new directory'
