# Vendor naming derived from the packages/fonts tree itself.
#
# Every directory under packages/fonts is a vendor: it gets a
# `<vendor>Packages` scope (overlays/fonts/scopes.nix), a
# `<vendor>-fonts` aggregate (overlays/fonts/aggregates.nix), and a flake
# output through the aggregate name manifest — with no overlay edit, so a
# new upstream-vendored font family only takes a sync to go live.
#
# microsoft/ is the one exception: its packages are generated locally
# (tools/gen-ms-sources) through a shared builder and carry the
# windows-fonts edition aggregates instead, so it keeps a dedicated
# makeScope block and is excluded from the derived lists.
{
  lib,
  projectRoot,
}:
let
  vendors = builtins.removeAttrs (lib.filterAttrs (_: type: type == "directory") (
    builtins.readDir (projectRoot + /packages/fonts)
  )) [ "microsoft" ];
in
{
  names = builtins.attrNames vendors;

  scopeName = vendor: "${vendor}Packages";

  aggregateName = vendor: "${vendor}-fonts";
}
