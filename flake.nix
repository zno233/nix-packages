{
  description = "zno's Nix packages, font collections, and NixOS modules";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      # x86_64-darwin is gone: nixpkgs 26.11 dropped support there (every
      # package evaluation throws), so exposing it would only publish a
      # flake output whose packages fail to evaluate.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      overlayLib = import ./lib { inherit lib; };

      # The overlays directory exports a manifest named like the flake
      # outputs: the composed overlay, the fonts aggregate names, and the
      # app discovery helper shared with the overlay itself.
      overlayManifest = import ./overlays {
        inherit lib overlayLib;
        projectRoot = ./.;
      };

      appsManifest = import ./overlays/apps.nix {
        inherit lib;
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

      # Local applications are discovered by the logic shared with the
      # overlay (overlays/apps.nix): the same flatten, including the honk
      # variant re-exports; new apps still need no flake.nix edit.
      # The union stays lazy: no derivation may be forced while building
      # this set (nixpkgs re-applies overlays for every stdenv boot stage).
      appPackages = lib.mapAttrs (_: pkgs: appsManifest.discover { inherit (pkgs) callPackage; }) pkgsFor;

      # Font aggregates register themselves in overlays/fonts/aggregates.nix,
      # which exports both their derivations and a static name manifest.
      # `lib.getAttrs` fails loudly if the manifest and the overlaid package
      # set ever drift apart, so no nixpkgs name diffing is needed here.
      # Vendor packages promoted to the plain set are listed in the same
      # manifest (flattenNames) and merged in the same way.
      fontNames = overlayManifest.aggregateNames ++ overlayManifest.flattenNames;

      fontPackages = lib.mapAttrs (_: pkgs: lib.getAttrs fontNames pkgs) pkgsFor;

      # Prebuilt apps are published for a subset of systems and throw when
      # forced elsewhere; the filter must be throw-tolerant so that a
      # darwin evaluation of `packages`/`checks` stays evaluation-only.
      filterSupported =
        pkgs:
        lib.filterAttrs (
          _: drv: (lib.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform drv)).value or false
        );

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

      # Evaluation-only smoke test: `nix flake check` evaluates every
      # nixosConfiguration's toplevel without building it, so module edits
      # breaking eval surface in CI. Only bootstrapped once; extend the
      # module list here if more modules appear.
      nixosConfigurations = lib.genAttrs [ "x86_64-linux" ] (
        system:
        lib.nixosSystem {
          inherit system;
          pkgs = pkgsFor.${system};
          modules = [
            honkModule
            {
              services.honk-core.enable = true;
              # Minimal honest payload: the module asserts exactly one of
              # `config`/`configFile` is set.
              services.honk-core.config = "";
            }
            # Skeleton to pass the stock NixOS assertions without implying a
            # real machine — this configuration is eval-only, never built.
            {
              fileSystems."/" = {
                device = "nodev";
                fsType = "tmpfs";
              };
              boot.loader.grub.enable = false;
            }
          ];
        }
      );

      # Expose the full overlaid package set for consumers that prefer
      # `legacyPackages` over applying the overlay themselves.
      legacyPackages = pkgsFor;

      packages = lib.mapAttrs (
        system: pkgs:
        # An app name (or honk-style variant name) colliding with a font
        # name would be silently resolved to the font by the merge below —
        # fail the evaluation instead. Both name sources are cheap to
        # enumerate (directory names and static manifests).
        assert lib.assertMsg (
          lib.intersectLists (lib.attrNames appPackages.x86_64-linux) fontNames == [ ]
        ) "flake.nix: an app name collides with a font aggregate or promoted vendor package";
        filterSupported pkgs (appPackages.${system} // fontPackages.${system})
      ) pkgsFor;

      # Build the local applications (these are what `nix flake check`
      # builds). Font aggregates are excluded on purpose: building one
      # requires building its whole vendor font tree, so they are validated
      # by the font sync workflow and by the aggregate manifest above.
      checks = lib.mapAttrs (system: pkgs: filterSupported pkgs appPackages.${system}) pkgsFor;

      formatter = lib.mapAttrs (_: pkgs: pkgs.nixfmt-tree) pkgsFor;

      # Tools the workflows drive; app refs pin them to this flake's
      # locked nixpkgs instead of the mutable registry.
      apps = lib.mapAttrs (_: pkgs: {
        nix-update = {
          type = "app";
          program = "${pkgs.nix-update}/bin/nix-update";
        };
        shellcheck = {
          type = "app";
          program = "${pkgs.shellcheck}/bin/shellcheck";
        };
        statix = {
          type = "app";
          program = "${pkgs.statix}/bin/statix";
        };
        deadnix = {
          type = "app";
          program = "${pkgs.deadnix}/bin/deadnix";
        };
      }) pkgsFor;

      devShells = lib.mapAttrs (_: pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            deadnix
            nix-update
            nixfmt-tree
            python3
            shellcheck
            statix
          ];
        };
      }) pkgsFor;
    };
}
