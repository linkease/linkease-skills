#!/bin/sh
set -eu

runtime="${1:-}"
version="${2:-}"
mise_bin="${MISE_ISTORE_BIN:-mise-istore}"

[ "${KAIPLUS_CONFIRMED:-}" = "1" ] || {
  echo "blocked: explicit user confirmation is required" >&2
  exit 3
}

case "$runtime" in
  python|node|go) ;;
  nodejs) runtime=node ;;
  golang) runtime=go ;;
  *) echo "failed: supported runtimes are python, node and go" >&2; exit 2 ;;
esac

[ -n "$version" ] || { echo "failed: a version is required" >&2; exit 2; }
case "$version" in
  *[!A-Za-z0-9._-]*) echo "failed: invalid version" >&2; exit 2 ;;
esac

command -v "$mise_bin" >/dev/null 2>&1 || {
  echo "failed: mise-istore is not installed" >&2
  exit 4
}

"$mise_bin" use --global "$runtime@$version"
"$mise_bin" which "$runtime"
exec "$mise_bin" exec -- "$runtime" --version
