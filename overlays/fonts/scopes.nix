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

  # Windows edition splits shared with the top-level aggregates
  # (overlays/fonts/aggregates.nix); the rationale for each list lives in
  # the manifest itself.
  windowsEditions = import ./windows-fonts-editions.nix;

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

      # Edition splits as derivations. Resolving the manifest names against
      # packageScope fails loudly if the manifest and the tree drift apart.
      windowsEnUsExcluded = map (n: packageScope.${n}) windowsEditions.enUsExcluded;
      windowsSlimCore = map (n: packageScope.${n}) windowsEditions.slimCore;
      windowsSlimZhCn = map (n: packageScope.${n}) windowsEditions.slimZhCn;
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
      # plus DengXian), while the slim editions keep only the faces Word's
      # default templates and common documents reference.
      windows-fonts-zh-cn = link fontPackages "windows-fonts-zh-cn" (_: true);
      windows-fonts-en-us = link fontPackages "windows-fonts-en-us" (
        drv: !(elem drv windowsEnUsExcluded)
      );
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
