#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"

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
need_file "istoreos-docker-acceleration-istoreenhance/SKILL.md"
need_file "istoreos-kspeeder-domainfold-fetch/SKILL.md"

for script in "$root"/*/scripts/*.sh; do
  [ -f "$script" ] || continue
  sh -n "$script"
done

echo "ok: remote-control-istoreos profile smoke passed"
