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

case "$mode" in
  url)
    ksget="$root/istoreos-kspeeder-domainfold-fetch/scripts/ksget.sh"
    [ -f "$ksget" ] || need "ksget not found at $ksget; install the istoreos-kspeeder-domainfold-fetch skill first."
    exec sh "$ksget" "$@"
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
