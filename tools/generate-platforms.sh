#!/bin/sh
set -eu

root="${LINKEASE_SKILLS_ROOT:-$(CDPATH= cd -- "$(dirname "$0")/.." && pwd -P)}"
output="${1:-$root/platforms}"
case "$output" in ''|/) echo "failed: unsafe output path" >&2; exit 2 ;; esac
command -v jq >/dev/null 2>&1 || { echo "failed: jq is required" >&2; exit 2; }
command -v sha256sum >/dev/null 2>&1 || { echo "failed: sha256sum is required" >&2; exit 2; }

tmp="$(mktemp -d "${TMPDIR:-/tmp}/linkease-platforms.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

hash_roots() {
  : >"$tmp/files"
  for relative_root in "$@"; do
    find "$root/$relative_root" -type f | sed "s#^$root/##" >>"$tmp/files"
  done
  LC_ALL=C sort -u "$tmp/files" -o "$tmp/files"
  while IFS= read -r relative_file; do
    printf '%s  %s\n' "$(sha256sum "$root/$relative_file" | awk '{print $1}')" "$relative_file"
  done <"$tmp/files" | sha256sum | awk '{print "sha256:" $1}'
}

hash_tree() {
  tree="$1"
  find "$tree" -type f | sed "s#^$tree/##" | LC_ALL=C sort |
  while IFS= read -r relative_file; do
    printf '%s  %s\n' "$(sha256sum "$tree/$relative_file" | awk '{print $1}')" "$relative_file"
  done | sha256sum | awk '{print "sha256:" $1}'
}

copy_skills() {
  destination="$1"
  shift
  for source_root in "$@"; do
    if [ -f "$root/$source_root/SKILL.md" ]; then
      source="$root/$source_root"
      name="$(basename "$source")"
      [ ! -e "$destination/$name" ] || {
        echo "failed: duplicate generated skill $name" >&2
        exit 1
      }
      cp -R "$source" "$destination/$name"
      continue
    fi
    for source in "$root/$source_root"/*; do
      [ -f "$source/SKILL.md" ] || continue
      name="$(basename "$source")"
      [ ! -e "$destination/$name" ] || {
        echo "failed: duplicate generated skill $name" >&2
        exit 1
      }
      cp -R "$source" "$destination/$name"
    done
  done
}

make_preset() {
  platform="$1"
  mode="$2"
  title="$3"
  generated_from_json="$4"
  component_versions_json="$5"
  shift 5
  preset="$output/$platform/$mode"
  rm -rf "$preset"
  mkdir -p "$preset/skills"
  copy_skills "$preset/skills" "$@"
  cp "$root/tools/preset-install.sh" "$preset/install.sh"
  chmod +x "$preset/install.sh"

  source_digest="$(hash_roots "$@")"
  tree_digest="$(hash_tree "$preset/skills")"
  jq -n \
    --arg id "$platform-$mode" \
    --arg title "$title" \
    --arg platform "$platform" \
    --arg mode "$mode" \
    --arg sourceDigest "$source_digest" \
    --arg treeDigest "$tree_digest" \
    --argjson generatedFrom "$generated_from_json" \
    --argjson componentVersions "$component_versions_json" \
    '{schemaVersion: 1, id: $id, title: $title, platform: $platform, mode: $mode,
      aliases: [], path: ".", skillsRoot: "skills", generated: true,
      generatedFrom: $generatedFrom, componentVersions: $componentVersions,
      sourceDigest: $sourceDigest, treeDigest: $treeDigest}' \
    >"$preset/preset.json"
  cp "$preset/preset.json" "$preset/.generated.json"
  printf '%s\n' \
    "# Generated $platform preset" \
    '' \
    'This directory is generated. Do not edit it; change `components/` and run `tools/generate-platforms.sh`.' \
    '' \
    'Install only this preset with `sh install.sh --target /path/to/skills`.' \
    >"$preset/README.md"
}

mkdir -p "$output/istoreos"
system_roots="components/system-packs/common/skills components/system-packs/linux/skills components/system-packs/openwrt/skills components/system-packs/istoreos/skills"
make_preset istoreos on-device "Use an agent on an iStoreOS device" \
  '["common","linux","openwrt","istoreos"]' \
  '{"common":"1.0.0","linux":"1.0.0","openwrt":"1.0.0","istoreos":"2.0.0"}' \
  $system_roots
make_preset istoreos remote-control "Control an iStoreOS device remotely" \
  '["common","linux","openwrt","istoreos","transport.ssh","transport.luci-http"]' \
  '{"common":"1.0.0","linux":"1.0.0","openwrt":"1.0.0","istoreos":"2.0.0","transport.ssh":"1.1.0","transport.luci-http":"1.0.0"}' \
  $system_roots components/transports/ssh/skills/target-ssh-controller components/transports/luci-http/skills

printf '%s\n' \
  '# iStoreOS skills' \
  '' \
  '- `on-device/`: the Agent runs on the iStoreOS device.' \
  '- `remote-control/`: the Agent runs elsewhere and controls iStoreOS.' \
  >"$output/istoreos/README.md"

echo "ok: generated $output/istoreos"

mkdir -p "$output/windows"
windows_roots="components/system-packs/common/skills components/system-packs/windows/skills"
make_preset windows on-device "Use an agent on a Windows device" \
  '["common","windows"]' \
  '{"common":"1.0.0","windows":"1.0.0"}' \
  $windows_roots
make_preset windows remote-control "Control a Windows device remotely" \
  '["common","windows","transport.ssh"]' \
  '{"common":"1.0.0","windows":"1.0.0","transport.ssh":"1.1.0"}' \
  $windows_roots components/transports/ssh/skills/target-ssh-powershell-controller

printf '%s\n' \
  '# Windows skills' \
  '' \
  '- `on-device/`: the Agent runs on Windows with PowerShell.' \
  '- `remote-control/`: the Agent uses Windows OpenSSH and PowerShell.' \
  >"$output/windows/README.md"

echo "ok: generated $output/windows"

mkdir -p "$output/macos"
macos_roots="components/system-packs/common/skills components/system-packs/macos/skills"
make_preset macos on-device "Use an agent on a macOS device" \
  '["common","macos"]' \
  '{"common":"1.0.0","macos":"1.0.0"}' \
  $macos_roots
make_preset macos remote-control "Control a macOS device remotely" \
  '["common","macos","transport.ssh"]' \
  '{"common":"1.0.0","macos":"1.0.0","transport.ssh":"1.1.0"}' \
  $macos_roots components/transports/ssh/skills/target-ssh-controller

printf '%s\n' \
  '# macOS skills' \
  '' \
  '- `on-device/`: the Agent runs on macOS.' \
  '- `remote-control/`: the Agent uses SSH and a POSIX target shell.' \
  >"$output/macos/README.md"

echo "ok: generated $output/macos"
