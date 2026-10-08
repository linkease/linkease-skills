#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
mkdir -p "$tmp/bin" "$tmp/system/etc" "$tmp/runtime home" "$tmp/sdk"
echo 'DISTRIB_ID=iStoreOS' >"$tmp/system/etc/openwrt_release"
export ISTORE_SYSTEM_ROOT="$tmp/system" TEST_RUNTIME="$tmp/runtime home" TEST_SDK="$tmp/sdk" TEST_CALLS="$tmp/calls"
cat >"$tmp/bin/uci" <<'EOF'
#!/bin/sh
echo "$TEST_RUNTIME"
EOF
cat >"$tmp/bin/mise-exec" <<'EOF'
#!/bin/sh
echo enter >>"$TEST_CALLS"
export HOME="$TEST_RUNTIME"
if [ "${TEST_BAD_HOME:-0}" = 1 ]; then HOME=/wrong-home; fi
if [ "${TEST_BAD_SHIMS:-0}" != 1 ]; then export PATH="$HOME/.local/share/mise/shims:$PATH"; fi
exec /bin/sh
EOF
cat >"$tmp/bin/mise" <<'EOF'
#!/bin/sh
echo "mise $*" >>"$TEST_CALLS"
case "$1" in
where) [ "${TEST_MISSING_SDK:-0}" != 1 ] || exit 8; echo "$TEST_SDK" ;;
--version) echo 'mise 2026.8.14' ;;
exec) [ "$3" = -- ] || exit 2; shift 3; exec "$@" ;;
*) exit 2 ;;
esac
EOF
cat >"$tmp/bin/ks-cli" <<'EOF'
#!/bin/sh
echo "ks-cli $*" >>"$TEST_CALLS"
[ "$HOME" = "$TEST_RUNTIME" ] || exit 90
case "$*" in
'mise exec go@1.27.1 -- go env GOROOT') echo "$TEST_SDK" ;;
'mise exec go@1.27.1 -- go version') echo "go version go${TEST_GO_VERSION:-1.27.1} linux/amd64" ;;
'mise settings get go.skip_checksum') echo false ;;
'mise settings get gpg_verify') exit 1 ;;
'mise install go@1.27.1') exit "${TEST_INSTALL_EXIT:-0}" ;;
'doctor '*|'--explain --json '*) echo '{}' ;;
'go mod download -x '*)
  printf '%s\n' 'github.com/google/uuid v1.6.0 h1:fixture' >go.sum
  echo '# get https://dl-golang.linkease.net:5443/github.com/google/uuid/@v/v1.6.0.mod: 200 OK'
  echo '# get https://dl-golang.linkease.net:5443/github.com/google/uuid/@v/v1.6.0.zip: 200 OK'
  if [ -n "${TEST_GATEWAY_LOG:-}" ]; then
    printf '%s\n' 'download gateway done mirror=golang url=https://proxy.golang.org/github.com/google/uuid/@v/v1.6.0.mod bytes=42' 'download gateway done mirror=golang url=https://proxy.golang.org/github.com/google/uuid/@v/v1.6.0.zip bytes=123' >>"$TEST_GATEWAY_LOG"
  fi ;;
