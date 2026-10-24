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
  version = "v0.1.0-beta.1";
  hashes.x86_64-linux.full = "sha256-MyprLOnoxImJCf+B8y1LVLdkcENeI7uJushtX7AZzTM=";
  hashes.x86_64-linux.stock = "sha256-3O0vGpxgpub9LIVnB3U3+B+0ItjKshaP74+ZkizEiP8=";
  hashes.aarch64-linux.full = "sha256-2eGa/B/PEicEJQeUvgqmhcgRAk2jig7DPcn3Wk7mAPU=";
  hashes.aarch64-linux.stock = "sha256-2jQNTT9zEDdGjjS6W7OtDxG1+lSRuld7/LEd4OFMCGM=";
}
