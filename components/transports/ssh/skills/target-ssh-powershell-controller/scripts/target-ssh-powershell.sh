#!/bin/sh
set -eu

phase="${1:-}"
case "$phase" in inspect|plan|verify|facts) ;; apply) [ "${TARGET_CHANGE_APPROVED:-}" = "YES" ] || { echo "failed: apply requires approval" >&2; exit 3; } ;; *) echo "usage: target-ssh-powershell.sh inspect|plan|apply|verify|facts" >&2; exit 2 ;; esac
[ "$#" -eq 1 ] || exit 2

target_id="${TARGET_ID:-}"
host="${TARGET_SSH_HOST:-}"
user="${TARGET_SSH_USER:-}"
port="${TARGET_SSH_PORT:-22}"
known_hosts="${TARGET_SSH_KNOWN_HOSTS:-}"
identity="${TARGET_SSH_IDENTITY:-}"
timeout_seconds="${TARGET_TIMEOUT_SECONDS:-30}"
ssh_bin="${TARGET_SSH_BIN:-ssh}"
keygen_bin="${TARGET_SSH_KEYGEN_BIN:-ssh-keygen}"

case "$target_id" in ''|*[!A-Za-z0-9._:-]*) echo "failed: invalid TARGET_ID" >&2; exit 2 ;; esac
case "$host" in ''|-*|*[!A-Za-z0-9._:-]*) echo "failed: invalid TARGET_SSH_HOST" >&2; exit 2 ;; esac
case "$user" in ''|*[!A-Za-z0-9._-]*) echo "failed: invalid TARGET_SSH_USER" >&2; exit 2 ;; esac
case "$port" in ''|*[!0-9]*) echo "failed: invalid port" >&2; exit 2 ;; esac
case "$timeout_seconds" in ''|*[!0-9]*) echo "failed: invalid timeout" >&2; exit 2 ;; esac
[ "$port" -ge 1 ] && [ "$port" -le 65535 ] || exit 2
[ "$timeout_seconds" -ge 1 ] && [ "$timeout_seconds" -le 3600 ] || exit 2
[ -f "$known_hosts" ] || { echo "failed: pinned known_hosts file is required" >&2; exit 2; }
[ -z "$identity" ] || [ -f "$identity" ] || exit 2
lookup="$host"; [ "$port" = 22 ] || lookup="[$host]:$port"
"$keygen_bin" -F "$lookup" -f "$known_hosts" >/dev/null 2>&1 || { echo "failed: target host key is not pinned" >&2; exit 4; }

set -- -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
  -o "UserKnownHostsFile=$known_hosts" -o "ConnectTimeout=$timeout_seconds" -p "$port"
[ -z "$identity" ] || set -- "$@" -i "$identity"
set -- "$@" "$user@$host" powershell.exe -NoLogo -NoProfile -NonInteractive -Command -

if [ "$phase" = facts ]; then
  script='$result = [ordered]@{platform=[Environment]::OSVersion.Platform.ToString(); version=[Environment]::OSVersion.Version.ToString(); architecture=$env:PROCESSOR_ARCHITECTURE; psVersion=$PSVersionTable.PSVersion.ToString()}; $result | ConvertTo-Json -Compress'
else
  script="$(cat)"
fi
echo "target=$target_id transport=ssh shell=powershell phase=$phase" >&2
if command -v timeout >/dev/null 2>&1; then
  printf '%s\n' "$script" | timeout "$timeout_seconds" "$ssh_bin" "$@"
else
  printf '%s\n' "$script" | "$ssh_bin" "$@"
fi
