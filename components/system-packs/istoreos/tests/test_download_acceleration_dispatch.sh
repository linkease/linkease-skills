#!/bin/sh
set -eu

profile_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
dispatcher="$profile_root/skills/istoreos-download-acceleration/scripts/dispatch.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin"

printf '%s\n' \
  '#!/bin/sh' \
  'printf '\''%s\n'\'' "$*" >"$TEST_CURL_LOG"' \
  'printf '\''%s\n'\'' '\''{"input":"https://github.com/example/project.git","output":"https://gh.linkease.net:5443/example/project.git","admin_path":"/gh/example/project.git"}'\''' \
  >"$tmp/bin/curl"

printf '%s\n' \
  '#!/bin/sh' \
  'printf '\''%s\n'\'' "$@" >"$TEST_GIT_LOG"' \
  >"$tmp/bin/git"

chmod +x "$tmp/bin/curl" "$tmp/bin/git"

TEST_CURL_LOG="$tmp/curl.log"
TEST_GIT_LOG="$tmp/git.log"
export TEST_CURL_LOG TEST_GIT_LOG

PATH="$tmp/bin:$PATH" sh "$dispatcher" git-clone \
  "https://github.com/example/project.git" "$tmp/project"

grep -F '"url":"https://github.com/example/project.git"' "$TEST_CURL_LOG" >/dev/null

expected="$(printf 'clone\n--\n%s\n%s\n' \
  'https://gh.linkease.net:5443/example/project.git' "$tmp/project")"
actual="$(cat "$TEST_GIT_LOG")"
[ "$actual" = "$expected" ] || {
  echo "failed: unexpected git arguments" >&2
  printf 'expected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
  exit 1
}

echo "ok: download acceleration git-clone dispatch passed"
