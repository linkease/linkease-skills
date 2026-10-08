#!/bin/sh
set -eu
here="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
exec sh "$here/package.sh" owner "${1:?an absolute file path is required}"
