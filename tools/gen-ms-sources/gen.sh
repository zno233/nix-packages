#!/usr/bin/env bash
# Generate tools/gen-ms-sources/sources.nix from the pjobson/Microsoft-Fonts
# mirror. Requires: bash, jq, curl, sha256sum, base64. No nix needed.
#
# The mapping file map.tsv pairs each target font file name (the name used in
# the Nix package `files` lists) with the display name under which the file is
# archived in pjobson/Microsoft-Fonts ("<display> - <md5>.<ext>.gz").
#
# Sources are searched in Windows-era directories, newest first, preferring
# plain TTF over TTC collections. Target and source extensions must match.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$here/../.." && pwd)
out="$here/sources.nix"

repo=pjobson/Microsoft-Fonts
map_file="$here/map.tsv"

# Directory search order (extension-aware; ttf before ttc within each release).
dirs=(
  "2021 - Windows 11/ttf"
  "2021 - Windows 11/ttc"
  "2015 - Windows 10/ttf"
  "2015 - Windows 10/ttc"
  "2009 - Windows 7/ttf"
  "2009 - Windows 7/ttc"
  "2012 - Windows 8/ttf"
  "2012 - Windows 8/ttc"
)

die() {
  printf 'gen-ms-sources: %s\n' "$*" >&2
  exit 1
}

curl_get() {
  curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors "$@"
}

re_escape() {
  printf %s "$1" | sed 's/[][\\.^$*+?{}|()]/\\&/g'
}

