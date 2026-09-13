#!/bin/sh
set -eu

root="$(CDPATH= cd -- "$(dirname "$0")/../.." && pwd -P)"
ssh_skill="$root/components/transports/ssh/skills/target-ssh-controller"
luci_skill="$root/components/transports/luci-http/skills/luci-http-controller"
runner="$ssh_skill/scripts/target-ssh.sh"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/linkease-skills-m3.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

fail() {
  echo "failed: $*" >&2
  exit 1
}

jq -e '.kind == "transport" and (.provides | index("target.exec"))' \
  "$root/components/transports/ssh/component.json" >/dev/null
jq -e '.kind == "transport" and (.provides | index("target.http"))' \
  "$root/components/transports/luci-http/component.json" >/dev/null

grep -q '^owner: transport/ssh$' "$ssh_skill/SKILL.md"
grep -q '^systems: any$' "$ssh_skill/SKILL.md"
grep -q '^owner: transport/luci-http$' "$luci_skill/SKILL.md"
grep -q '^systems: any$' "$luci_skill/SKILL.md"

if grep -R -E -i 'istoreos|openwrt|quickstart|opkg|docker|uci commit' \
  "$root/components/transports" --exclude='*.sum' >/dev/null; then
  fail "transport component contains operating-system business policy"
fi
if grep -R -F 'StrictHostKeyChecking=no' "$root/components/transports" --include='*.sh' --include='*.go' >/dev/null; then
  fail "transport disables SSH host-key verification"
fi

sh -n "$runner" "$root/istoreos/skills/istoreos-quickstart-api/scripts/request.sh"

cat >"$tmp/fake-keygen" <<'EOF'
#!/bin/sh
exit "${FAKE_KEYGEN_STATUS:-0}"
EOF
cat >"$tmp/fake-ssh" <<'EOF'
#!/bin/sh
cat >"$FAKE_REMOTE_CAPTURE"
EOF
chmod +x "$tmp/fake-keygen" "$tmp/fake-ssh"
: >"$tmp/known_hosts"
: >"$tmp/controller-sentinel"

run_fake() {
  env \
    TARGET_ID=router-test \
    TARGET_SSH_HOST=router.example \
    TARGET_SSH_USER=root \
    TARGET_SSH_KNOWN_HOSTS="$tmp/known_hosts" \
    TARGET_SSH_BIN="$tmp/fake-ssh" \
    TARGET_SSH_KEYGEN_BIN="$tmp/fake-keygen" \
    FAKE_REMOTE_CAPTURE="$tmp/remote-script" \
    "$@"
}

printf 'rm -f %s\nprintf "remote-only\\n"\n' "$tmp/controller-sentinel" |
  run_fake sh "$runner" inspect >/dev/null
[ -f "$tmp/controller-sentinel" ] || fail "target script executed on controller host"
grep -F "$tmp/controller-sentinel" "$tmp/remote-script" >/dev/null ||
  fail "target script was not sent to fake SSH adapter"

if printf 'true\n' | run_fake sh "$runner" apply >/dev/null 2>&1; then
  fail "apply succeeded without explicit approval"
fi
printf 'true\n' | TARGET_CHANGE_APPROVED=YES run_fake sh "$runner" apply >/dev/null

if printf 'true\n' | FAKE_KEYGEN_STATUS=1 run_fake sh "$runner" inspect >/dev/null 2>&1; then
  fail "unknown SSH host key was accepted"
fi

(
  cd "$luci_skill/scripts"
  go test lucihttp.go lucihttp_test.go
)

sh "$root/tests/architecture/test-m2-canonical.sh"
echo "M3 transport contracts: PASS"
