#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fake="$tmp/fake-tool"
log="$tmp/calls.log"
printf '%s\n' '#!/bin/sh' 'printf "%s\\n" "$*" >> "${HELPER_CALL_LOG:?}"' 'exit 0' > "$fake"
chmod +x "$fake"
export HELPER_CALL_LOG="$log"

systools="$root/skills/istoreos-systools/scripts/apply.sh"
mise_install="$root/skills/istoreos-mise-runtime/scripts/install.sh"

if SYSTOOLS_BIN="$fake" "$systools" ipv6_pd >/dev/null 2>&1; then
  echo "failed: systools helper ran without confirmation" >&2
  exit 1
fi
[ ! -s "$log" ]

KAIPLUS_CONFIRMED=1 SYSTOOLS_BIN="$fake" "$systools" ipv6_pd
grep -Fx 'ipv6_pd' "$log" >/dev/null

if KAIPLUS_CONFIRMED=1 SYSTOOLS_BIN="$fake" "$systools" reset_rom_pkgs >/dev/null 2>&1; then
  echo "failed: unreviewed systools action was accepted" >&2
  exit 1
fi

if KAIPLUS_CONFIRMED=1 SYSTOOLS_BIN="$fake" "$systools" speedtest >/dev/null 2>&1; then
  echo "failed: network speed test remained in the systools allowlist" >&2
  exit 1
fi

: > "$log"
if MISE_ISTORE_BIN="$fake" "$mise_install" python 3.13 >/dev/null 2>&1; then
  echo "failed: mise helper ran without confirmation" >&2
  exit 1
fi
[ ! -s "$log" ]

KAIPLUS_CONFIRMED=1 MISE_ISTORE_BIN="$fake" "$mise_install" nodejs lts
grep -Fx 'use --global node@lts' "$log" >/dev/null
grep -Fx 'which node' "$log" >/dev/null
grep -Fx 'exec -- node --version' "$log" >/dev/null

if KAIPLUS_CONFIRMED=1 MISE_ISTORE_BIN="$fake" "$mise_install" ruby latest >/dev/null 2>&1; then
  echo "failed: unsupported runtime was accepted" >&2
  exit 1
fi

echo "ok: system helper contracts passed"
