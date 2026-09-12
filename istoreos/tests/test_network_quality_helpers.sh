#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin"
calls="$tmp/fastnet.calls"

printf '%s\n' \
  '#!/bin/sh' \
  'printf "%s\\n" "$@" >> "${FASTNET_CALL_LOG:?}"' \
  '[ "${1:-}" != version ] || printf "%s\\n" "0.7.7-test"' \
  >"$tmp/bin/FastNet"

printf '%s\n' \
  '#!/bin/sh' \
  '[ "${1:-}" != status ] || printf "%s\\n" "running"' \
  >"$tmp/fastnet.init"

printf '%s\n' \
  '#!/bin/sh' \
  'case "${3:-}" in' \
  '  "fastnet.@fastnet[0].enabled") printf "%s\\n" 1 ;;' \
  '  "fastnet.@fastnet[0].port") printf "%s\\n" 3200 ;;' \
  '  "fastnet.@fastnet[0].logger") printf "%s\\n" 0 ;;' \
  '  "fastnet.@fastnet[0].token") printf "%s\\n" super-secret-token ;;' \
  'esac' \
  >"$tmp/bin/uci"

chmod +x "$tmp/bin/FastNet" "$tmp/bin/uci" "$tmp/fastnet.init"
export FASTNET_CALL_LOG="$calls"

inspect="$root/skills/istoreos-network-quality/scripts/inspect.sh"
runner="$root/skills/istoreos-network-quality/scripts/run.sh"

inspect_output="$(PATH="$tmp/bin:$PATH" FASTNET_BIN="$tmp/bin/FastNet" FASTNET_INIT="$tmp/fastnet.init" "$inspect")"
printf '%s\n' "$inspect_output" | grep -Fx 'fastnet=available' >/dev/null
printf '%s\n' "$inspect_output" | grep -Fx 'version=0.7.7-test' >/dev/null
printf '%s\n' "$inspect_output" | grep -Fx 'token_configured=yes' >/dev/null
if printf '%s\n' "$inspect_output" | grep -F 'super-secret-token' >/dev/null; then
  echo "failed: inspect output exposed the FastNet token" >&2
  exit 1
fi

: >"$calls"
if FASTNET_BIN="$tmp/bin/FastNet" "$runner" quick >/dev/null 2>&1; then
  echo "failed: quick test ran without confirmation" >&2
  exit 1
fi
[ ! -s "$calls" ]

if KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" unknown >/dev/null 2>&1; then
  echo "failed: unsupported mode was accepted" >&2
  exit 1
fi
[ ! -s "$calls" ]

KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" quick
grep -Fx 'quick' "$calls" >/dev/null

: >"$calls"
KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" multi
grep -Fx 'multi-stream' "$calls" >/dev/null

: >"$calls"
KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" nat
grep -Fx 'nat' "$calls" >/dev/null

: >"$calls"
KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" ipv6
grep -Fx 'ipv6' "$calls" >/dev/null

: >"$calls"
KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" wan 1234
expected="$(printf 'speedtest_one\n--json\n--server\n1234')"
actual="$(cat "$calls")"
[ "$actual" = "$expected" ] || {
  printf 'failed: unexpected WAN arguments\nexpected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
  exit 1
}

: >"$calls"
if KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" lan router.lan:3200 14 >/dev/null 2>&1; then
  echo "failed: unsafe LAN parallelism was accepted" >&2
  exit 1
fi
[ ! -s "$calls" ]

if KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" lan bad:host:3200 4 >/dev/null 2>&1; then
  echo "failed: ambiguous LAN address was accepted" >&2
  exit 1
fi
[ ! -s "$calls" ]

KAIPLUS_CONFIRMED=1 FASTNET_BIN="$tmp/bin/FastNet" "$runner" lan 192.168.1.2:3200 4
expected="$(printf 'homebox_cli\n--addr\n192.168.1.2:3200\n--parallel\n4')"
actual="$(cat "$calls")"
[ "$actual" = "$expected" ] || {
  printf 'failed: unexpected LAN arguments\nexpected:\n%s\nactual:\n%s\n' "$expected" "$actual" >&2
  exit 1
}

echo "ok: network quality helper contracts passed"
