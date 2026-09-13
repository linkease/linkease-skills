#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)"
pack="$root/components/system-packs/windows"
controller="$root/components/transports/ssh/skills/target-ssh-powershell-controller"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/linkease-skills-m8.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  echo "failed: $*" >&2
  exit 1
}

jq -e '.id == "windows" and .match.osFamily == "windows" and .requires == ["target-shell:powershell"]' \
  "$pack/pack.json" >/dev/null
jq -e '.schemaVersion == 1 and .os.version != "" and (.fixedDisks | length == 1)' \
  "$root/tests/fixtures/windows/diagnostics.json" >/dev/null

for skill in "$pack"/skills/*/SKILL.md; do
  grep -q '^owner: system-pack/windows$' "$skill"
  grep -q '^systems: windows$' "$skill"
  grep -q '^requires: target-shell:powershell$' "$skill"
done
grep -q 'TARGET_CHANGE_APPROVED' "$pack/skills/windows-service-eventlog/scripts/apply.ps1"
if grep -R -E 'Invoke-Expression|iex[[:space:]]' "$pack/skills" --include='*.ps1' >/dev/null; then
  fail "Windows scripts use dynamic PowerShell evaluation"
fi
grep -q '8192' "$pack/skills/windows-system-diagnostics/scripts/inspect.ps1"

runner="$controller/scripts/target-ssh-powershell.sh"
sh -n "$runner"
cat >"$tmp/fake-keygen" <<'EOF'
#!/bin/sh
exit 0
EOF
cat >"$tmp/fake-ssh" <<'EOF'
#!/bin/sh
cat >"$FAKE_REMOTE_CAPTURE"
EOF
chmod +x "$tmp/fake-keygen" "$tmp/fake-ssh"
: >"$tmp/known_hosts"
: >"$tmp/host-sentinel"
printf 'Remove-Item -LiteralPath "%s"\n' "$tmp/host-sentinel" |
  TARGET_ID=windows-fixture TARGET_SSH_HOST=windows.example TARGET_SSH_USER=operator \
  TARGET_SSH_KNOWN_HOSTS="$tmp/known_hosts" TARGET_SSH_BIN="$tmp/fake-ssh" \
  TARGET_SSH_KEYGEN_BIN="$tmp/fake-keygen" FAKE_REMOTE_CAPTURE="$tmp/remote.ps1" \
  sh "$runner" inspect >/dev/null
[ -f "$tmp/host-sentinel" ] || fail "PowerShell target script executed on controller host"
grep -q 'Remove-Item' "$tmp/remote.ps1" || fail "PowerShell script was not sent to SSH adapter"
if printf 'Get-Service\n' | TARGET_ID=windows-fixture TARGET_SSH_HOST=windows.example \
  TARGET_SSH_USER=operator TARGET_SSH_KNOWN_HOSTS="$tmp/known_hosts" \
  TARGET_SSH_BIN="$tmp/fake-ssh" TARGET_SSH_KEYGEN_BIN="$tmp/fake-keygen" \
  FAKE_REMOTE_CAPTURE="$tmp/remote.ps1" sh "$runner" apply >/dev/null 2>&1; then
  fail "remote PowerShell apply succeeded without approval"
fi

sh "$root/tools/generate-platforms.sh" "$tmp/platforms" >/dev/null
for mode in on-device remote-control; do
  sh "$tmp/platforms/windows/$mode/install.sh" --target "$tmp/install-$mode" >/dev/null
done
on_device="$(find "$tmp/install-on-device" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
remote="$(find "$tmp/install-remote-control" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[ "$on_device" -eq 2 ] || fail "Windows on-device expected 2 skills, got $on_device"
[ "$remote" -eq 3 ] || fail "Windows remote-control expected 3 skills, got $remote"
[ -f "$tmp/install-remote-control/target-ssh-powershell-controller/SKILL.md" ] || fail "Windows SSH controller missing"
[ ! -d "$root/components/transports/winrm" ] || fail "unimplemented WinRM placeholder exists"

sh "$root/tools/verify-generated.sh"
sh "$root/tests/architecture/test-catalog.sh"
echo "M8 Windows vertical slice: PASS"
