#!/bin/sh
set -eu
tool="${1:-}"
client="${2:-}"
gateway="${3:-}"
port="${4:-}"
case "$tool" in pip|npm|go) ;; *) echo 'usage: evidence.sh pip|npm|go CLIENT_LOG GATEWAY_LOG ACTUAL_TLS_PORT' >&2; exit 2 ;; esac
[ -f "$client" ] && [ -f "$gateway" ] || { echo 'failed: both current-run logs are required' >&2; exit 2; }
case "$port" in ''|*[!0-9]*) echo 'failed: actual numeric TLS port is required' >&2; exit 2 ;; esac
[ "$port" -gt 0 ] && [ "$port" -le 65535 ] || exit 2
here="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
exec awk -v tool="$tool" -v port="$port" -f "$here/../data/gateway-evidence.awk" "$client" "$gateway"
