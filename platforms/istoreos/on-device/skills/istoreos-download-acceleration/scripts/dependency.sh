#!/bin/sh
set -eu
[ "${KAIPLUS_CONFIRMED:-}" = 1 ] || { echo 'blocked: dependency and possible service-start effects require authorization' >&2; exit 3; }
selected=0
if [ "${1:-}" = --selected ]; then selected=1; shift; fi
tool="${1:-}"
version="${2:-}"
[ "$#" -ge 4 ] && [ "$3" = -- ] || { echo 'usage: dependency.sh pip|npm|go RESOLVED_VERSION -- TOOL_ARGS...' >&2; exit 2; }
shift 3
case "$tool" in pip) runtime=python ;; npm) runtime=node ;; go) runtime=go ;; *) echo 'failed: unsupported dependency tool' >&2; exit 2 ;; esac
printf '%s\n' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' || { echo 'failed: a complete installed runtime version is required' >&2; exit 2; }
here="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
runtime_scripts="$here/../../istoreos-mise-runtime/scripts"
if [ "${ISTORE_RUNTIME_ENTERED:-}" != 1 ]; then
  exec sh "$runtime_scripts/exec.sh" "$here/dependency.sh" "$tool" "$version" -- "$@"
fi
[ "$HOME" = "$(uci -q get mise.main.runtime_dir)" ] || { echo 'failed: incorrect integration HOME' >&2; exit 4; }
export MISE_NOT_FOUND_AUTO_INSTALL=0
if [ "$tool" != pip ] && [ "$selected" = 0 ]; then
  exec mise exec "$runtime@$version" -- sh "$here/dependency.sh" --selected "$tool" "$version" -- "$@"
fi
case "$tool" in
  pip)
    case "${VIRTUAL_ENV:-}" in /*) ;; *) echo 'failed: venv-not-active: create and activate a project venv in this execution environment' >&2; exit 4 ;; esac
    [ -f "$VIRTUAL_ENV/bin/activate" ] || { echo 'failed: venv activation file is missing' >&2; exit 4; }
    . "$VIRTUAL_ENV/bin/activate"
    [ "$(command -v pip)" = "$VIRTUAL_ENV/bin/pip" ] || { echo 'failed: pip-launcher is outside the venv' >&2; exit 4; }
    python -c 'import os, pathlib, sys; assert sys.prefix != sys.base_prefix; assert pathlib.Path(sys.prefix).resolve() == pathlib.Path(os.environ["VIRTUAL_ENV"]).resolve(); assert sys.version.split()[0] == sys.argv[1], sys.version' "$version"
    [ -z "${PIP_TRUSTED_HOST:-}" ] || { echo 'failed: integrity-disabled: inspect trusted-host configuration; preserve TLS' >&2; exit 4; }
    ;;
  npm)
    [ "${NODE_TLS_REJECT_UNAUTHORIZED:-1}" != 0 ] && [ "$(npm config get strict-ssl)" = true ] || { echo 'failed: integrity-disabled: npm TLS verification is disabled' >&2; exit 4; }
    ;;
  go)
    sumdb="$(go env GOSUMDB)"
    [ -n "$sumdb" ] && [ "$sumdb" != off ] && [ -z "$(go env GOINSECURE)" ] || { echo 'failed: integrity-disabled: inspect Go sumdb/insecure settings' >&2; exit 4; }
    ;;
esac
ks-cli doctor "$tool" --json
exec ks-cli "$tool" "$@"
