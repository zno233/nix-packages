{
  description = "zno's Nix packages, font collections, and NixOS modules";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      overlayLib = import ./lib { inherit lib; };

      # The overlays directory exports a manifest named like the flake
      # outputs: the composed overlay plus a list of the aggregate names
      # the fonts overlay registers.
      overlayManifest = import ./overlays {
        inherit lib overlayLib;
        projectRoot = ./.;
      };

      overlays.default = overlayManifest.overlays.default;

      # One nixpkgs instantiation per system, shared by every flake output.
      pkgsFor = lib.genAttrs systems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlays.default ];
        }
      );

      # Local applications are discovered from packages/apps/<name>/package.nix.
      # A directory may publish release variants by returning an attrset of
      # derivations (see packages/apps/honk/); those are re-exported flat —
      # keep the explicit re-exports in sync with overlays/apps.nix. The
      # union stays lazy: no derivation may be forced while building this
      # set (nixpkgs re-applies overlays for every stdenv boot stage).
      appPackages = lib.mapAttrs (
        _: pkgs:
        let
          apps = lib.packagesFromDirectoryRecursive {
            inherit (pkgs) callPackage;
            directory = ./packages/apps;
          };
        in
        apps
        // {
          honk = apps.honk.honk;
          honk-stock = apps.honk.honk-stock;
        }
      ) pkgsFor;

      # Font aggregates register themselves in overlays/fonts/aggregates.nix,
      # which exports both their derivations and a static name manifest.
      # `lib.getAttrs` fails loudly if the manifest and the overlaid package
      # set ever drift apart, so no nixpkgs name diffing is needed here.
      # Vendor packages promoted to the plain set are listed in the same
      # manifest (flattenNames) and merged in the same way.
      fontPackages = lib.mapAttrs (
        _: pkgs: lib.getAttrs (overlayManifest.aggregateNames ++ overlayManifest.flattenNames) pkgs
      ) pkgsFor;

      # modules/ is partitioned by flake output key (nixosModules today,
      # e.g. homeManagerModules later) for symmetric growth.
      honkModule = ./modules/nixosModules/honk.nix;
    in
    {
      inherit overlays;

      # Re-export the helper library so downstream flakes can use the same
      # derivation utilities and license metadata.
      lib = overlayLib;

      nixosModules = {
        honk = honkModule;

        # Collection-style default: it contains every module of this flake
        # today (just honk) and can grow without misleading consumers.
        default = {
          imports = [ honkModule ];
        };
      };

      # Expose the full overlaid package set for consumers that prefer
      # `legacyPackages` over applying the overlay themselves.
      legacyPackages = pkgsFor;

      packages = lib.mapAttrs (system: _: appPackages.${system} // fontPackages.${system}) pkgsFor;

      # Build the local applications (these are what `nix flake check`
      # builds). Font aggregates are excluded on purpose: building one
      # requires building its whole vendor font tree, so they are validated
      # by the font sync workflow and by the aggregate manifest above.
      checks = lib.mapAttrs (system: _: appPackages.${system}) pkgsFor;

      formatter = lib.mapAttrs (_: pkgs: pkgs.nixfmt-tree) pkgsFor;

      devShells = lib.mapAttrs (_: pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            deadnix
            nixfmt
            statix
          ];
        };
      }) pkgsFor;
    };
}
