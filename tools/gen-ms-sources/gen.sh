#!/usr/bin/env bash
# Generate tools/gen-ms-sources/sources.nix from the uinv/windows-fonts
# `windows11` branch snapshot. Requires: bash, jq, curl, sha256sum, base64.
# No nix needed.
#
# The snapshot is flat: every font file sits at the tree root and is
# addressed by its exact-case file name, so no display-name mapping is
# needed — a package's `files` entries must match the upstream file names
# verbatim. Coverage is checked against packages/fonts/microsoft/*/package.nix.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
repo_root=$(cd "$here/../.." && pwd)
out="$here/sources.nix"

repo=uinv/windows-fonts
branch=windows11
jobs=${JOBS:-8}

die() {
  printf 'gen-ms-sources: %s\n' "$*" >&2
  exit 1
}

curl_get() {
  curl -fsSL --retry 5 --retry-delay 2 --retry-all-errors "$@"
}

# hex (lowercase, no 0x) -> SRI "sha256-..."
hex2sri() {
  local hex=$1 i
  # binary must stream through a pipe: command substitution would drop NULs
  printf 'sha256-%s' "$(
    for ((i = 0; i < ${#hex}; i += 2)); do
      # dynamic \x escape into the format string: it is on purpose — bash's
      # printf only accepts literal hex digits in \xHH, so \x%s would emit
      # the backslash-x text instead of the byte
      # shellcheck disable=SC2059
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

# ---- resolve pin and tree ----------------------------------------------------
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cache="$here/.cache"
mkdir -p "$cache"

# Optional GitHub token raises the API rate limit (needed in CI).
auth=()
if [ -n "${GITHUB_TOKEN:-}" ]; then
  auth=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

slug=${repo//\//-}

# snapshot tracks a moving branch; GEN_MS_SOURCES_PIN can hard-pin a
# commit (the run then uses exactly that tree), otherwise the cached commit
# refreshes daily so regular runs pick up new files without re-resolving
# on every invocation. Remove $cache/pin.$slug to force a re-resolve.
pin_cache="$cache/pin.$slug"
if [ -n "${GEN_MS_SOURCES_PIN:-}" ]; then
  pin=$GEN_MS_SOURCES_PIN
  printf 'gen-ms-sources: pin %s (GEN_MS_SOURCES_PIN)\n' "$pin" >&2
elif [ -s "$pin_cache" ] && ! find "$pin_cache" -mmin +1440 | grep -q .; then
  pin=$(cat "$pin_cache")
  printf 'gen-ms-sources: pin %s (cached)\n' "$pin" >&2
else
  printf 'gen-ms-sources: resolving %s@%s ...\n' "$repo" "$branch" >&2
  pin=$(curl_get "${auth[@]}" "https://api.github.com/repos/$repo/commits/$branch" | jq -re .sha)
  [ -n "$pin" ] || die "could not resolve current $branch commit of $repo"
  printf '%s' "$pin" > "$pin_cache"
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

# The flat layout addresses every file by basename alone; duplicated
# basenames across directories would make resolution ambiguous.
sed 's|.*/||' "$tmp/paths" | sort -u > "$tmp/names"
dupes=$(sort <(sed 's|.*/||' "$tmp/paths") | uniq -d || true)
if [ -n "$dupes" ]; then
  printf 'duplicate file names in %s@%s: %s\n' "$repo" "$branch" "$dupes" >&2
  die 'ambiguous snapshot layout; resolve manually'
fi

# ---- coverage check: every package file exists in the snapshot ---------------
pkg_files="$(
  grep -hoE '"[^"]+\.(ttf|ttc)"' "$repo_root"/packages/fonts/microsoft/*/package.nix \
    | tr -d '"' | sort -u
)"
[ -n "$pkg_files" ] || die 'no .ttf/.ttc references in packages/fonts/microsoft'

fail=0
while IFS= read -r file; do
  [ -z "$file" ] && continue
  grep -qxF "$file" "$tmp/names" && continue
  printf 'gen-ms-sources: %s missing from %s@%s\n' "$file" "$repo" "$branch" >&2
  fail=1
done < <(printf '%s\n' "$pkg_files")
if [ "$fail" -ne 0 ]; then
  die 'package files not in snapshot; sources.nix NOT written (fix file names or pin an older commit)'
fi

# Flat layout: the tree path for each package file is the file name itself.
printf '%s\n' "$pkg_files" > "$tmp/resolved"

# ---- download, hash ----------------------------------------------------------
# One entry line per file, cached under a hash of the file name so font
# names with spaces or non-ASCII bytes still get one slot each.
entries_dir="$tmp/entries"
mkdir -p "$entries_dir"

total=$(wc -l < "$tmp/resolved")

build_entry() {
  local file=$1
  local dest="$cache/$file" hex url
  url=$(raw_url "$file")
  printf 'gen-ms-sources: %s\n' "$file" >&2
  if [ ! -s "$dest" ]; then
    curl_get "$url" -o "$dest.part"
    mv "$dest.part" "$dest"
  fi
  hex=$(sha256sum "$dest" | cut -d' ' -f1)
  jq -cn --arg f "$file" --arg u "$url" --arg h "$(hex2sri "$hex")" \
    '{file: $f, url: $u, hash: $h}' \
    > "$entries_dir/$(printf %s "$file" | sha256sum | cut -d' ' -f1)"
}

export -f build_entry curl_get hex2sri raw_url
export here repo pin cache entries_dir

printf 'gen-ms-sources: hashing %d files (%d parallel)\n' "$total" "$jobs" >&2
hash_entries() {
  # single quotes are required: the snippet is code run by the child shell
  # shellcheck disable=SC2016
  xargs -n2 -P "$jobs" bash -c 'build_entry "$1"' _
}
while IFS= read -r file; do
  printf '%s\t%s\n' "$file" "$file"
done < "$tmp/resolved" | hash_entries

entries="$tmp/entries.all"
find "$entries_dir" -type f -exec cat {} + |
  while IFS= read -r row; do
    printf '%s\t%s\n' "$(jq -r .file <<<"$row")" "$row"
  done |
  LC_ALL=C sort |
  cut -f2- > "$entries"
[ "$(wc -l < "$entries")" -eq "$total" ] ||
  die "entry count $(wc -l < "$entries") != $total"

# ---- emit sources.nix --------------------------------------------------------
{
  cat <<EOF
# Generated by tools/gen-ms-sources/gen.sh — DO NOT EDIT MANUALLY.
#
# Direct-download sources for Microsoft font files, taken from the
# uinv/windows-fonts ${branch} snapshot of the Windows font set.
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
