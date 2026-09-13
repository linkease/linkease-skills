#!/bin/sh
set -eu

profile="istoreos"
mode="copy"
force="0"
target_config=""
target_skills=""

usage() {
  cat >&2 <<'EOF'
Usage:
  sh install.sh [--profile NAME] --target-config DIR [--copy|--symlink] [--force]
  sh install.sh [--profile NAME] --target-skills DIR [--copy|--symlink] [--force]

Defaults:
  --profile istoreos --copy

If --target-config is omitted and KAIPLUS_HOME is set, installs to:
  $KAIPLUS_HOME/config
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      shift
      [ "$#" -gt 0 ] || { usage; exit 2; }
      profile="$1"
      ;;
    --target-config)
      shift
      [ "$#" -gt 0 ] || { usage; exit 2; }
      target_config="$1"
      ;;
    --target-skills)
      shift
      [ "$#" -gt 0 ] || { usage; exit 2; }
      target_skills="$1"
      ;;
    --copy)
      mode="copy"
      ;;
    --symlink)
      mode="symlink"
      ;;
    --force)
      force="1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
  shift
done

root="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
src="$root/$profile"
[ -d "$src" ] || { echo "failed: missing profile $profile at $src" >&2; exit 1; }

if [ -z "$target_config" ] && [ -z "$target_skills" ] && [ -n "${KAIPLUS_HOME:-}" ]; then
  target_config="$KAIPLUS_HOME/config"
fi

[ -n "$target_config" ] || [ -n "$target_skills" ] || { usage; exit 2; }

copy_or_link_dir() {
  from="$1"
  to="$2"
  [ -d "$from" ] || return 0
  mkdir -p "$(dirname "$to")"
  if [ -e "$to" ] || [ -L "$to" ]; then
    if [ "$force" != "1" ]; then
      echo "skip: $to exists (use --force to replace)" >&2
      return 0
    fi
    rm -rf "$to"
  fi
  case "$mode" in
    copy) cp -R "$from" "$to" ;;
    symlink) ln -s "$from" "$to" ;;
    *) echo "failed: invalid mode $mode" >&2; exit 2 ;;
  esac
  echo "installed: $from -> $to" >&2
}

copy_file() {
  from="$1"
  to="$2"
  [ -f "$from" ] || return 0
  mkdir -p "$(dirname "$to")"
  if [ -e "$to" ] || [ -L "$to" ]; then
    if [ "$force" != "1" ]; then
      echo "skip: $to exists (use --force to replace)" >&2
      return 0
    fi
    rm -f "$to"
  fi
  cp "$from" "$to"
  echo "installed: $from -> $to" >&2
}

install_skills() {
  dest="$1"
  mkdir -p "$dest"
  install_skills_from() {
    skills_root="$1"
    for skill in "$skills_root"/*; do
      [ -d "$skill" ] || continue
      [ -f "$skill/SKILL.md" ] || continue
      copy_or_link_dir "$skill" "$dest/$(basename "$skill")"
    done
  }

  if [ "$profile" = "remote-control-istoreos" ]; then
    install_skills_from "$root/istoreos/skills"
    install_skills_from "$root/components/transports/ssh/skills"
    install_skills_from "$root/components/transports/luci-http/skills"
  elif [ -d "$src/skills" ]; then
    install_skills_from "$src/skills"
  else
    install_skills_from "$src"
  fi
}

if [ -n "$target_config" ]; then
  mkdir -p "$target_config"
  copy_or_link_dir "$src/agents" "$target_config/agents"
  install_skills "$target_config/skills"
  copy_file "$src/home-prompts.json" "$target_config/home-prompts.json"
  copy_file "$src/manifest.json" "$target_config/kaiplus-profile.json"
else
  install_skills "$target_skills"
fi

echo "ok: installed profile=$profile"
