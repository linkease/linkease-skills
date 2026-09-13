#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"
repo_root="$(CDPATH= cd -- "$root/.." && pwd -P)"

need_file() {
  [ -f "$root/$1" ] || {
    echo "failed: missing $1" >&2
    exit 1
  }
}

need_file "manifest.json"
need_file "home-prompts.json"
need_file "agents/remote-istoreos.md"
need_file "TASK_ROUTING.md"
need_file "istoreos-ssh-ops/SKILL.md"
need_file "quickstart-router-api/SKILL.md"
[ -f "$repo_root/istoreos/skills/istoreos-docker-acceleration-istoreenhance/SKILL.md" ] || {
  echo "failed: missing canonical iStoreOS system pack" >&2
  exit 1
}

for path in "$root"/istoreos-*; do
  [ -f "$path/SKILL.md" ] || continue
  [ "$(basename "$path")" = "istoreos-ssh-ops" ] || {
    echo "failed: duplicated system skill remains in remote preset: $path" >&2
    exit 1
  }
done

for script in "$root"/*/scripts/*.sh; do
  [ -f "$script" ] || continue
  sh -n "$script"
done

tmp="$(mktemp -d "${TMPDIR:-/tmp}/linkease-remote-smoke.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
sh "$root/install.sh" --target "$tmp" --copy >/dev/null
[ "$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" -eq 21 ] || {
  echo "failed: remote preset did not install 19 system + 2 transport skills" >&2
  exit 1
}
cmp "$repo_root/istoreos/skills/istoreos-package-manager/SKILL.md" \
  "$tmp/istoreos-package-manager/SKILL.md"

echo "ok: remote-control-istoreos profile smoke passed"