'go mod verify') echo 'all modules verified' ;;
'go run .') exit "${TEST_RUN_EXIT:-0}" ;;
*) echo "unexpected command: $*" >&2; exit 2 ;;
esac
EOF
cat >"$tmp/bin/go" <<'EOF'
#!/bin/sh
case "$*" in
'env GOSUMDB') echo sum.golang.org ;;
'env GOINSECURE') echo ;;
*) exit 2 ;;
esac
EOF
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" XDG_DATA_HOME="$tmp/agent-data" XDG_CACHE_HOME="$tmp/agent-cache" XDG_CONFIG_HOME="$tmp/agent-config"
unset ISTORE_RUNTIME_ENTERED MISE_DATA_DIR MISE_CACHE_DIR MISE_CONFIG_DIR
runtime="$pack/skills/istoreos-mise-runtime/scripts"
download="$pack/skills/istoreos-download-acceleration/scripts"
expect_code() {
  expected="$1"; shift
  code=0; "$@" >"$tmp/out" 2>"$tmp/err" || code=$?
  [ "$code" = "$expected" ] || { cat "$tmp/err" >&2; echo "expected=$expected actual=$code" >&2; exit 1; }
}
# System facts must not enter the integration or inspect another HOME's SDKs.
sh "$runtime/check.sh" go >"$tmp/facts"
if [ -f "$TEST_CALLS" ]; then ! grep -Fx enter "$TEST_CALLS"; fi
: >"$TEST_CALLS"
echo 'echo payload-ran >>"$TEST_CALLS"' >"$tmp/payload.sh"
expect_code 4 env TEST_BAD_HOME=1 sh "$runtime/exec.sh" "$tmp/payload.sh"
! grep -F payload-ran "$TEST_CALLS"
expect_code 4 env TEST_BAD_SHIMS=1 sh "$runtime/exec.sh" "$tmp/payload.sh"
! grep -F payload-ran "$TEST_CALLS"
: >"$TEST_CALLS"
expect_code 2 sh "$runtime/probe.sh" go latest
[ ! -s "$TEST_CALLS" ]
sh "$runtime/probe.sh" go 1.27.1 >"$tmp/probe1" 2>"$tmp/err"
sh "$runtime/probe.sh" go 1.27.1 >"$tmp/probe2" 2>>"$tmp/err"
cmp "$tmp/probe1" "$tmp/probe2"
python3 - "$tmp/probe1" "$TEST_RUNTIME" "$TEST_SDK" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
assert r['schemaVersion'] == 1 and r['status'] == 'passed' and r['exitCode'] == 0, r
assert r['operation'] == 'runtime-probe' and r['runtime_validation'] == 'passed', r
assert r['home'] == sys.argv[2] and r['sdk_path'] == sys.argv[3], r
assert r['mise_data_dir'] == sys.argv[2] + '/.local/share/mise', r
assert r['version'] == '1.27.1' and r['gateway_validation'] == 'not-applicable', r
PY
expect_code 4 env TEST_GO_VERSION=1.26.0 sh "$runtime/probe.sh" go 1.27.1
python3 - "$tmp/out" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['status']=='failed' and r['runtime_validation']=='failed', r
PY
expect_code 8 env TEST_MISSING_SDK=1 sh "$runtime/probe.sh" go 1.27.1
! grep -F 'mise install' "$TEST_CALLS"
MISE_DATA_DIR="$tmp/explicit data" sh "$runtime/probe.sh" go 1.27.1 >"$tmp/override" 2>"$tmp/err"
python3 - "$tmp/override" "$tmp/explicit data" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['mise_data_dir']==sys.argv[2], r
PY
[ "$XDG_DATA_HOME" = "$tmp/agent-data" ]
# Receipts remain valid JSON for literal path characters and multiline diagnostics.
sh -c '. "$1"; result_emit failed test 7 path "$2"' sh "$runtime/result.sh" 'space "quote" \backslash
tab	carriage控制' >"$tmp/escaped"
python3 - "$tmp/escaped" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['path']=='space "quote" \\backslash\ntab\tcarriage\r控制', r
PY
# Installer results are about the SDK, never dependency gateway success.
KAIPLUS_CONFIRMED=1 sh "$runtime/install.sh" go 1.27.1 >"$tmp/install"
tail -n 1 "$tmp/install" >"$tmp/result"
python3 - "$tmp/result" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['operation']=='runtime-install' and r['runtime_validation']=='passed' and r['gateway_validation']=='not-applicable', r
PY
expect_code 9 env KAIPLUS_CONFIRMED=1 TEST_INSTALL_EXIT=9 sh "$runtime/install.sh" go 1.27.1
tail -n 1 "$tmp/out" >"$tmp/result"
python3 - "$tmp/result" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['status']=='failed' and r['exitCode']==9 and r['runtime_validation']!='passed', r
PY
# Client success alone is partial. Old gateway entries cannot fill missing evidence.
KAIPLUS_CONFIRMED=1 sh "$download/smoke.sh" go 1.27.1 "$tmp/client-only" >"$tmp/out" 2>"$tmp/err"
python3 - "$tmp/client-only/result.json" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['status']=='partial' and r['client_validation']=='passed' and r['gateway_validation']=='pending', r
PY
expect_code 7 env KAIPLUS_CONFIRMED=1 TEST_RUN_EXIT=7 sh "$download/smoke.sh" go 1.27.1 "$tmp/client-failed"
python3 - "$tmp/client-failed/result.json" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['status']=='failed' and r['exitCode']==7 and r['client_validation']=='failed', r
PY
printf '%s\n' 'download gateway done mirror=golang url=https://proxy.golang.org/github.com/google/uuid/@v/v1.6.0.mod bytes=42' 'download gateway done mirror=golang url=https://proxy.golang.org/github.com/google/uuid/@v/v1.6.0.zip bytes=123' >"$tmp/gateway.log"
expect_code 4 env KAIPLUS_CONFIRMED=1 sh "$download/smoke.sh" go 1.27.1 "$tmp/stale" "$tmp/gateway.log" 5443
python3 - "$tmp/stale/result.json" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['client_validation']=='passed' and r['gateway_validation']=='insufficient-evidence' and r['status']=='failed', r
PY
KAIPLUS_CONFIRMED=1 TEST_GATEWAY_LOG="$tmp/gateway.log" sh "$download/smoke.sh" go 1.27.1 "$tmp/confirmed" "$tmp/gateway.log" 5443 >"$tmp/out" 2>"$tmp/err"
python3 - "$tmp/confirmed/result.json" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['status']=='passed' and r['environment_validation']=='passed' and r['runtime_validation']=='passed' and r['client_validation']=='passed' and r['gateway_validation']=='confirmed', r
PY
sh "$download/evidence.sh" --json go "$tmp/confirmed/client.log" "$tmp/confirmed/gateway.log" 5443 >"$tmp/evidence"
python3 - "$tmp/evidence" <<'PY'
import json, sys
r=json.load(open(sys.argv[1])); assert r['operation']=='gateway-evidence' and r['gateway_validation']=='confirmed', r
PY
expect_code 4 sh "$download/evidence.sh" --json go "$tmp/confirmed/client.log" "$tmp/confirmed/gateway.log" 5444
# Do not create a work directory or run commands on a non-iStore target.
rm "$tmp/system/etc/openwrt_release"
echo ID=ubuntu >"$tmp/system/etc/os-release"
expect_code 4 sh "$runtime/probe.sh" go 1.27.1
expect_code 4 env KAIPLUS_CONFIRMED=1 sh "$download/smoke.sh" go 1.27.1 "$tmp/ubuntu"
[ ! -e "$tmp/ubuntu" ]
echo 'ok: scoped runtime probes, operation receipts and current-window gateway acceptance passed'
