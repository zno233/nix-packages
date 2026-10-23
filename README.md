# nix-packages

A repo to store personal nix packages.

## Usage

```nix
{
  inputs.nix-packages.url = "github:zno233/nix-packages";

  outputs = { nixpkgs, nix-packages, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nix-packages.nixosModules.honk
        { nixpkgs.overlays = [ nix-packages.overlays.default ]; }
      ];
    };
  };
}
```

- The overlay adds all packages as plain attributes to the host's `pkgs`.
  Without applying it, reference `packages.<system>.<name>` directly;
  `legacyPackages` exposes the whole prepared `pkgs` set.
- Applications are auto-discovered from `packages/apps/<name>/package.nix` —
  adding one is just a new directory.
- Fonts live in `packages/fonts/<vendor>/<font>/package.nix` under a
  per-vendor `<vendor>Packages` scope, with one `<vendor>-fonts` aggregate
  bundle per vendor on top.
- `nixosModules.honk` configures the honk proxy engine service;
  `nixosModules.default` imports every module provided by this flake.

## Licensing

Most Chinese-language fonts are restrictive (`redistributable = false`,
personal/non-commercial use only) and the microsoft fonts are unfree — check
a package's `meta.license` before binary caching or redistributing beyond
personal machines.

## Font updates

13 of the 16 vendor trees mirror
[brsvh/chinese-fonts-overlay](https://github.com/brsvh/chinese-fonts-overlay),
refreshed daily by `sync-fonts.yml`; `apple/`, `microsoft/`, and `zno/` are
maintained here. The microsoft tree is built from
`tools/gen-ms-sources/sources.nix` — regenerate it with `gen.sh` when
upstream changes.

## CI

- `check.yml`: `nix flake check` on push / PR
- `update.yml`: daily flake.lock bump and package updates (apps via nix-update,
  honk via `tools/update-honk`, apple-fonts dmg pins via `tools/update-apple-fonts`),
  pushed only after a passing check
- `sync-fonts.yml`: daily font-tree sync from upstream mirrors, local trees
  excluded, pushed only after a passing check

## Development

`nix fmt` (nixfmt) and `nix flake check` are the base loop; `nix develop`
provides `nixfmt`, `statix`, and `deadnix`.
