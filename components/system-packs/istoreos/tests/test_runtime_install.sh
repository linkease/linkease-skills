#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/system/etc" "$tmp/system/lib" "$tmp/runtime home" "$tmp/install"
echo 'DISTRIB_ID=iStoreOS' >"$tmp/system/etc/openwrt_release"
: >"$tmp/system/lib/ld-musl-x86_64.so.1"
export ISTORE_SYSTEM_ROOT="$tmp/system" TEST_RUNTIME="$tmp/runtime home" TEST_INSTALL="$tmp/install" TEST_CALLS="$tmp/calls" TEST_ARCH=x86_64
cat >"$tmp/bin/uci" <<'EOF'
#!/bin/sh
echo "$TEST_RUNTIME"
EOF
cat >"$tmp/bin/uname" <<'EOF'
#!/bin/sh
echo "$TEST_ARCH"
EOF
cat >"$tmp/bin/mise-exec" <<'EOF'
#!/bin/sh
export HOME="$TEST_RUNTIME" PATH="$TEST_RUNTIME/.local/share/mise/shims:$PATH"
export MISE_NODE_MIRROR_URL=https://legacy.invalid MISE_NODE_VERIFY=0
exec /bin/sh
EOF
cat >"$tmp/bin/mise" <<'EOF'
#!/bin/sh
case "$1" in
where) echo "$TEST_INSTALL" ;;
--version) echo 'mise 2026.8.14' ;;
esac
EOF
cat >"$tmp/bin/ks-cli" <<'EOF'
#!/bin/sh
set -eu
[ "$HOME" = "$TEST_RUNTIME" ] || exit 90
printf '%s\n' "$*|compile=${MISE_PYTHON_COMPILE:-unset}|os=${MISE_PYTHON_PRECOMPILED_OS:-unset}|arch=${MISE_PYTHON_PRECOMPILED_ARCH:-unset}|verify=${MISE_NODE_VERIFY:-unset}|mirror=${MISE_NODE_MIRROR_URL:-unset}" >>"$TEST_CALLS"
case "$*" in
'mise latest node@lts') echo '24.21.0' ;;
'mise latest go@1.27') echo '1.27.1' ;;
'mise settings get node.mirror_url') exit 1 ;;
'mise settings get node.verify') echo true ;;
'mise settings get node.gpg_verify') echo true ;;
'mise settings get skip_checksum') echo "${TEST_SKIP_CHECKSUM:-false}" ;;
'mise settings get not_found_auto_install') echo true ;;
'mise exec go@1.27.1 -- go env GOROOT') echo "$TEST_INSTALL" ;;
'mise exec go@1.27.1 -- go version') echo "go version go${TEST_GO_VERSION:-1.27.1} linux/amd64" ;;
'mise install '* )
 if [ "${TEST_INSTALL_FAILURE:-}" = 1 ]; then echo 'no precompiled python found for this platform' >&2; exit 9; fi ;;
'mise exec python@3.13.7 -- python -c '*)
 if [ "${TEST_WRONG_SOURCE:-}" = 1 ]; then shift 5; exec python3 "$@"; fi ;;
esac
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
install="$pack/skills/istoreos-mise-runtime/scripts/install.sh"
if sh "$install" python 3.13.7 >"$tmp/out" 2>&1; then exit 1; fi
[ ! -e "$TEST_CALLS" ]
KAIPLUS_CONFIRMED=1 sh "$install" python 3.13.7
grep -F 'mise install python@3.13.7|compile=0|os=unknown-linux-musl|arch=x86_64' "$TEST_CALLS"
grep -F 'mise exec python@3.13.7 -- python' "$TEST_CALLS"
! grep -F 'use --global' "$TEST_CALLS"
: >"$TEST_CALLS"
if KAIPLUS_CONFIRMED=1 sh "$install" python latest >"$tmp/out" 2>&1; then exit 1; fi
grep -F explicit-python-version "$tmp/out"
[ ! -s "$TEST_CALLS" ]
KAIPLUS_CONFIRMED=1 sh "$install" nodejs lts
grep -F 'mise install node@24.21.0' "$TEST_CALLS"
! grep 'mise install node@.*verify=0' "$TEST_CALLS"
grep -F 'mise install node@24.21.0|compile=unset|os=unset|arch=unset|verify=1|mirror=unset' "$TEST_CALLS"
KAIPLUS_CONFIRMED=1 sh "$install" go 1.27 global
grep -F 'mise use --global go@1.27.1' "$TEST_CALLS"
grep -F 'mise exec go@1.27.1 -- go env GOROOT' "$TEST_CALLS"
code=0
KAIPLUS_CONFIRMED=1 TEST_INSTALL_FAILURE=1 sh "$install" python 3.13.7 >"$tmp/out" 2>&1 || code=$?
[ "$code" = 9 ]
grep -F precompiled-unavailable "$tmp/out"
: >"$TEST_CALLS"
if KAIPLUS_CONFIRMED=1 TEST_SKIP_CHECKSUM=true sh "$install" node 24.21.0 >"$tmp/out" 2>&1; then exit 1; fi
grep -F integrity-disabled "$tmp/out"
! grep -F 'mise install' "$TEST_CALLS"
if TEST_WRONG_SOURCE=1 sh "$pack/skills/istoreos-mise-runtime/scripts/verify.sh" python 3.13.7 >"$tmp/out" 2>&1; then echo 'system interpreter accepted as mise installation' >&2; exit 1; fi
grep -F AssertionError "$tmp/out"
if KAIPLUS_CONFIRMED=1 TEST_GO_VERSION=1.26.0 sh "$install" go 1.27.1 >"$tmp/out" 2>&1; then exit 1; fi
grep -F version-mismatch "$tmp/out"
KAIPLUS_CONFIRMED=1 TEST_ARCH=aarch64 sh "$install" python 3.13.7 >"$tmp/out"
grep -F 'os=unknown-linux-musl|arch=aarch64' "$TEST_CALLS"
: >"$TEST_CALLS"
if KAIPLUS_CONFIRMED=1 TEST_ARCH=mips sh "$install" python 3.13.7 >"$tmp/out" 2>&1; then exit 1; fi
grep -F unsupported-architecture "$tmp/out"
! grep -F 'mise install' "$TEST_CALLS"
echo 'ok: runtime version, platform, integrity and activation contracts passed'
