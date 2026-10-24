# Vendor package scopes for the vendored font trees.
#
# Every scope exposes its packages plus two combinators:
#
#   combine  :: (Derivation -> Bool) -> Derivation
#   combine' :: String -> (Derivation -> Bool) -> Derivation
#
# `combine` uses the vendor's canonical aggregate name; `combine'` lets the
# aggregate layer choose a name for filtered subsets.
{
  lib,
  final,
  projectRoot,
  link,
}:
let
  inherit (lib)
    elem
    makeScope
    mapAttrs'
    nameValuePair
    packagesFromDirectoryRecursive
    removeAttrs
    ;

  mkFontScope =
    {
      aggregateName,
      directory,
      remove ? [ ],
    }:
    let
      packages = removeAttrs (packagesFromDirectoryRecursive {
        inherit (final)
          callPackage
          newScope
          ;

        inherit directory;
      }) remove;
    in
    packages
    // {
      combine = link packages aggregateName;
      combine' = link packages;
    };

  # Every vendor directory maps to `<vendor>Packages`; only the apple scope
  # needs to hide its helper derivation.
  vendors = {
    alibaba = { };
    alimama = { };
    apple = {
      remove = [ "fontPackage" ];
    };
    buttaiwan = { };
    dingtalk = { };
    foundertype = { };
    hanwang = { };
    huawei = { };
    justfont = { };
    taobao = { };
    tianheng = { };
    trionestype = { };
    tsangertype = { };
    xiaomi = { };
    zno = { };
  };

  mkVendorScope =
    vendor: attrs:
    mkFontScope (
      {
        aggregateName = "${vendor}-fonts";
        directory = projectRoot + /packages/fonts/${vendor};
      }
      // attrs
    );

  microsoftPackages =
    let
      packageScope = makeScope final.newScope (
        self:
        let
          packages = packagesFromDirectoryRecursive {
            inherit (self)
              callPackage
              newScope
              ;

            directory = projectRoot + /packages/fonts/microsoft;
          };
        in
        packages
        // {
          mkMicrosoftFontDerivation = self.callPackage (projectRoot + /packages/fonts/microsoft/builder.nix) {
            sources = import (projectRoot + /tools/gen-ms-sources/sources.nix);
          };
        }
      );

      fontPackages = removeAttrs packageScope [
        "builder"
        "mkMicrosoftFontDerivation"
        "windows-fonts"
      ];

      # Keep in sync with the slim lists in overlays/fonts/aggregates.nix.
      windowsSlimCore = with packageScope; [
        arial
        bahnschrift
        calibri
        cambria
        cambria-math
        candara
        comic-sans-ms
        consolas
        constantia
        corbel
        courier-new
        franklin-gothic-medium
        gabriola
        georgia
        impact
        ink-free
        lucida-console
        lucida-sans-unicode
        marlett
        microsoft-sans-serif
        palatino-linotype
        segoe-icons
        segoe-print
        segoe-script
        segoe-ui
        segoe-ui-symbols
        segoe-ui-variable
        sitka
        sylfaen
        symbol
        tahoma
        times-new-roman
        trebuchet-ms
        verdana
        webdings
        wingdings
      ];

      windowsSlimZhCn =
        windowsSlimCore
        ++ (with packageScope; [
          dengxian
          fangsong
          kaiti
          microsoft-yahei
          simhei
          simsun
        ]);
    in
    removeAttrs packageScope [
      "builder"
      "mkMicrosoftFontDerivation"
    ]
    // {
      combine = link fontPackages "windows-fonts";
      combine' = link fontPackages;

      # Edition aggregates, addressable as microsoftPackages.<name> as well
      # as the top-level registration in overlays/fonts/aggregates.nix.
      # Same split semantics: en-US packs none of the zh-CN-only set
      # (SimHei, KaiTi, and FangSong which are Windows 7-era legacy fonts,
      # plus DengXian).
      windows-fonts-zh-cn = link fontPackages "windows-fonts-zh-cn" (_: true);
      windows-fonts-en-us = link fontPackages "windows-fonts-en-us" (
        drv:
        !(elem drv [
          packageScope.dengxian
          packageScope.kaiti
          packageScope.fangsong
          packageScope.simhei
        ])
      );

      # Slim editions: only the fonts Word's default templates and common
      # documents reference (see overlays/fonts/aggregates.nix for the same
      # lists on the top-level registration path).
      windows-fonts-en-us-slim = link fontPackages "windows-fonts-en-us-slim" (
        drv: elem drv windowsSlimCore
      );
      windows-fonts-zh-cn-slim = link fontPackages "windows-fonts-zh-cn-slim" (
        drv: elem drv windowsSlimZhCn
      );
    };
in
mapAttrs' (vendor: attrs: nameValuePair "${vendor}Packages" (mkVendorScope vendor attrs)) vendors
// {
  inherit microsoftPackages;
}
