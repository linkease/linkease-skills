#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/linkease-skills-m5.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  echo "failed: $*" >&2
  exit 1
}

sh -n "$root/install.sh"
list="$(sh "$root/install.sh" --list)"
[ "$(printf '%s\n' "$list" | wc -l | tr -d ' ')" -eq 4 ] || fail "text list must contain four presets"
sh "$root/install.sh" --list --json | jq -e 'length == 4' >/dev/null
sh "$root/install.sh" --describe istoreos-remote-control |
  jq -e '.platform == "istoreos" and .mode == "remote-control"' >/dev/null

if sh "$root/install.sh" >"$tmp/out" 2>"$tmp/question"; then
  fail "installer guessed a platform"
fi
[ "$(wc -l <"$tmp/question" | tr -d ' ')" -eq 1 ] || fail "missing platform should ask one question"
grep -Fx 'Which device platform do you want to manage?' "$tmp/question" >/dev/null

if sh "$root/install.sh" --platform istoreos >"$tmp/out" 2>"$tmp/question"; then
  fail "installer guessed on-device versus remote-control"
fi
[ "$(wc -l <"$tmp/question" | tr -d ' ')" -eq 1 ] || fail "missing mode should ask one question"
grep -Fx 'Will the Agent run on the device, or control it remotely?' "$tmp/question" >/dev/null

dry_target="$tmp/dry-run-must-not-exist"
dry_output="$(sh "$root/install.sh" --platform istoreos --mode remote-control \
  --consumer generic --target-skills "$dry_target" --dry-run)"
[ ! -e "$dry_target" ] || fail "dry-run changed the filesystem"
printf '%s\n' "$dry_output" | grep -Fx 'preset=istoreos-remote-control' >/dev/null
[ "$(printf '%s\n' "$dry_output" | grep -c '^skill=')" -eq 22 ] || fail "remote dry-run did not list 22 skills"

sh "$root/install.sh" --platform istoreos --mode on-device --consumer generic \
  --target-skills "$tmp/generic" >/dev/null
[ "$(find "$tmp/generic" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" -eq 20 ] ||
  fail "generic on-device install count is wrong"

CODEX_HOME="$tmp/codex" sh "$root/install.sh" --platform istoreos \
  --mode remote-control --consumer codex >/dev/null
[ -f "$tmp/codex/skills/target-ssh-controller/SKILL.md" ] || fail "Codex target resolution failed"

XDG_CONFIG_HOME="$tmp/config" sh "$root/install.sh" --platform istoreos \
  --mode on-device --consumer opencode >/dev/null
[ -f "$tmp/config/opencode/skills/istoreos-package-manager/SKILL.md" ] ||
  fail "OpenCode target resolution failed"

legacy="$(sh "$root/install.sh" --profile remote-control-istoreos \
  --target-skills "$tmp/legacy" --dry-run 2>"$tmp/legacy-notice")"
grep -F -- '--profile is deprecated' "$tmp/legacy-notice" >/dev/null || fail "legacy command lacks migration notice"
printf '%s\n' "$legacy" | grep -Fx 'preset=istoreos-remote-control' >/dev/null

sh "$root/tools/verify-generated.sh"
echo "M5 discovery and install UX: PASS"
