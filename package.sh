#!/bin/sh
set -eu

profile="all"
format="zip"
out=""

usage() {
  cat >&2 <<'EOF'
Usage:
  sh package.sh [--profile NAME|--all-profiles] [--zip|--tar.gz|--all] [OUT]

Defaults:
  --all-profiles --zip

Examples:
  sh package.sh --profile istoreos --zip /tmp/linkease-skills-istoreos.zip
  sh package.sh --all-profiles --all
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile)
      shift
      [ "$#" -gt 0 ] || { usage; exit 2; }
      profile="$1"
      ;;
    --all-profiles)
      profile="all"
      ;;
    --zip)
      format="zip"
      ;;
    --tar.gz|--tgz)
      format="tar.gz"
      ;;
    --all)
      format="all"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      [ -z "$out" ] || { usage; exit 2; }
      out="$1"
      ;;
  esac
  shift
done

root="$(CDPATH= cd -- "$(dirname "$0")" && pwd -P)"
parent="$(dirname "$root")"
base="$(basename "$root")"

abs_out() {
  case "$1" in
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$(pwd)/$1" ;;
  esac
}

write_checksum() {
  file="$1"
  rm -f "$file.sha256"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" >"$file.sha256"
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" >"$file.sha256"
  else
    echo "warn: sha256sum/shasum not found; checksum not written" >&2
  fi
}

archive_name() {
  suffix="$1"
  if [ "$profile" = "all" ]; then
    printf '%s/linkease-skills.%s\n' "$parent" "$suffix"
  else
    printf '%s/linkease-skills-%s.%s\n' "$parent" "$profile" "$suffix"
  fi
}

tar_paths() {
  if [ "$profile" = "all" ]; then
    printf '%s\n' "$base"
  else
    [ -d "$root/$profile" ] || { echo "failed: missing profile $profile" >&2; exit 1; }
    printf '%s\n' "$base/install.sh"
    printf '%s\n' "$base/package.sh"
    printf '%s\n' "$base/README.md"
    printf '%s/%s\n' "$base" "$profile"
  fi
}

make_targz() {
  file="$1"
  rm -f "$file" "$file.sha256"
  tar \
    --exclude "$base/.git" \
    --exclude "$base/*/.git" \
    --exclude "$base/*.zip" \
    --exclude "$base/*.tar.gz" \
    -C "$parent" \
    -czf "$file" \
    $(tar_paths)
  write_checksum "$file"
}

make_zip() {
  file="$1"
  command -v zip >/dev/null 2>&1 || { echo "failed: zip command not found" >&2; exit 2; }
  rm -f "$file" "$file.sha256"
  (
    cd "$parent"
    zip -qr "$file" $(tar_paths) \
      -x "$base/.git/*" \
      -x "$base/*/.git/*" \
      -x "$base/*.zip" \
      -x "$base/*.tar.gz"
  )
  write_checksum "$file"
}

case "$format" in
  zip)
    out="$(abs_out "${out:-$(archive_name zip)}")"
    make_zip "$out"
    echo "archive: $out" >&2
    [ -f "$out.sha256" ] && echo "checksum: $out.sha256" >&2
    ;;
  tar.gz)
    out="$(abs_out "${out:-$(archive_name tar.gz)}")"
    make_targz "$out"
    echo "archive: $out" >&2
    [ -f "$out.sha256" ] && echo "checksum: $out.sha256" >&2
    ;;
  all)
    [ -z "$out" ] || { echo "failed: --all does not accept OUT" >&2; exit 2; }
    zipfile="$(archive_name zip)"
    targz="$(archive_name tar.gz)"
    make_zip "$zipfile"
    make_targz "$targz"
    echo "archive: $zipfile" >&2
    [ -f "$zipfile.sha256" ] && echo "checksum: $zipfile.sha256" >&2
    echo "archive: $targz" >&2
    [ -f "$targz.sha256" ] && echo "checksum: $targz.sha256" >&2
    ;;
  *)
    usage
    exit 2
    ;;
esac
