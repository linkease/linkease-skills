#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/system/etc" "$tmp/runtime" "$tmp/venv/bin"
echo 'DISTRIB_ID=iStoreOS' >"$tmp/system/etc/openwrt_release"
export ISTORE_SYSTEM_ROOT="$tmp/system" TEST_RUNTIME="$tmp/runtime" TEST_CALLS="$tmp/calls"
cat >"$tmp/bin/uci" <<'EOF'
#!/bin/sh
echo "$TEST_RUNTIME"
EOF
cat >"$tmp/bin/mise-exec" <<'EOF'
#!/bin/sh
export HOME="$TEST_RUNTIME" PATH="$TEST_RUNTIME/.local/share/mise/shims:$PATH"
exec /bin/sh
EOF
cat >"$tmp/bin/mise" <<'EOF'
#!/bin/sh
[ "$1" = exec ] && [ "$3" = -- ] || exit 2
printf '%s\n' "selected=$2" >>"$TEST_CALLS"
shift 3
if [ "${TEST_MISSING_RUNTIME:-0}" = 1 ]; then
  if [ "${MISE_AUTO_INSTALL:-1}" != 0 ]; then echo automatic-runtime-install-attempt >>"$TEST_CALLS"; fi
  echo 'runtime is not installed' >&2
  exit 4
fi
exec "$@"
EOF
cat >"$tmp/bin/ks-cli" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$TEST_CALLS"
if [ "$1" = doctor ] && [ "${TEST_DOCTOR_FAILURE:-0}" != 0 ]; then exit "$TEST_DOCTOR_FAILURE"; fi
EOF
cat >"$tmp/bin/npm" <<'EOF'
#!/bin/sh
echo true
EOF
cat >"$tmp/bin/go" <<'EOF'
#!/bin/sh
case "$*" in
  'env GOSUMDB') echo "${TEST_SUMDB:-sum.golang.org}" ;;
  'env GOINSECURE') echo "${TEST_GO_INSECURE:-}" ;;
esac
EOF
cat >"$tmp/venv/bin/activate" <<'EOF'
export PATH="$VIRTUAL_ENV/bin:$PATH"
EOF
printf '%s\n' '#!/bin/sh' 'exit 0' >"$tmp/venv/bin/python"
printf '%s\n' '#!/bin/sh' 'exit 0' >"$tmp/venv/bin/pip"
chmod +x "$tmp/bin/"* "$tmp/venv/bin/python" "$tmp/venv/bin/pip"
export PATH="$tmp/bin:$PATH"
dispatch="$pack/skills/istoreos-download-acceleration/scripts/dispatch.sh"
if sh "$dispatch" npm 24.21.0 -- install >"$tmp/out" 2>&1; then exit 1; fi
[ ! -e "$TEST_CALLS" ]
KAIPLUS_CONFIRMED=1 sh "$dispatch" npm 24.21.0 -- install --save-exact is-number@7.0.0
grep -Fx 'selected=node@24.21.0' "$TEST_CALLS"
grep -Fx 'npm install --save-exact is-number@7.0.0' "$TEST_CALLS"
if KAIPLUS_CONFIRMED=1 sh "$dispatch" pip 3.13.7 -- install idna==3.10 >"$tmp/out" 2>&1; then exit 1; fi
grep -F venv-not-active "$tmp/out"
KAIPLUS_CONFIRMED=1 VIRTUAL_ENV="$tmp/venv" sh "$dispatch" pip 3.13.7 -- install --no-cache-dir idna==3.10
grep -Fx 'pip install --no-cache-dir idna==3.10' "$TEST_CALLS"
: >"$TEST_CALLS"
code=0
KAIPLUS_CONFIRMED=1 TEST_DOCTOR_FAILURE=7 sh "$dispatch" go 1.27.1 -- mod download -x >"$tmp/out" 2>&1 || code=$?
[ "$code" = 7 ]
! grep -Fx 'go mod download -x' "$TEST_CALLS"
if KAIPLUS_CONFIRMED=1 TEST_SUMDB=off sh "$dispatch" go 1.27.1 -- mod download >"$tmp/out" 2>&1; then exit 1; fi
grep -F integrity-disabled "$tmp/out"
if KAIPLUS_CONFIRMED=1 TEST_GO_INSECURE='*' sh "$dispatch" go 1.27.1 -- mod download >"$tmp/out" 2>&1; then exit 1; fi
grep -F integrity-disabled "$tmp/out"
code=0
: >"$TEST_CALLS"
KAIPLUS_CONFIRMED=1 TEST_MISSING_RUNTIME=1 sh "$dispatch" npm 24.21.0 -- install >"$tmp/out" 2>&1 || code=$?
[ "$code" = 4 ]
! grep -F automatic-runtime-install-attempt "$TEST_CALLS"
echo 'ok: dependency routing, venv, runtime selection and health gates passed'
