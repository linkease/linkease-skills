#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
observe="$root/skills/istoreos-system-task-router/scripts/observe.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

if sh "$observe" unknown >"$tmp/out" 2>"$tmp/err"; then
  echo 'failed: observer accepted an unknown mode' >&2
  exit 1
fi
grep -q 'supported modes' "$tmp/err"

if sh "$observe" service '../shadow' >"$tmp/out" 2>"$tmp/err"; then
  echo 'failed: observer accepted a traversal subject' >&2
  exit 1
fi
grep -q 'invalid identifier' "$tmp/err"

sh "$observe" auto >"$tmp/auto"
grep -q '^evidence_version=1$' "$tmp/auto"
grep -q '^mode=auto$' "$tmp/auto"
grep -q '^observed_at=' "$tmp/auto"
grep -q '^source=current-device$' "$tmp/auto"
[ "$(wc -c <"$tmp/auto" | tr -d ' ')" -le 8192 ]

echo 'ok: unknown-problem observer emits a bounded read-only evidence card'
