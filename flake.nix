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

      projectRoot = ./.;

      overlayLib = import ./lib { inherit lib; };

      # The overlays and modules directories export manifests named like the
      # flake outputs: the composed overlay, the fonts aggregate names, the
      # app discovery helper shared with the overlay itself, and the module
      # partitions.
      overlayManifest = import ./overlays {
        inherit lib overlayLib projectRoot;
      };

      appsManifest = import ./overlays/apps.nix {
        inherit lib projectRoot;
      };

      moduleManifest = import ./modules { inherit projectRoot; };

      overlays = {
        default = overlayManifest.overlays.default;
      };

      # One nixpkgs instantiation per system, shared by every flake output.
      pkgsFor = lib.genAttrs systems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ overlays.default ];
        }
      );

      # Every per-system output below is built through this, so the system
      # set stays defined in one place.
      eachSystem = f: lib.mapAttrs (system: pkgs: f system pkgs) pkgsFor;

      # Local applications are discovered by the logic shared with the
      # overlay (overlays/apps.nix): the same flatten, including the honk
      # variant re-exports; new apps still need no flake.nix edit.
      # The union stays lazy: no derivation may be forced while building
      # this set (nixpkgs re-applies overlays for every stdenv boot stage).
      appPackages = eachSystem (_: pkgs: appsManifest.discover { inherit (pkgs) callPackage; });

      # Font aggregates register themselves in overlays/fonts/aggregates.nix,
      # which exports both their derivations and a static name manifest.
      # `lib.getAttrs` fails loudly if the manifest and the overlaid package
      # set ever drift apart, so no nixpkgs name diffing is needed here.
      # Vendor packages promoted to the plain set are listed in the same
      # manifest (flattenNames) and merged in the same way.
      fontNames = overlayManifest.aggregateNames ++ overlayManifest.flattenNames;

      fontPackages = eachSystem (_: pkgs: lib.getAttrs fontNames pkgs);

      # Prebuilt apps are published for a subset of systems and throw when
      # forced elsewhere; the filter must be throw-tolerant so that a
      # darwin evaluation of `packages`/`checks` stays evaluation-only.
      filterSupported =
        pkgs:
        lib.filterAttrs (
          _: drv: (lib.tryEval (lib.meta.availableOn pkgs.stdenv.hostPlatform drv)).value or false
        );

      nixosModuleFiles = moduleManifest.nixosModules;
    in
    {
      inherit overlays;

      # Re-export the helper library so downstream flakes can use the same
      # derivation utilities and license metadata.
      lib = overlayLib;

      nixosModules = nixosModuleFiles // {
        # Collection-style default: it contains every module of this flake
        # today (honk and windinput) and can grow without misleading
        # consumers.  Both modules are opt-in through
        # services.honk-core.enable / programs.windinput.enable.
        default.imports = builtins.attrValues nixosModuleFiles;
      };

      # Evaluation-only smoke test: `nix flake check` evaluates every
      # nixosConfiguration's toplevel without building it, so module edits
      # breaking eval surface in CI.
      nixosConfigurations = lib.genAttrs [ "x86_64-linux" ] (
        system:
        lib.nixosSystem {
          inherit system;
          pkgs = pkgsFor.${system};
          modules = builtins.attrValues nixosModuleFiles ++ [
            {
              services.honk-core.enable = true;
              # Minimal honest payload: the module asserts exactly one of
              # `config`/`configFile` is set.
              services.honk-core.config = "";

              # windinput pulls the addon into the fcitx5 wrapper and sets the
              # launcher environment variables; eval-only here.
              programs.windinput.enable = true;
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

      packages = eachSystem (
        system: pkgs:
        # An app name (or honk-style variant name) colliding with a font
        # name would be silently resolved to the font by the merge below —
        # fail the evaluation instead. Both name sources are cheap to
        # enumerate (directory names and static manifests).
        assert lib.assertMsg (
          lib.intersectLists (lib.attrNames appPackages.${system}) fontNames == [ ]
        ) "flake.nix: an app name collides with a font aggregate or promoted vendor package";
        filterSupported pkgs (appPackages.${system} // fontPackages.${system})
      );

      # Build the local applications (these are what `nix flake check`
      # builds). Font aggregates are excluded on purpose: building one
      # requires building its whole vendor font tree, so they are validated
      # by the font sync workflow and by the aggregate manifest above.
      checks = eachSystem (system: pkgs: filterSupported pkgs appPackages.${system});

      formatter = eachSystem (_: pkgs: pkgs.nixfmt-tree);

      # Tools the workflows drive; app refs pin them to this flake's
      # locked nixpkgs instead of the mutable registry.
      apps = eachSystem (
        system: pkgs: {
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
        }
      );

      devShells = eachSystem (
        system: pkgs: {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                deadnix
                nix-update
                nixfmt-tree
                python3
                shellcheck
                statix
              ];
          };
        }
      );
    };
}
