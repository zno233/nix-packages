{
  fetchurl,
  lib,
  nerd-font-patcher,
  parallel,
  p7zip,
  stdenvNoCC,
}:

import ../fontPackage.nix {
  inherit
    lib
    nerd-font-patcher
    parallel
    p7zip
    stdenvNoCC
    ;

  name = "sf-mono";
  pkgName = "SF Mono Fonts.pkg";
  nerd = false;

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg";
    hash = "sha256-bUoLeOOqzQb5E/ZCzq0cfbSvNO1IhW1xcaLgtV2aeUU=";
  };
}
