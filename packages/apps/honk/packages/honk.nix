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
  version = "v0.1.0-beta.5";
  hashes.x86_64-linux.full = "sha256-eDWxbK4IVZBZJ57T8AmLdGBrZaBrjoMcfVvtqmmWc4Q=";
  hashes.x86_64-linux.stock = "sha256-XO1sQkqh6qpSwtwmERrF21ogZIupTdVcAMFDw/xybQ4=";
  hashes.aarch64-linux.full = "sha256-RCdBwPRZAXFMBb1i+LYkKCXMaF2fszi64C0Qdpi4BlY=";
  hashes.aarch64-linux.stock = "sha256-Felc85mv+2iA3tcKY/KfXos2emZ2nDqIS+8GC9rczkY=";
}
