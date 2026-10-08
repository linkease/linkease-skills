#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
smoke="$pack/skills/istoreos-download-acceleration/scripts/smoke.sh"
if sh "$smoke" pip 3.13.7 "$tmp/unapproved" >"$tmp/out" 2>&1; then exit 1; fi
[ ! -e "$tmp/unapproved" ]
grep -F authorization "$tmp/out"
if KAIPLUS_CONFIRMED=1 sh "$smoke" pip latest "$tmp/bad-version" >"$tmp/out" 2>&1; then exit 1; fi
[ ! -e "$tmp/bad-version" ]
grep -F 'complete installed version' "$tmp/out"
mkdir "$tmp/existing"
echo preserve >"$tmp/existing/sentinel"
if KAIPLUS_CONFIRMED=1 sh "$smoke" npm 24.21.0 "$tmp/existing" >"$tmp/out" 2>&1; then exit 1; fi
grep -F 'new directory' "$tmp/out"
grep -Fx preserve "$tmp/existing/sentinel"
sh -n "$smoke"
mkdir -p "$tmp/bin" "$tmp/home"
mkdir -p "$tmp/sdk/bin"
export TEST_RUNTIME="$tmp/home"
export TEST_SDK="$tmp/sdk"
cat >"$tmp/bin/uci" <<'EOF'
#!/bin/sh
echo "$TEST_RUNTIME"
EOF
cat >"$tmp/bin/mise" <<'EOF'
#!/bin/sh
if [ "$1" = where ]; then echo "$TEST_SDK"; exit 0; fi
[ "$1" = exec ] && [ "$3" = -- ] || exit 2
shift 3
export PATH="$TEST_SDK/bin:$PATH"
exec "$@"
EOF
cat >"$tmp/bin/go" <<'EOF'
#!/bin/sh
case "$*" in
'env GOSUMDB') echo sum.golang.org ;;
'env GOINSECURE') echo ;;
'version') echo 'go version go1.27.1 linux/amd64' ;;
esac
EOF
cat >"$tmp/bin/ks-cli" <<'EOF'
#!/bin/sh
case "$*" in
'mise exec go@1.27.1 -- go env GOROOT') echo "$TEST_SDK" ;;
'mise exec go@1.27.1 -- go version') echo 'go version go1.27.1 linux/amd64' ;;
'--explain --json '*|doctor*) echo '{}' ;;
'go mod download -x'*)
  echo 'github.com/google/uuid v1.6.0/go.mod h1:fixture' >go.sum
  # With a pruned graph, no-argument download need not write the package sum.
  for arg in "$@"; do
    if [ "$arg" = github.com/google/uuid@v1.6.0 ]; then
      echo 'github.com/google/uuid v1.6.0 h1:fixture-package' >>go.sum
    fi
  done ;;
'go mod verify') echo 'all modules verified' ;;
'go run .')
  grep -F '"github.com/google/uuid"' main.go >/dev/null || exit 2
  grep -F 'github.com/google/uuid v1.6.0 h1:' go.sum >/dev/null || { echo 'missing go.sum entry' >&2; exit 1; }
  echo '123e4567-e89b-12d3-a456-426614174000' ;;
*) echo "unexpected fixture command: $*" >&2; exit 2 ;;
esac
EOF
chmod +x "$tmp/bin/"*
cp "$tmp/bin/go" "$tmp/sdk/bin/go"
PATH="$TEST_RUNTIME/.local/share/mise/shims:$tmp/bin:$PATH" HOME="$TEST_RUNTIME" ISTORE_RUNTIME_ENTERED=1 KAIPLUS_CONFIRMED=1 sh "$smoke" go 1.27.1 "$tmp/go-project" >"$tmp/out" 2>&1
# Download + verify is insufficient unless the actual importing program runs.
grep -F '123e4567-e89b-12d3-a456-426614174000' "$tmp/out"
grep -F 'client_validation=passed' "$tmp/out"
echo 'ok: smoke examples are isolated and Go has a package checksum before running'
