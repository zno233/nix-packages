# Font scopes and aggregates, derived from brsvh/chinese-fonts-overlay.
#
# The package trees under packages/fonts/ are vendored from
# brsvh/chinese-fonts-overlay and refreshed by sync-fonts.yml, except
# apple/, zno/, and microsoft/, which are maintained locally. This file and
# the files in overlays/fonts/
# contain only the overlay glue: vendor scopes, aggregate derivations, and
# throwing aliases for renamed attributes.
#
# This file exports a manifest instead of a bare overlay:
#
#   overlay   : the fonts overlay (final: prev: ...)
#   aggregateNames : [ String ], static list of aggregate names
#
{
  lib,
  overlayLib,
  projectRoot,
}:
let
  # `aggregateNames` is a static manifest (see overlays/fonts/aggregates.nix):
  # evaluating it must not force any scope value, so the manifest-only import
  # runs with `scopes = null`.
  aggregateNames =
    (import ./fonts/aggregates.nix {
      inherit lib;
      scopes = null;
    }).names;
in
{
  inherit aggregateNames;

  overlay =
    final: prev:
    let
      inherit (overlayLib) filterDerivations;

      lib = prev.lib.extend (
        _final: prevAttrs: {
          licenses = prevAttrs.licenses // overlayLib.licenses;
        }
      );

      link =
        scope: pname: condition:
        let
          members = filterDerivations condition scope;
        in
        final.stdenvNoCC.mkDerivation {
          inherit pname;

          version = "0";

          dontUnpack = true;

          installPhase = ''
            runHook preInstall

            mkdir -p $out

            for drv in ${lib.concatStringsSep " " members}; do
              ${final.lndir}/bin/lndir -silent "$drv" "$out"
            done

            runHook postInstall
          '';

          meta = {
            description = "${pname}: aggregate of ${toString (lib.length members)} font packages";
            license = lib.lists.unique (
              lib.lists.flatten (map (drv: lib.toList (drv.meta.license or [ ])) members)
            );
          };
        };

      scopes = import ./fonts/scopes.nix {
        inherit
          final
          lib
          link
          projectRoot
          ;
      };

      aggregates = import ./fonts/aggregates.nix {
        inherit lib scopes;
      };

      compat = import ./fonts/compat.nix { inherit lib; };
    in
    scopes // aggregates.packages // compat // { inherit lib; };
}
