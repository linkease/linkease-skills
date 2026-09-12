#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)"

need_file() {
  [ -f "$root/$1" ] || {
    echo "failed: missing $1" >&2
    exit 1
  }
}

need_skill() {
  need_file "skills/$1/SKILL.md"
}

need_file "manifest.json"
need_file "home-prompts.json"
need_file "agents/system.md"
need_file "agents/istoreos.md"
need_file "TASK_ROUTING.md"
need_file "tests/test_download_acceleration_dispatch.sh"
need_file "tests/test_system_helpers.sh"
need_file "tests/test_network_quality_helpers.sh"
need_file "tests/test_skill_architecture.sh"

need_skill "istoreos-system-task-router"
need_skill "istoreos-download-acceleration"
need_skill "istoreos-docker-acceleration-istoreenhance"
need_skill "istoreos-kspeeder-domainfold-fetch"
need_skill "istoreos-docker-basics"
need_skill "istoreos-package-manager"
need_skill "istoreos-storage-path"
need_skill "istoreos-service-manager"
need_skill "istoreos-logs-and-diagnostics"
need_skill "istoreos-backup-restore"
need_skill "istoreos-luci-recovery"
need_skill "istoreos-systools"
need_skill "istoreos-mise-runtime"
need_skill "istoreos-network-quality"

grep -F 'istoreos-network-quality' "$root/TASK_ROUTING.md" >/dev/null
grep -F 'istoreos-network-quality' "$root/skills/istoreos-system-task-router/SKILL.md" >/dev/null

for script in "$root"/skills/*/scripts/*.sh; do
  [ -f "$script" ] || continue
  sh -n "$script"
done

sh "$root/tests/test_download_acceleration_dispatch.sh"
sh "$root/tests/test_system_helpers.sh"
sh "$root/tests/test_network_quality_helpers.sh"
sh "$root/tests/test_skill_architecture.sh"

echo "ok: istoreos profile smoke passed"
