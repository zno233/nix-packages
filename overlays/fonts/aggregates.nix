# Aggregate font derivations built from the vendor scopes.
#
# The return value is a manifest:
#
#   packages : AttrSet name -> Derivation, used by the fonts overlay
#   names    : [ String ], static list of the aggregate names
#
# `names` is consumed by flake.nix to pick the aggregates out of the
# overlaid package set. It is evaluated on its own (with `scopes = null`),
# so it must remain derivable without forcing any scope value.
{
  lib,
  scopes,
}:
let
  inherit (lib) elem;

  windowsEditions = import ./windows-fonts-editions.nix;

  inherit (lib.licenses)
    foundertype-commercial-license
    foundertype-family-license
    tsangertype-font-license
    tsangertype-freefont-license
    ;

  inherit (scopes)
    alibabaPackages
    alimamaPackages
    applePackages
    buttaiwanPackages
    dingtalkPackages
    foundertypePackages
    hanwangPackages
    huaweiPackages
    justfontPackages
    microsoftPackages
    taobaoPackages
    tianhengPackages
    trionestypePackages
    tsangertypePackages
    xiaomiPackages
    znoPackages
    ;

  all = _: true;

  foundertypeCtexPackages = with foundertypePackages; [
    fzfangsong
    fzheiti
    fzkaiti
    fzlishu
    fzshusong
    fzxiaobiaosong
    fzxiheiyi
    fzxiyuan
    fzzhunyuan
  ];

  foundertypePaidPackages = with foundertypePackages; [
    fzcuyuan
    fzlishu
    fzxiaobiaosong
    fzxiheiyi
    fzxiyuan
    fzzhunyuan
  ];

  harmonyosSansPackages = with huaweiPackages; [
    harmonyos-sans
    harmonyos-sans-sc
    harmonyos-sans-tc
    harmonyos-sans-naskh-arabic
    harmonyos-sans-naskh-arabic-ui
  ];

  harmonyosSansVfPackages = with huaweiPackages; [
    harmonyos-sans-vf
    harmonyos-sans-sc-vf
    harmonyos-sans-tc-vf
    harmonyos-sans-naskh-arabic-vf
    harmonyos-sans-naskh-arabic-ui-vf
  ];

  # Windows edition split; the name lists (with their rationale) live in
  # overlays/fonts/windows-fonts-editions.nix and are shared with the scope-level
  # path. Looking each name up in `microsoftPackages` also fails loudly if
  # the manifest and the tree ever drift apart.
  windowsEnUsExcluded = map (n: microsoftPackages.${n}) windowsEditions.enUsExcluded;

  licenseIn = licenses: drv: elem (drv.meta.license or null) licenses;

  mkAggregate =
    name: scope: predicate:
    scope.combine' name predicate;

  # Aggregates that contain every derivation in their vendor scope.
  allOfScope = {
    alibaba-fonts = alibabaPackages;
    alimama-fonts = alimamaPackages;
    apple-fonts = applePackages;
    buttaiwan-fonts = buttaiwanPackages;
    dingtalk-fonts = dingtalkPackages;
    foundertype-fonts = foundertypePackages;
    hanwang-fonts = hanwangPackages;
    huawei-fonts = huaweiPackages;
    justfont-fonts = justfontPackages;
    taobao-fonts = taobaoPackages;
    tianheng-fonts = tianhengPackages;
    trionestype-fonts = trionestypePackages;
    tsangertype-fonts = tsangertypePackages;
    windows-fonts = microsoftPackages;
    xiaomi-fonts = xiaomiPackages;
    zno-fonts = znoPackages;
  };

  # Aggregates that select a subset of their vendor scope.
  filteredOfScope = [
    {
      name = "foundertype-ctex-fonts";
      scope = foundertypePackages;
      predicate = drv: elem drv foundertypeCtexPackages;
    }
    {
      name = "foundertype-gcu-fonts";
      scope = foundertypePackages;
      predicate =
        drv: licenseIn [ foundertype-commercial-license ] drv && !(elem drv foundertypePaidPackages);
    }
    {
      name = "foundertype-gpu-fonts";
      scope = foundertypePackages;
      predicate =
        drv:
        licenseIn [
          foundertype-commercial-license
          foundertype-family-license
        ] drv
        && !(elem drv foundertypePaidPackages);
    }
    {
      name = "foundertype-paid-fonts";
      scope = foundertypePackages;
      predicate = drv: elem drv foundertypePaidPackages;
    }
    {
      name = "harmonyos-sans-fonts";
      scope = huaweiPackages;
      predicate = drv: elem drv harmonyosSansPackages;
    }
    {
      name = "harmonyos-sans-vf-fonts";
      scope = huaweiPackages;
      predicate = drv: elem drv harmonyosSansVfPackages;
    }
    {
      name = "windows-fonts-en-us";
      scope = microsoftPackages;
      predicate = drv: !(elem drv windowsEnUsExcluded);
    }
    {
      name = "windows-fonts-zh-cn";
      scope = microsoftPackages;
      predicate = all;
    }
    {
      name = "windows-fonts-en-us-slim";
      scope = microsoftPackages;
      predicate = drv: elem drv (map (n: microsoftPackages.${n}) windowsEditions.slimCore);
    }
    {
      name = "windows-fonts-zh-cn-slim";
      scope = microsoftPackages;
      predicate = drv: elem drv (map (n: microsoftPackages.${n}) windowsEditions.slimZhCn);
    }
    {
      name = "tsangertype-gcu-fonts";
      scope = tsangertypePackages;
      predicate = drv: licenseIn [ tsangertype-freefont-license ] drv;
    }
    {
      name = "tsangertype-gpu-fonts";
      scope = tsangertypePackages;
      predicate =
        drv:
        licenseIn [
          tsangertype-freefont-license
          tsangertype-font-license
        ] drv;
    }
  ];

  packages =
    lib.mapAttrs (name: scope: mkAggregate name scope all) allOfScope
    // lib.listToAttrs (
      lib.map (
        {
          name,
          scope,
          predicate,
        }:
        lib.nameValuePair name (mkAggregate name scope predicate)
      ) filteredOfScope
    );

  # Static manifest: only the attrset keys and the record names are forced
  # here, so this line is safe to evaluate with a stubbed `scopes`.
  names = lib.attrNames allOfScope ++ lib.catAttrs "name" filteredOfScope;

  # Packages promoted out of their vendor scope to the plain package set,
  # for scopes where a single package makes the scope layer pointless
  # (`pkg.pkgs.asuka-fonts` installs like every other package). The paths
  # are resolved against the scopes when the overlay runs; a static name
  # list is all the manifest needs to stay stub-evaluable.
  flatPaths = {
    asuka-fonts = [
      "znoPackages"
      "asuka-fonts"
    ];
  };

  flattenNames = lib.attrNames flatPaths;
in
{
  inherit
    packages
    names
    flatPaths
    flattenNames
    ;
}
