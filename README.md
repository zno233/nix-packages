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
  bundle per vendor on top; scopes where a single font carries the vendor
  are promoted as plain `pkgs.<font>` attributes. Windows editions are
  additionally curated as `windows-fonts-zh-cn` (complete set, as shipped by
  a zh-CN install) and `windows-fonts-en-us` (everything but the zh-CN-only
  SimHei/KaiTi/FangSong trio and DengXian an en-US image does not bundle).
  Both have `-slim` variants carrying the Office core/theme and classic
  document faces plus Segoe UI's UI/emoji variants (exotic-script fonts such
  as Tibetan, Mongolian, Yi, Tai, PhagsPa, Myanmar, Javanese, Indian and
  other rare scripts are only in the full aggregates); the zh-CN slim set
  additionally carries 宋体/黑体/楷体/仿宋/微软雅黑/等线 — the Traditional
  Chinese, Japanese, and Korean faces are kept out of it on purpose, they
  account for most of the size and are not needed for zh-CN documents.
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
`tools/gen-ms-sources/sources.nix`, which is generated from the
[uinv/windows-fonts](https://github.com/uinv/windows-fonts) `windows11`
snapshot: package `files` lists must match its exact-case file names, and
`gen.sh` regenerates `sources.nix` from the current branch tip (or a
pinned commit via `GEN_MS_SOURCES_PIN`) after verifying that coverage.

## CI

- `check.yml`: `nix flake check` on push / PR
- `update.yml`: daily flake.lock bump and package updates (apps via nix-update;
  pins without a releasable version follow `tools/update-pins.toml` recipes),
  pushed only after a passing check
- `sync-fonts.yml`: daily font-tree sync from upstream mirrors, local trees
  excluded, pushed only after a passing check

## Development

`nix fmt` (nixfmt) and `nix flake check` are the base loop; `nix develop`
provides `nixfmt`, `statix`, and `deadnix`.
