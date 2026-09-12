# Advanced runtime routes

Read only the section matching the active task.

## Node.js and npm

For Node.js managed by mise:

```sh
MISE_NODE_MIRROR_URL=https://dl-node-unofficial.linkease.net:5443/ \
MISE_NODE_VERIFY=0 mise-istore use --global node@lts
```

For npm packages:

```sh
npm install -g <pkg> --registry=https://dl-npm.linkease.net:5443
```

Verify the route before install with a bounded request to
`https://dl-node-unofficial.linkease.net:5443/index.json`.

## Go SDK and modules

For a Go SDK managed by mise:

```sh
MISE_GO_DOWNLOAD_MIRROR=https://dl-go-sdk.linkease.net:5443 \
mise-istore install go@<version>
```

For modules, retain checksum verification:

```sh
GOPROXY=https://dl-golang.linkease.net:5443,direct go mod download
```

Do not set `GOSUMDB=off` unless the user explicitly accepts that integrity tradeoff.

## Python and pip

Use the iStoreOS runtime environment before mise:

```sh
. /lib/functions/mise.sh
istore_runtime_env
mise-istore install python@<version>
```

For pip, use one index so metadata and artifact rewrites stay coherent:

```sh
PIP_INDEX_URL=https://dl-pypi.linkease.net:5443/simple/ \
python -m pip install <package>
```

Do not add a second index by default.

## Homebrew

Free mode accelerates metadata:

```sh
eval "$(iStoreEnhance brew-env --mode free)"
brew install <formula>
```

Plus mode may additionally route GHCR-backed bottles:

```sh
eval "$(iStoreEnhance brew-env --mode plus)"
brew install <formula>
```

Do not replace the GHCR bottle path with legacy `HOMEBREW_BOTTLE_DOMAIN`.

## Source-specific rule

These routes are product defaults, not universal Internet mirrors. Check current
device readiness and use direct download as the fallback when a route is absent
or unhealthy.
