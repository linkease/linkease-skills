#!/bin/sh
set -eu

usage() {
  cat >&2 <<'EOF'
usage:
  dispatch.sh url [-o FILE|-O [FILE]] <URL>
  dispatch.sh docker-pull <IMAGE>

Environment:
  KAIPLUS_HOME or KAIPLUS_SKILLS_DIR locates the installed skills directory.
  CONFIRM_ISTOREENHANCE_APPLY=YES permits iStoreEnhance install/autoconf/UCI/service changes.
EOF
}

need() {
  echo "need-confirmation: $*" >&2
  exit 2
}

skills_root() {
  if [ -n "${KAIPLUS_SKILLS_DIR:-}" ] && [ -d "$KAIPLUS_SKILLS_DIR" ]; then
    printf '%s\n' "$KAIPLUS_SKILLS_DIR"
    return 0
  fi
  if [ -n "${KAIPLUS_HOME:-}" ] && [ -d "$KAIPLUS_HOME/config/skills" ]; then
    printf '%s\n' "$KAIPLUS_HOME/config/skills"
    return 0
  fi
  script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
  skill_dir="$(dirname "$script_dir")"
  dirname "$skill_dir"
}

mode="${1:-}"
[ -n "$mode" ] || { usage; exit 2; }
shift

root="$(skills_root)"

basename_from_url() {
  u="${1%%\?*}"
  u="${u%%#*}"
  b="${u##*/}"
  [ -n "$b" ] || b="download.bin"
  printf '%s\n' "$b"
}

dispatch_url_download() {
  out=""
  url=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -o)
        [ "$#" -ge 3 ] || { usage; exit 2; }
        out="$2"
        shift 2
        ;;
      -O)
        [ "$#" -ge 2 ] || { usage; exit 2; }
        if [ "$#" -eq 2 ]; then
          url="$2"
          out="$(basename_from_url "$url")"
          shift 2
        else
          out="$2"
          shift 2
        fi
        ;;
      *)
        [ -z "$url" ] || { usage; exit 2; }
        url="$1"
        shift
        ;;
    esac
  done
  [ -n "$url" ] || { usage; exit 2; }
  if command -v kspeeder >/dev/null 2>&1; then
    if [ -n "$out" ]; then
      exec kspeeder download --json --events ndjson -O "$out" "$url"
    fi
    exec kspeeder download "$url"
  fi
  ksget="$root/istoreos-kspeeder-domainfold-fetch/scripts/ksget.sh"
  [ -f "$ksget" ] || need "kspeeder binary and ksget wrapper are both unavailable; upgrade iStoreEnhance/KSpeeder first."
  if [ -n "$out" ]; then
    exec sh "$ksget" -o "$out" "$url"
  fi
  exec sh "$ksget" "$url"
}

case "$mode" in
  url)
    dispatch_url_download "$@"
    ;;
  docker-pull)
    image="${1:-}"
    [ -n "$image" ] || { usage; exit 2; }
    space="$root/istoreos-docker-basics/scripts/check_space.sh"
    ready="$root/istoreos-docker-acceleration-istoreenhance/scripts/ensure_ready.sh"
    [ -f "$ready" ] || need "KSpeeder readiness script not found at $ready."
    if [ -f "$space" ]; then
      sh "$space"
    fi
    sh "$ready"
    echo "action: docker pull $image" >&2
    exec docker pull "$image"
    ;;
  *)
    usage
    exit 2
    ;;
esac
