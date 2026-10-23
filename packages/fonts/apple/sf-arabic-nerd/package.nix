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

  name = "sf-arabic-nerd";
  pkgName = "SF Arabic Fonts.pkg";
  nerd = true;

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Arabic.dmg";
    hash = "sha256-J2DGLVArdwEsSVF8LqOS7C1MZH/gYJhckn30jRBRl7k=";
  };
}
