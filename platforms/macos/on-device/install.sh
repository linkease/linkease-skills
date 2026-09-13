#!/bin/sh
set -eu

target=""
mode="copy"
force="0"

usage() {
  echo "usage: install.sh --target DIR [--copy|--symlink] [--force]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) shift; [ "$#" -gt 0 ] || usage; target="$1" ;;
    --copy) mode="copy" ;;
    --symlink) mode="symlink" ;;
    --force) force="1" ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
  shift
done
[ -n "$target" ] || usage

root="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
mkdir -p "$target"
for source in "$root"/skills/*; do
  [ -f "$source/SKILL.md" ] || continue
  destination="$target/$(basename "$source")"
  if [ -e "$destination" ] || [ -L "$destination" ]; then
    [ "$force" = "1" ] || {
      echo "failed: $destination exists; use --force to replace" >&2
      exit 1
    }
    rm -rf "$destination"
  fi
  case "$mode" in
    copy) cp -R "$source" "$destination" ;;
    symlink) ln -s "$source" "$destination" ;;
  esac
done
echo "ok: installed preset into $target"
