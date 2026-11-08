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
  version = "v0.1.0-beta.6";
  hashes.x86_64-linux.full = "sha256-fVIIDhizrRctmkGk6jioT/CfOkjNfa/50IcsbYe6TKc=";
  hashes.x86_64-linux.stock = "sha256-0+8wtSAV4LdB/H5EIGf3byfVNZI+P67w+Y6jxwrPBYE=";
  hashes.aarch64-linux.full = "sha256-tveNxbVfKX1A3/G/yTY3WIn2NdLNz/yipKNRxv4QlE0=";
  hashes.aarch64-linux.stock = "sha256-231/gfa1jTk6wBK/y/Q1g4CmhvLBFn+OC1UL6YE0r9U=";
}
