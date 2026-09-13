#!/bin/sh
set -eu

target=""
mode="copy"
force="0"
action="install"
dry_run="0"
upgrade_only="0"

usage() {
  echo "usage: install.sh --target DIR [--copy|--symlink] [--force] [--upgrade|--uninstall] [--dry-run]" >&2
  exit 2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) shift; [ "$#" -gt 0 ] || usage; target="$1" ;;
    --copy) mode="copy" ;;
    --symlink) mode="symlink" ;;
    --force) force="1" ;;
    --upgrade) action="install"; upgrade_only="1" ;;
    --uninstall) action="uninstall" ;;
    --dry-run) dry_run="1" ;;
    -h|--help) usage ;;
    *) usage ;;
  esac
  shift
done
[ -n "$target" ] || usage
case "$target" in /|'') echo "failed: unsafe target directory" >&2; exit 2 ;; esac

root="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
preset="$root/preset.json"
command -v jq >/dev/null 2>&1 || { echo "failed: jq is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "failed: sha256sum is required" >&2; exit 2; }
[ -f "$preset" ] || { echo "failed: preset.json is missing" >&2; exit 1; }
preset_id="$(jq -er '.id' "$preset")"
case "$preset_id" in ''|*[!a-z0-9-]*) echo "failed: unsafe preset id" >&2; exit 1 ;; esac

hash_tree() {
  tree="$1"
  find -H "$tree" -type f | sed "s#^$tree/##" | LC_ALL=C sort |
  while IFS= read -r relative_file; do
    printf '%s  %s\n' "$(sha256sum "$tree/$relative_file" | awk '{print $1}')" "$relative_file"
  done | sha256sum | awk '{print "sha256:" $1}'
}

manifest="$target/.linkease-skills/$preset_id.json"
owned="0"
[ -f "$manifest" ] && owned="1"
[ "$upgrade_only" = "0" ] || [ "$owned" = "1" ] || {
  echo "failed: preset $preset_id is not installed; use install without --upgrade" >&2
  exit 1
}
[ "$action" != "uninstall" ] || [ "$owned" = "1" ] || {
  echo "failed: no ownership manifest for preset $preset_id" >&2
  exit 1
}

verify_owned_files() {
  [ "$owned" = "1" ] || return 0
  jq -e --arg id "$preset_id" '.schemaVersion == 1 and .presetId == $id' "$manifest" >/dev/null || {
    echo "failed: invalid ownership manifest $manifest" >&2
    exit 1
  }
  jq -r '.skills[] | [.name, .treeDigest] | @tsv' "$manifest" |
  while IFS="$(printf '\t')" read -r name expected; do
    case "$name" in ''|*/*|.|..) echo "failed: unsafe owned skill name" >&2; exit 1 ;; esac
    current="$target/$name"
    [ -e "$current" ] || [ -L "$current" ] || {
      echo "failed: installed skill $name is missing; refusing to change ownership state" >&2
      exit 1
    }
    actual="$(hash_tree "$current")"
    [ "$actual" = "$expected" ] || {
      echo "failed: user-modified skill $name; preserved without changes" >&2
      exit 1
    }
  done
}

verify_owned_files

if [ "$action" = "install" ]; then
  for source in "$root"/skills/*; do
    [ -f "$source/SKILL.md" ] || continue
    name="$(basename "$source")"
    destination="$target/$name"
    if [ -e "$destination" ] || [ -L "$destination" ]; then
      source_owned="0"
      if [ "$owned" = "1" ] && jq -e --arg name "$name" 'any(.skills[]; .name == $name)' "$manifest" >/dev/null; then
        source_owned="1"
      fi
      if [ "$source_owned" = "0" ] && [ "$force" = "0" ]; then
        echo "failed: $destination exists and is not owned by $preset_id; use --force to replace" >&2
        exit 1
      fi
    fi
  done
fi

if [ "$dry_run" = "1" ]; then
  echo "preset=$preset_id"
  echo "action=$action"
  echo "destination=$target"
  if [ "$action" = "install" ]; then
    for source in "$root"/skills/*; do
      [ -f "$source/SKILL.md" ] && echo "skill=$(basename "$source")"
    done
  else
    jq -r '.skills[].name | "skill=" + .' "$manifest"
  fi
  exit 0
fi

parent="$(dirname "$target")"
mkdir -p "$parent"
parent="$(CDPATH= cd -- "$parent" && pwd -P)"
target="$parent/$(basename "$target")"
transaction="$(mktemp -d "$parent/.linkease-skills-transaction.XXXXXX")"
next="$transaction/next"
previous="$transaction/previous"
swapped="0"
cleanup() {
  if [ "$swapped" = "1" ] && [ -d "$previous" ] && [ ! -e "$target" ]; then
    mv "$previous" "$target" || true
  fi
  rm -rf "$transaction"
}
trap cleanup EXIT HUP INT TERM

mkdir -p "$next"
if [ -d "$target" ]; then
  cp -R "$target"/. "$next"/
elif [ -e "$target" ] || [ -L "$target" ]; then
  echo "failed: target exists and is not a directory" >&2
  exit 1
fi

if [ "$owned" = "1" ]; then
  jq -r '.skills[].name' "$manifest" |
  while IFS= read -r name; do
    rm -rf "$next/$name"
  done
fi

if [ "$action" = "install" ]; then
  records="$transaction/skills.tsv"
  : >"$records"
  for source in "$root"/skills/*; do
    [ -f "$source/SKILL.md" ] || continue
    name="$(basename "$source")"
    rm -rf "$next/$name"
    case "$mode" in
      copy) cp -R "$source" "$next/$name" ;;
      symlink) ln -s "$source" "$next/$name" ;;
    esac
    printf '%s\t%s\n' "$name" "$(hash_tree "$source")" >>"$records"
  done
  mkdir -p "$next/.linkease-skills"
  skills_json="$(jq -Rn '[inputs | split("\t") | {name: .[0], treeDigest: .[1]}]' <"$records")"
  jq -n \
    --arg presetId "$preset_id" \
    --arg installMode "$mode" \
    --arg sourceDigest "$(jq -r '.sourceDigest // ""' "$preset")" \
    --arg treeDigest "$(jq -r '.treeDigest // ""' "$preset")" \
    --arg installedAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson skills "$skills_json" \
    '{schemaVersion:1,presetId:$presetId,installMode:$installMode,sourceDigest:$sourceDigest,treeDigest:$treeDigest,installedAt:$installedAt,skills:$skills}' \
    >"$next/.linkease-skills/$preset_id.json"
else
  rm -f "$next/.linkease-skills/$preset_id.json"
  rmdir "$next/.linkease-skills" 2>/dev/null || true
fi

if [ "${LINKEASE_INSTALL_TEST_FAIL_BEFORE_SWAP:-}" = "1" ]; then
  echo "failed: injected pre-swap failure" >&2
  exit 99
fi

if [ -d "$target" ]; then
  mv "$target" "$previous"
  swapped="1"
fi
if ! mv "$next" "$target"; then
  [ "$swapped" = "0" ] || mv "$previous" "$target"
  swapped="0"
  echo "failed: atomic install swap failed" >&2
  exit 1
fi
swapped="0"
rm -rf "$previous"
trap - EXIT HUP INT TERM
rm -rf "$transaction"

if [ "$action" = "install" ]; then
  echo "ok: installed preset=$preset_id destination=$target"
else
  echo "ok: uninstalled preset=$preset_id destination=$target"
fi
