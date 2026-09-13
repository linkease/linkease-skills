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
  mode="$1"
  title="$2"
  generated_from_json="$3"
  component_versions_json="$4"
  shift 4
  preset="$output/istoreos/$mode"
  rm -rf "$preset"
  mkdir -p "$preset/skills"
  copy_skills "$preset/skills" "$@"
  cp "$root/tools/preset-install.sh" "$preset/install.sh"
  chmod +x "$preset/install.sh"

  source_digest="$(hash_roots "$@")"
  tree_digest="$(hash_tree "$preset/skills")"
  jq -n \
    --arg id "istoreos-$mode" \
    --arg title "$title" \
    --arg mode "$mode" \
    --arg sourceDigest "$source_digest" \
    --arg treeDigest "$tree_digest" \
    --argjson generatedFrom "$generated_from_json" \
    --argjson componentVersions "$component_versions_json" \
    '{schemaVersion: 1, id: $id, title: $title, platform: "istoreos", mode: $mode,
      aliases: [], path: ".", skillsRoot: "skills", generated: true,
      generatedFrom: $generatedFrom, componentVersions: $componentVersions,
      sourceDigest: $sourceDigest, treeDigest: $treeDigest}' \
    >"$preset/preset.json"
  cp "$preset/preset.json" "$preset/.generated.json"
  printf '%s\n' \
    '# Generated iStoreOS preset' \
    '' \
    'This directory is generated. Do not edit it; change `components/` and run `tools/generate-platforms.sh`.' \
    '' \
    'Install only this preset with `sh install.sh --target /path/to/skills`.' \
    >"$preset/README.md"
}

mkdir -p "$output/istoreos"
system_roots="components/system-packs/common/skills components/system-packs/linux/skills components/system-packs/openwrt/skills components/system-packs/istoreos/skills"
make_preset on-device "Use an agent on an iStoreOS device" \
  '["system.common","system.linux","system.openwrt","system.istoreos"]' \
  '{"system.common":"1.0.0","system.linux":"1.0.0","system.openwrt":"1.0.0","system.istoreos":"1.0.0"}' \
  $system_roots
make_preset remote-control "Control an iStoreOS device remotely" \
  '["system.common","system.linux","system.openwrt","system.istoreos","transport.ssh","transport.luci-http"]' \
  '{"system.common":"1.0.0","system.linux":"1.0.0","system.openwrt":"1.0.0","system.istoreos":"1.0.0","transport.ssh":"1.0.0","transport.luci-http":"1.0.0"}' \
  $system_roots components/transports/ssh/skills components/transports/luci-http/skills

printf '%s\n' \
  '# iStoreOS skills' \
  '' \
  '- `on-device/`: the Agent runs on the iStoreOS device.' \
  '- `remote-control/`: the Agent runs elsewhere and controls iStoreOS.' \
  >"$output/istoreos/README.md"

echo "ok: generated $output/istoreos"
