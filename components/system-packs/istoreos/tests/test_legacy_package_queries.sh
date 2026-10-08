#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/system/etc" "$tmp/system/usr/lib/opkg" "$tmp/bin"
printf '%s\n' 'DISTRIB_ID="iStoreOS"' >"$tmp/system/etc/openwrt_release"
: >"$tmp/system/usr/lib/opkg/status"
export ISTORE_SYSTEM_ROOT="$tmp/system" TEST_CALLS="$tmp/calls"
cat >"$tmp/bin/opkg" <<'EOF'
#!/bin/sh
printf '%s\n' "opkg $*" >>"$TEST_CALLS"
case "$1" in
  --help) [ "${TEST_NATIVE_FIND:-0}" = 0 ] || echo '  find <regexp>'; exit 0 ;;
  find) [ "${TEST_NATIVE_FIND_EMPTY:-0}" = 0 ] || exit 0
    printf '%s\n' 'luci-app-alpha - 1.0 - First plugin' 'luci-app-beta - 1.0 - Second plugin' 'mise - 1.0 - Runtime' ;;
  list) printf '%s\n' 'luci-app-alpha - 1.0 - First plugin' 'luci-app-beta - 1.0 - Second plugin' 'mise - 1.0 - Runtime' ;;
  info)
    case "$2" in luci-app-alpha|luci-app-beta) printf 'Package: %s\nVersion: 1.0\n' "$2" ;; esac
    ;;
  search) printf '%s\n' 'curl: /usr/bin/curl' 'libcurl: /usr/lib/libcurl.so' ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$tmp/bin/opkg"
export PATH="$tmp/bin:$PATH"
scripts="$pack/skills/istoreos-package-manager/scripts"
sh "$scripts/opkg-find.sh" 'luci-app-.*' 1 >"$tmp/result"
[ "$(cat "$tmp/result")" = 'luci-app-alpha - 1.0 - First plugin' ]
sh "$scripts/opkg-find.sh" luci 1 >"$tmp/result"
[ "$(wc -l <"$tmp/result" | tr -d ' ')" = 1 ]
TEST_NATIVE_FIND=1 sh "$scripts/opkg-find.sh" 'luci-app-.*' 1 >"$tmp/result"
[ "$(cat "$tmp/result")" = 'luci-app-alpha - 1.0 - First plugin' ]
grep -Fx 'opkg find luci-app-.*' "$TEST_CALLS"
TEST_NATIVE_FIND=1 TEST_NATIVE_FIND_EMPTY=1 sh "$scripts/opkg-find.sh" 'luci-app-.*' 1 >"$tmp/result"
[ "$(cat "$tmp/result")" = 'luci-app-alpha - 1.0 - First plugin' ]
TEST_NATIVE_FIND=1 TEST_NATIVE_FIND_EMPTY=1 sh "$scripts/opkg-info.sh" 'luci-app-.*' 1 >"$tmp/result"
grep -Fx 'Package: luci-app-alpha' "$tmp/result"
sh "$scripts/opkg-info.sh" 'luci-app-.*' 1 >"$tmp/result"
grep -Fx 'Package: luci-app-alpha' "$tmp/result"
if grep -F 'Package: luci-app-beta' "$tmp/result"; then exit 1; fi
sh "$scripts/opkg-search-file.sh" 'curl.*' 1 >"$tmp/result"
[ "$(cat "$tmp/result")" = 'curl: /usr/bin/curl' ]
for helper in opkg-find.sh opkg-info.sh opkg-search-file.sh; do
  if sh "$scripts/$helper" luci invalid >"$tmp/result" 2>&1; then
    echo "failed: $helper ignored an invalid limit" >&2
    exit 1
  fi
done
if grep -E 'opkg (update|install|upgrade|remove)' "$TEST_CALLS"; then
  echo 'failed: legacy query mutated the system' >&2
  exit 1
fi
echo 'ok: legacy opkg queries preserve regexp/limit without implicit refresh'
