# Pin data for the honk packages, refreshed by tools/update-pins — do not
# edit by hand!
#
# Both glibc variants are built from the same release tag: version is the
# SemVer tag and every hash is the sha256 of
# honk-core-<tag>-<arch>-unknown-linux-gnu-<asset>.tar.gz, taken from the
# release's SHA256SUMS (flavor "full" = the -full asset, "stock" = the
# -stock-full asset). Flat one-line entries keep each hash matched by
# exactly one update-pins recipe (tools/update-pins.toml).
{
  version = "v0.1.0-beta.2";
  hashes.x86_64-linux.full = "sha256-xbAgQMl1P/8glRdQS265/IogmnsgyHOQmmUJUXU1bcY=";
  hashes.x86_64-linux.stock = "sha256-FGq0bxXQXCHke+laDWUN+JpPhrxlbLqRBDzjRndC7B4=";
  hashes.aarch64-linux.full = "sha256-h/zm0ckWOPK1imhAW8fa6tcITv2EwMAxwpeMVD1BtwY=";
  hashes.aarch64-linux.stock = "sha256-NSy9KGjfPI4kXXUE1yNxt2O5TQvGwxRtyOkujFSJb6M=";
}
