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
#   flattenNames   : [ String ], static list of vendor packages promoted to
#                    the plain package set
#
{
  lib,
  overlayLib,
  projectRoot,
}:
let
  # `aggregateNames`/`flattenNames` are a static manifest (see
  # overlays/fonts/aggregates.nix): evaluating it must not force any scope
  # value, so the manifest-only import runs with `scopes = null`.
  manifest = import ./fonts/aggregates.nix {
    inherit
      lib
      projectRoot
      ;
    scopes = null;
  };
in
{
  inherit (manifest) flattenNames;
  aggregateNames = manifest.names;

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
        inherit
          lib
          projectRoot
          scopes
          ;
      };

      # Vendor packages promoted past their scope, addressed as `pkgs.<name>`.
      flat = lib.mapAttrs (_name: path: lib.getAttrFromPath path scopes) aggregates.flatPaths;

      compat = import ./fonts/compat.nix { inherit lib; };
    in
    scopes // aggregates.packages // flat // compat // { inherit lib; };
}
