# Manifest for the default overlay of this flake, mirroring the flake output
# naming for direct consumption by flake.nix:
#
#   overlays.default : the composed font + apps overlay (final: prev: ...)
#   aggregateNames   : static list of the aggregate names added by the fonts
#                      overlay, consumed by flake.nix
#
# The overlay itself glues the vendored font scopes/aggregates together with
# the locally maintained application packages.
{
  lib,
  overlayLib,
  projectRoot,
}:
let
  fonts = import ./fonts.nix {
    inherit lib overlayLib projectRoot;
  };
in
{
  overlays.default = lib.composeManyExtensions [
    fonts.overlay
    (import ./apps.nix { inherit lib projectRoot; })
  ];

  inherit (fonts) aggregateNames;
}
