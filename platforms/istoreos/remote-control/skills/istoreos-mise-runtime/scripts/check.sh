#!/bin/sh
set -eu

runtime="${1:-all}"
mise_bin="${MISE_ISTORE_BIN:-mise-istore}"

case "$runtime" in
  python|node|go|all) ;;
  *) printf 'usage: %s <python|node|go|all>\n' "$0" >&2; exit 2 ;;
esac

printf '[system]\n'
uname -m 2>/dev/null || true
df -h 2>/dev/null || true

runtime_dir=""
if command -v uci >/dev/null 2>&1; then
  runtime_dir="$(uci -q get mise.main.runtime_dir 2>/dev/null || true)"
fi
printf 'runtime_dir=%s\n' "${runtime_dir:-not-configured}"
[ -z "$runtime_dir" ] || df -h "$runtime_dir" 2>/dev/null || true

if ! command -v "$mise_bin" >/dev/null 2>&1; then
  printf 'mise-istore=unavailable\n'
  exit 0
fi

printf 'mise-istore=%s\n' "$(command -v "$mise_bin")"
"$mise_bin" --version 2>&1 || true
if [ "$runtime" = "all" ]; then
  "$mise_bin" ls python node go 2>&1 || true
else
  "$mise_bin" ls "$runtime" 2>&1 || true
fi
