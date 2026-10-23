# Local application packages, discovered from packages/apps/<name>/package.nix.
# This keeps `packages.<system>` in sync with the directory listing; new apps
# only need a new directory here, never a flake.nix edit.
{ lib, projectRoot }:
final: _prev:
lib.packagesFromDirectoryRecursive {
  inherit (final) callPackage;

  directory = projectRoot + /packages/apps;
}
