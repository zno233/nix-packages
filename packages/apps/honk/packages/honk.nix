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
  version = "v0.1.0-beta.3";
  hashes.x86_64-linux.full = "sha256-6oUlgdEYKwRLoPgVceWWFmhUlHsaS/5SkTt5bCBXB4c=";
  hashes.x86_64-linux.stock = "sha256-YB2hU78hhR8GTs/1AReQJLsfaYsocfGkMjUiJs8VI1A=";
  hashes.aarch64-linux.full = "sha256-ZHC41mXGCbCNAJ0kPuRMCtOUib8GjhdzVkTfUzlMj/k=";
  hashes.aarch64-linux.stock = "sha256-senCfDGonVOVVr+MrAkrzEe/an2lbYPWb8HQhzvFhQU=";
}
