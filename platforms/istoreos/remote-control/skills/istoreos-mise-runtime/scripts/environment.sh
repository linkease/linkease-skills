#!/bin/sh
# Shared boundary check; this file does not enter or alter the integration.
runtime_environment_check() {
  integrated_home="$(uci -q get mise.main.runtime_dir)" || {
    echo 'failed: runtime directory is not configured' >&2; return 4;
  }
  case "$integrated_home" in /*) ;; *) echo 'failed: configured runtime directory must be absolute' >&2; return 4 ;; esac
  [ "${HOME:-}" = "$integrated_home" ] && [ -d "$integrated_home" ] && [ -w "$integrated_home" ] || {
    echo 'failed: incorrect integration HOME or unavailable runtime directory' >&2; return 4;
  }
  # Explicit SDK selection and venv activation may legitimately precede shims.
  case ":${PATH:-}:" in *":$HOME/.local/share/mise/shims:"*) ;; *)
    echo 'failed: missing integrated shims; inspect mise-exec' >&2; return 4 ;;
  esac
}
