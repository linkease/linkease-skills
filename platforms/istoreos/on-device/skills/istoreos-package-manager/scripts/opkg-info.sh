#!/bin/sh
set -eu
here="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
# Compatibility alias. Use package.sh directly for new workflows.
exec sh "$here/package.sh" info "${1:?a package or search term is required}"