# hex (lowercase, no 0x) -> SRI "sha256-..."
hex2sri() {
  local hex=$1 i
  # binary must stream through a pipe: command substitution would drop NULs
  printf 'sha256-%s' "$(
    for ((i = 0; i < ${#hex}; i += 2)); do
      printf "\\x${hex:i:2}"
    done | base64 -w0
  )"
}

# raw.githubusercontent URL for a tree path (spaces and non-ASCII encoded).
raw_url() {
  local path=$1 enc
  enc=$(printf %s "$path" | jq -sRr @uri | sed 's/%2F/\//g')
  printf 'https://raw.githubusercontent.com/%s/%s/%s' "$repo" "$pin" "$enc"
}

[ -f "$map_file" ] || die "missing $map_file"

# ---- coverage check: package files == map.tsv keys -------------------------
map_keys=$(cut -f1 "$map_file" | sed '/^$/d' | sort -u)
pkg_files=$(
  grep -hoE '"[^"]+\.(ttf|ttc)"' "$repo_root"/packages/microsoft/*/package.nix \
    | tr -d '"' | sort -u
)
if [ "$map_keys" != "$pkg_files" ]; then
  {
    printf 'map.tsv and package.nix file lists disagree.\n\n'
    printf 'Only in map.tsv:\n'
    comm -23 <(printf '%s\n' "$map_keys") <(printf '%s\n' "$pkg_files")
    printf 'Only in package.nix files lists:\n'
    comm -13 <(printf '%s\n' "$map_keys") <(printf '%s\n' "$pkg_files")
    printf '\nUpdate tools/gen-ms-sources/map.tsv (and run this script) to match.\n'
  } >&2
  exit 1
fi

# ---- resolve pin and tree ---------------------------------------------------
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cache="$here/.cache"
mkdir -p "$cache"

# Optional GitHub token raises the API rate limit (needed in CI).
auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

# The mirror is archived upstream; pin and tree results are cached forever.
if [ -s "$cache/pin" ]; then
  pin=$(cat "$cache/pin")
  printf 'gen-ms-sources: pin %s (cached)\n' "$pin" >&2
else
  printf 'gen-ms-sources: resolving %s@main ...\n' "$repo" >&2
  pin=$(curl_get "${auth[@]}" "https://api.github.com/repos/$repo/commits/main" | jq -re '.sha')
  [ -n "$pin" ] || die "could not resolve current main commit of $repo"
  printf '%s' "$pin" > "$cache/pin"
  printf 'gen-ms-sources: pin %s\n' "$pin" >&2
fi

if [ -s "$cache/tree.$pin" ]; then
  cp "$cache/tree.$pin" "$tmp/paths"
else
  curl_get "${auth[@]}" "https://api.github.com/repos/$repo/git/trees/$pin?recursive=1" \
    | jq -re '.tree[].path' > "$tmp/paths"
  [ -s "$tmp/paths" ] || die "empty git tree for $pin"
  cp "$tmp/paths" "$cache/tree.$pin"
fi

# ---- resolve every map row --------------------------------------------------
resolved="$tmp/resolved" # lines: file<TAB>display<TAB>path
: > "$resolved"

fail=0
while IFS=$'\t' read -r file display; do
  [ -z "$file" ] && continue
  ext=".${file##*.}"
  esc_display=$(re_escape "$display")
  hit=""
  for d in "${dirs[@]}"; do
    # directory variant (…/ttf or …/ttc) must match the extension
    case "$d" in *"${ext#.}") ;; *) continue ;; esac
    candidate=$(
      grep -E "^$(re_escape "$d")/${esc_display} - [0-9a-f]{32}$(re_escape "$ext")\.gz$" \
        "$tmp/paths" | head -n1 || true
    )
    if [ -n "$candidate" ]; then
      hit=$candidate
      break
    fi
  done
  if [ -z "$hit" ]; then
    printf 'gen-ms-sources: no source for %s (display name %q)\n' "$file" "$display" >&2
    fail=1
    continue
  fi
  printf '%s\t%s\t%s\n' "$file" "$display" "$hit" >> "$resolved"
done < "$map_file"

if [ "$fail" -ne 0 ]; then
  die 'unresolved files; sources.nix NOT written (extend map.tsv or fix package files)'
fi

# ---- download, hash ---------------------------------------------------------
entries="$tmp/entries"
: > "$entries"

total=$(wc -l < "$resolved")
n=0
while IFS=$'\t' read -r file display path; do
  n=$((n + 1))
  gz="$cache/$(basename "$path")"
  printf 'gen-ms-sources: [%d/%d] %s <- %s\n' "$n" "$total" "$file" "$display" >&2
  if [ ! -f "$gz" ]; then
    curl_get "$(raw_url "$path")" -o "$gz.part"
    mv "$gz.part" "$gz"
  fi
  hex=$(sha256sum "$gz" | cut -d' ' -f1)
  sri=$(hex2sri "$hex")
  url=$(raw_url "$path")
  jq -cn --arg f "$file" --arg u "$url" --arg h "$sri" \
    '{file: $f, url: $u, hash: $h}' >> "$entries"
done < "$resolved"

# ---- emit sources.nix -------------------------------------------------------
{
  cat <<EOF
# Generated by tools/gen-ms-sources/gen.sh — DO NOT EDIT MANUALLY.
#
# Direct-download sources for Microsoft font files, taken from the
# pjobson/Microsoft-Fonts archive of Microsoft Windows font files.
# Display-name mapping: tools/gen-ms-sources/map.tsv
# Regenerate with: tools/gen-ms-sources/gen.sh
{
  pin = "$pin";
  version = "${pin:0:7}";
  files = {
EOF
  cp "$entries" "$cache/entries.last"
  n=0
  while IFS= read -r row; do
    n=$((n + 1))
    if ! jq -r '"    \(.file | @json) = {\n      url = \(.url | @json);\n      hash = \(.hash | @json);\n    };"' <<<"$row"; then
      die "corrupt entries line $n: $row"
    fi
  done < "$entries"
  cat <<'EOF'
  };
}
EOF
} > "$tmp/sources.nix"

mv "$tmp/sources.nix" "$out"
printf 'gen-ms-sources: wrote %s (%d files, pin %s)\n' "$out" "$total" "$pin" >&2
