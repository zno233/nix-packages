# Local application packages, discovered from packages/apps/<name>/package.nix.
# This keeps `packages.<system>` in sync with the directory listing; new apps
# only need a new directory here, never a flake.nix edit.
#
# The file exports:
#
#   reexports : variant re-export plan — the one place where variant names live
#   discover  : { callPackage } -> flat app set with collision checks (used by
#               flake.nix, which also re-checks `reexports` against it)
#   overlay   : (final: prev: ...) adding that flat set to pkgs
#
# A directory may also publish release variants of one upstream: its
# package.nix returns an attrset of derivations (see packages/apps/honk/),
# and those attributes are re-exported flat from this set, nixpkgs
# all-packages.nix style ("brave = (callPackage …).brave").
#
# The overlay result must be a lazily merged set with STATIC keys: nixpkgs
# re-applies overlays for every stdenv boot stage, and anything that forces a
# package WHNF while the overlay result is constructed recurses. That rules
# out folding variant names dynamically here — hence the static `reexports`
# table; flake.nix re-checks it against the dynamic flatten, so a stale entry
# fails evaluation instead of drifting silently.
{ lib, projectRoot }:
let
  directory = projectRoot + /packages/apps;

  # Variant re-export plan: family directory name -> the variant attributes
  # of its package.nix lifted into the plain set. Names must not collide with
  # any directory name or sibling variant (asserted statically here, and
  # dynamically — including collisions with sibling derivations — below).
  reexports = {
    honk = [
      "honk"
      "honk-stock"
    ];
  };

  liftedNames = lib.concatLists (lib.attrValues reexports);

  dirNames = builtins.attrNames (builtins.readDir directory);

  flat =
    callPackage:
    let
      apps = lib.packagesFromDirectoryRecursive {
        inherit callPackage;
        inherit directory;
      };

      lifted = builtins.listToAttrs (
        lib.concatMap (
          family: map (name: lib.nameValuePair name apps.${family}.${name}) reexports.${family}
        ) (lib.attrNames reexports)
      );
    in
    apps // lifted;
in
assert lib.assertMsg (lib.allUnique liftedNames)
  "overlays.apps: duplicate variant name in reexports table";

# A lifted name equal to its own family's directory name is the intended
# shape (`honk` replaces the family attrset); colliding with any OTHER
# directory name is a shadow.
assert lib.assertMsg (
  lib.intersectLists (lib.subtractLists (lib.attrNames reexports) dirNames) liftedNames == [ ]
) "overlays.apps: a lifted variant name collides with an app directory name";
{
  inherit reexports;

  /**
    Flat app set: directory packages plus the lifted re-export names.

    Collisions among the merged names throw (the plain part stays lazy; the
    check runs on access).
  */
  discover =
    { callPackage }:
    let
      set = flat callPackage;
    in
    assert lib.assertMsg (lib.allUnique (lib.attrNames set)) "overlays.apps: duplicate app name";
    set;

  # Static-key re-exports keep the overlay result lazy (see file header).
  overlay = final: _prev: flat final.callPackage;
}
