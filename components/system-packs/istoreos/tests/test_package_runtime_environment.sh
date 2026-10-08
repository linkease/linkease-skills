#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/system/etc" "$tmp/system/usr/lib/opkg" "$tmp/bin" "$tmp/runtime home"
printf '%s\n' 'DISTRIB_ID="iStoreOS"' 'DISTRIB_RELEASE="24.10.1"' >"$tmp/system/etc/openwrt_release"
: >"$tmp/system/usr/lib/opkg/status"
export ISTORE_SYSTEM_ROOT="$tmp/system" TEST_CALLS="$tmp/calls" TEST_RUNTIME="$tmp/runtime home"
cat >"$tmp/bin/opkg" <<'EOF'
#!/bin/sh
printf '%s\n' "opkg $*" >>"$TEST_CALLS"
case "$1" in
list) printf '%s\n' "${TEST_PACKAGE_NAME:-mise} - 2026.8.14 - integrated runtime manager" ;;
info) printf '%s\n' 'Package: mise' 'Version: 2026.8.14' ;;
status) if [ "${TEST_PACKAGE_MISSING:-0}" = 0 ]; then printf '%s\n' 'Package: mise' 'Status: install ok installed'; fi ;;
files) printf '%s\n' '/usr/sbin/mise-exec' '/lib/functions/mise.sh' ;;
esac
EOF
cat >"$tmp/bin/is-opkg" <<'EOF'
#!/bin/sh
printf '%s\n' "is-opkg $*" >>"$TEST_CALLS"
EOF
cat >"$tmp/bin/apk" <<'EOF'
#!/bin/sh
printf '%s\n' "apk $*" >>"$TEST_CALLS"
case "$1" in
search) echo 'mise-2026.8.14 integrated runtime manager' ;;
info) echo 'mise-2026.8.14 description:' ;;
esac
EOF
cat >"$tmp/bin/uci" <<'EOF'
#!/bin/sh
printf '%s\n' "$TEST_RUNTIME"
EOF
cat >"$tmp/bin/mise" <<'EOF'
#!/bin/sh
echo 'mise 2026.8.14'
EOF
cat >"$tmp/bin/mise-exec" <<'EOF'
#!/bin/sh
# Match the system shell-only contract, deliberately ignore argv.
export HOME="$TEST_RUNTIME"
export PATH="$HOME/.local/share/mise/shims:$PATH"
export MISE_NODE_MIRROR_URL=https://legacy.invalid MISE_NODE_VERIFY=0
exec /bin/sh
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" XDG_DATA_HOME="$tmp/agent-data" XDG_CONFIG_HOME="$tmp/agent-config" XDG_CACHE_HOME="$tmp/agent-cache"
unset MISE_DATA_DIR MISE_CONFIG_DIR MISE_CACHE_DIR
pkg="$pack/skills/istoreos-package-manager/scripts/package.sh"
runner="$pack/skills/istoreos-mise-runtime/scripts/exec.sh"
sh "$pkg" detect >"$tmp/facts"
grep -Fx 'package_manager=opkg' "$tmp/facts"
grep -Fx 'package_installer=is-opkg' "$tmp/facts"
sh "$pkg" search mise >"$tmp/search"
grep -F 'mise - 2026.8.14' "$tmp/search"
if grep -F update "$TEST_CALLS"; then echo "failed: unexpected matching command/evidence" >&2; exit 1; fi
if sh "$pkg" install mise >/dev/null 2>&1; then echo 'unguarded package install' >&2; exit 1; fi
if grep -F install "$TEST_CALLS"; then echo "failed: unexpected matching command/evidence" >&2; exit 1; fi
KAIPLUS_CONFIRMED=1 sh "$pkg" install mise
grep -Fx 'is-opkg install mise' "$TEST_CALLS"
if TEST_PACKAGE_NAME=notmise sh "$pkg" available mise >"$tmp/out" 2>&1; then exit 1; fi
grep -F package-unavailable "$tmp/out"
if TEST_PACKAGE_MISSING=1 sh "$pkg" installed mise >"$tmp/out" 2>&1; then exit 1; fi
grep -F package-not-installed "$tmp/out"
# APK executable alone does not override the active opkg database.
rm "$tmp/system/usr/lib/opkg/status"
mkdir -p "$tmp/system/lib/apk/db"
: >"$tmp/system/lib/apk/db/installed"
sh "$pkg" detect >"$tmp/facts"
grep -Fx 'package_manager=apk' "$tmp/facts"
sh "$pkg" search mise >"$tmp/search"
KAIPLUS_CONFIRMED=1 sh "$pkg" install mise
grep -Fx 'apk add mise' "$TEST_CALLS"
if KAIPLUS_CONFIRMED=1 sh "$pkg" install absent-package >"$tmp/out" 2>&1; then exit 1; fi
grep -F package-unavailable "$tmp/out"
: >"$tmp/system/usr/lib/opkg/status"
if sh "$pkg" detect >"$tmp/out" 2>&1; then echo 'ambiguous databases accepted' >&2; exit 1; fi
grep -F ambiguous "$tmp/out"
rm "$tmp/system/usr/lib/opkg/status"
# Exact installed package and missing feed candidate must not install.
if KAIPLUS_CONFIRMED=1 sh "$pkg" install 'mise;false' >"$tmp/out" 2>&1; then exit 1; fi
cat >"$tmp/program.sh" <<'EOF'
set -eu
[ "$HOME" = "$TEST_RUNTIME" ]
[ "${MISE_DATA_DIR:-}" = "$HOME/.local/share/mise" ]
[ "${MISE_CACHE_DIR:-}" = "$HOME/.cache/mise" ]
[ "${MISE_CONFIG_DIR:-}" = "$HOME/.config/mise" ]
[ "$XDG_DATA_HOME" != "$HOME/.local/share" ]
case "$PATH" in "$HOME/.local/share/mise/shims:"*) ;; *) exit 8 ;; esac
# Runtime dir is HOME, not necessarily cwd. Workdir is an explicit argument.
[ "$PWD" = "$1" ]
[ "$2" = 'argument with spaces' ]
[ "$3" = 'literal '\''quote $(false) `false`' ]
printf '%s\n' "environment_ok=$HOME"
EOF
sh "$runner" "$tmp/program.sh" "$PWD" 'argument with spaces' 'literal '\''quote $(false) `false`' >"$tmp/run1"
sh "$runner" "$tmp/program.sh" "$PWD" 'argument with spaces' 'literal '\''quote $(false) `false`' >"$tmp/run2"
cmp "$tmp/run1" "$tmp/run2"
mkdir -p "$tmp/system/lib"
: >"$tmp/system/lib/ld-musl-x86_64.so.1"
# Minimal router images may omit printenv; diagnostics must still report facts.
cat >"$tmp/bin/printenv" <<'EOF'
#!/bin/sh
exit 127
EOF
chmod +x "$tmp/bin/printenv"
sh "$pack/skills/istoreos-mise-runtime/scripts/check.sh" python >"$tmp/check"
grep -Fx "XDG_DATA_HOME=$XDG_DATA_HOME" "$tmp/check"
grep -Fx 'libc=musl' "$tmp/check"
grep -Fx 'environment=enter-mise-exec' "$tmp/check"
if grep -F update "$TEST_CALLS"; then echo "failed: unexpected matching command/evidence" >&2; exit 1; fi
printf '%s\n' 'exit 17' >"$tmp/fail.sh"
code=0
sh "$runner" "$tmp/fail.sh" || code=$?
[ "$code" = 17 ]
printf '%s\n' 'ID=ubuntu' >"$tmp/system/etc/os-release"
rm "$tmp/system/etc/openwrt_release"
: >"$TEST_CALLS"
if sh "$pkg" search mise >"$tmp/out" 2>&1; then exit 1; fi
grep -F 'unsupported-system' "$tmp/out"
[ ! -s "$TEST_CALLS" ]
if sh "$runner" "$tmp/program.sh" "$PWD" x >"$tmp/out" 2>&1; then exit 1; fi
grep -F 'unsupported-system' "$tmp/out"
echo 'ok: package detection and persistent runtime execution contracts passed'
