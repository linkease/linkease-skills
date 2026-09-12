#!/bin/sh
set -eu

max_bytes="${ISTORE_DIAG_LOG_MAX_BYTES:-8192}"
case "$max_bytes" in ''|*[!0-9]*) echo "invalid ISTORE_DIAG_LOG_MAX_BYTES" >&2; exit 2 ;; esac

# Logs are untrusted input. Normalize terminal output, redact common credentials,
# collapse adjacent duplicate rows, and cap what can reach the model context.
LC_ALL=C tr '\r' '\n' |
  sed \
    -e 's/\[[0-9;?]*[ -\/]*[@-~]//g' \
    -E \
    -e 's#([Aa]uthorization:[[:space:]]*(Bearer|Basic))[[:space:]]+[^[:space:]]+#\1 [REDACTED]#g' \
    -e 's#((api[_-]?key|access[_-]?token|refresh[_-]?token|token|password|passwd|secret)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+#\1[REDACTED]#g' \
    -e 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1[REDACTED]@#g' |
  awk 'BEGIN { previous = "" } { if ($0 != previous || $0 == "") print; previous = $0 }' |
  head -c "$max_bytes"
