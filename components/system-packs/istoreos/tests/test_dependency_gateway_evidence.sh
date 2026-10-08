#!/bin/sh
set -eu
pack="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
checker="$pack/skills/istoreos-download-acceleration/scripts/evidence.sh"
cat >"$tmp/client" <<'EOF'
npm http fetch GET 200 https://dl-npm.linkease.net:15443/is-number 41ms (cache miss)
npm http fetch GET 200 https://dl-npm.linkease.net:15443/is-number/-/is-number-7.0.0.tgz 41ms (cache miss)
EOF
cat >"$tmp/gateway" <<'EOF'
download gateway GET mirror=npm /is-number -> https://registry.npmjs.org/is-number mode=auto
download gateway done mirror=npm url=https://registry.npmjs.org/is-number strategy=direct selected=npmjs bytes=100
download gateway GET mirror=npm /is-number/-/is-number-7.0.0.tgz -> https://registry.npmjs.org/is-number/-/is-number-7.0.0.tgz mode=auto
download gateway done mirror=npm url=https://registry.npmjs.org/is-number/-/is-number-7.0.0.tgz strategy=direct selected=origin bytes=100
EOF
sh "$checker" npm "$tmp/client" "$tmp/gateway" 15443 >"$tmp/out"
grep -Fx 'result=gateway-confirmed' "$tmp/out"
# Actual configured port, unrelated/stale artifact, cache and failures cannot pass.
if sh "$checker" npm "$tmp/client" "$tmp/gateway" 5443 >"$tmp/out"; then exit 1; fi
grep -Fx 'result=insufficient-evidence' "$tmp/out"
sed 's/is-number-7.0.0.tgz/unrelated-1.0.0.tgz/g' "$tmp/gateway" >"$tmp/other"
if sh "$checker" npm "$tmp/client" "$tmp/other" 15443 >"$tmp/out"; then exit 1; fi
sed 's/cache miss/cache hit/g' "$tmp/client" >"$tmp/cached"
if sh "$checker" npm "$tmp/cached" "$tmp/gateway" 15443 >"$tmp/out"; then exit 1; fi
echo 'npm http fetch GET 200 https://registry.npmjs.org/is-number/-/is-number-7.0.0.tgz 41ms' >>"$tmp/client"
if sh "$checker" npm "$tmp/client" "$tmp/gateway" 15443 >"$tmp/out"; then exit 1; fi
grep -Fx 'result=client-direct-observed' "$tmp/out"
cat >"$tmp/client" <<'EOF'
Fetching project page https://dl-pypi.linkease.net:15443/simple/idna/
https://dl-pypi.linkease.net:15443 "GET /simple/idna/ HTTP/1.1" 200 100
Downloading https://dl-pypi-files.linkease.net:15443/packages/aa/bb/idna-3.10-py3-none-any.whl
EOF
cat >"$tmp/gateway" <<'EOF'
download gateway pypi-index host=dl-pypi.linkease.net:15443 path=/simple/idna/ http_status=200 status=ok bytes=100
download gateway GET mirror=pypi-files /packages/aa/bb/idna-3.10-py3-none-any.whl -> https://files.pythonhosted.org/packages/aa/bb/idna-3.10-py3-none-any.whl mode=auto
download gateway done mirror=pypi-files url=https://files.pythonhosted.org/packages/aa/bb/idna-3.10-py3-none-any.whl strategy=direct selected=origin bytes=100
EOF
sh "$checker" pip "$tmp/client" "$tmp/gateway" 15443 >"$tmp/out"
grep -Fx 'result=gateway-confirmed' "$tmp/out"
sed 's/status=ok/status=failed/' "$tmp/gateway" >"$tmp/failed"
if sh "$checker" pip "$tmp/client" "$tmp/failed" 15443 >"$tmp/out"; then exit 1; fi
cat >"$tmp/client" <<'EOF'
# get https://dl-golang.linkease.net:15443/github.com/google/uuid/@v/v1.6.0.mod
# get https://dl-golang.linkease.net:15443/github.com/google/uuid/@v/v1.6.0.mod: 200 OK
# get https://dl-golang.linkease.net:15443/github.com/google/uuid/@v/v1.6.0.zip
# get https://dl-golang.linkease.net:15443/github.com/google/uuid/@v/v1.6.0.zip: 200 OK
EOF
cat >"$tmp/gateway" <<'EOF'
download gateway GET mirror=golang /github.com/google/uuid/@v/v1.6.0.mod -> https://proxy.golang.org/github.com/google/uuid/@v/v1.6.0.mod mode=auto
download gateway done mirror=golang url=https://proxy.golang.org/github.com/google/uuid/@v/v1.6.0.mod strategy=direct selected=google bytes=100
download gateway GET mirror=golang /github.com/google/uuid/@v/v1.6.0.zip -> https://proxy.golang.org/github.com/google/uuid/@v/v1.6.0.zip mode=auto
download gateway done mirror=golang url=https://proxy.golang.org/github.com/google/uuid/@v/v1.6.0.zip strategy=direct selected=google bytes=100
EOF
sh "$checker" go "$tmp/client" "$tmp/gateway" 15443 >"$tmp/out"
grep -Fx 'result=gateway-confirmed' "$tmp/out"
echo 'ok: cold-cache metadata/artifact evidence and direct fallback classification passed'
