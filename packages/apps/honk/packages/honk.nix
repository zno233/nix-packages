# Pin data for the honk packages, refreshed by tools/update-pins — do not
# edit by hand!
#
# Both glibc variants are built from the same release tag: version is the
# SemVer tag and every hash is the sha256 of
# honk-core-<tag>-<arch>-unknown-linux-gnu-<asset>.tar.gz, taken from the
# digest GitHub records for that release asset (flavor "full" = the -full
# asset, "stock" = the -stock-full asset). Flat one-line entries keep each
# hash matched by exactly one update-pins recipe (tools/update-pins.toml).
{
  version = "v0.1.0-beta.7";
  hashes.x86_64-linux.full = "sha256-Qjfqt1NhPHQdD3e1calf01Vz013C6e48r1uhkzt+haE=";
  hashes.x86_64-linux.stock = "sha256-SyD/ELVaUYtC2Gzd2rVDZFrFuYzoAwRHHY8YFJZS83M=";
  hashes.aarch64-linux.full = "sha256-7iy+WnkahA1oVxxj6gZrJNnOGTCGcWt7cp4jCd/S+tQ=";
  hashes.aarch64-linux.stock = "sha256-wVakF3ps9OOo9kox4zW3siOw62p3avJRL4d4rwAEm3g=";
}
