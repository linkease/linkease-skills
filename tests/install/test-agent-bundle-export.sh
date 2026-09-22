#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/linkease-agent-export.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  echo "failed: $*" >&2
  exit 1
}

for output in first second; do
  sh "$root/tools/export-agent-bundle.sh" \
    --platform istoreos \
    --mode on-device \
    --consumer opencode \
    --output "$tmp/$output" >/dev/null
done

jq -e '
  .schemaVersion == 1 and
  .platform == "istoreos" and
  .mode == "on-device" and
  .consumer == "opencode" and
  (.sourceCommit | test("^[a-f0-9]{40}$")) and
  (.sourceDigest | test("^sha256:[a-f0-9]{64}$")) and
  (.treeDigest | test("^sha256:[a-f0-9]{64}$")) and
  (.skills | length > 0)
' "$tmp/first/manifest.json" >/dev/null || fail "invalid bundle manifest"

[ -f "$tmp/first/agents/system.md" ] || fail "system Agent instruction is missing"
[ -f "$tmp/first/agents/istoreos.md" ] || fail "iStoreOS Agent instruction is missing"
[ -f "$tmp/first/home-prompts.json" ] || fail "home prompts are missing"
[ ! -e "$tmp/first/skills/target-ssh-controller" ] || fail "on-device bundle contains SSH transport"

first_digest="$(jq -r '.treeDigest' "$tmp/first/manifest.json")"
second_digest="$(jq -r '.treeDigest' "$tmp/second/manifest.json")"
[ "$first_digest" = "$second_digest" ] || fail "bundle export is not deterministic"
diff -ru --exclude manifest.json "$tmp/first" "$tmp/second" >/dev/null || fail "bundle trees differ"

jq -r '.skills[]' "$tmp/first/manifest.json" |
while IFS= read -r name; do
  [ -f "$tmp/first/skills/$name/SKILL.md" ] || fail "manifest references missing skill $name"
done

echo "OpenCode Agent bundle export: PASS"
