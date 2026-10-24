# Local application packages, discovered from packages/apps/<name>/package.nix.
# This keeps `packages.<system>` in sync with the directory listing; new apps
# only need a new directory here, never a flake.nix edit.
#
# A directory may also publish release variants of one upstream: its
# package.nix returns an attrset of derivations (see packages/apps/honk/),
# and those attributes are re-exported flat from this set, nixpkgs
# all-packages.nix style ("brave = (callPackage …).brave"). Variant names
# must not collide with any other package name under packages/apps/. Keep
# the explicit re-exports below in sync with flake.nix's appPackages. The
# set stays lazy — nothing here may force a derivation's WHNF, because
# nixpkgs re-applies overlays for every stdenv boot stage.
{ lib, projectRoot }:
final: _prev:
let
  apps = lib.packagesFromDirectoryRecursive {
    inherit (final) callPackage;

    directory = projectRoot + /packages/apps;
  };
in
apps
// {
  honk = apps.honk.honk;
  honk-stock = apps.honk.honk-stock;
}
