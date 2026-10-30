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
  version = "v0.1.0-beta.4";
  hashes.x86_64-linux.full = "sha256-ReS3l12XG/aROlpK2aK1aTjdQnkwsjT+xRJXUmOrhL0=";
  hashes.x86_64-linux.stock = "sha256-LLj/GlFLbEt8nQbw9AoskNjVCVb+hO43G8mfnBE5Sd0=";
  hashes.aarch64-linux.full = "sha256-YyDuKJ5PIlGxHoC3Oz9g5ExVyVH8AblCCse5lxsVBO4=";
  hashes.aarch64-linux.stock = "sha256-IcRLB985goAHKVrbTJRuHRtzylSPdFNfjPNTmy+dIDs=";
}
