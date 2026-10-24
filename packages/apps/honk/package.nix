# honk — prebuilt glibc builds from the daeuniverse/honk release assets
# (no compilation).
#
# honk publishes its own releases (SemVer tags; rolling "debug"-tagged
# releases carry CI artefacts and are skipped by the update rule). Every
# release attaches per-arch archives and their SHA256SUMS:
#   -unknown-linux-gnu       glibc build; packed by this derivation
#                            (autoPatchelfHook, see make-honk.nix)
#   -unknown-linux-musl      static build, needs no patching at all (not
#                            packaged here)
#   full / -stock-full       API set bundled into the glibc build: "full"
#                            (mimalloc) and "stock-full" (system allocator)
#                            both carry both APIs (clash-api and
#                            native-api) and the embedded doona UI — on
#                            glibc the per-API builds (-clash-api/
#                            -native-api) exist only for musl
# Both variants are built from the same release tag, and both versions and
# hashes land in ./packages/honk.nix, driven by tools/update-pins
# (tools/update-pins.toml).
{ callPackage }:

let
  flavorData = {
    honk = {
      flavor = "full";
      allocator = "mimalloc";
    };
    honk-stock = {
      flavor = "stock";
      allocator = "the system allocator";
    };
  };

  mkHonk =
    name:
    let
      pin = import ./packages/honk.nix;
      fd = flavorData.${name};
    in
    callPackage
      (import ./make-honk.nix {
        pname = name;
        inherit (pin) version hashes;
        inherit (fd) flavor allocator;
      })
      { };
in
{
  honk = mkHonk "honk";
  honk-stock = mkHonk "honk-stock";
}
