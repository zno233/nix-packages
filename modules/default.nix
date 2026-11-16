# Manifest for modules/, partitioned by flake output key (nixosModules today,
# e.g. homeManagerModules later), mirroring overlays/default.nix: flake.nix
# only assembles the outputs, and each partition stays next to its files.
{ projectRoot }:
let
  nixosModules = projectRoot + /modules/nixosModules;
in
{
  nixosModules = {
    honk = nixosModules + /honk.nix;
    windinput = nixosModules + /windinput.nix;
  };
}
