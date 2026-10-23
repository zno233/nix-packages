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

  name = "sf-armenian-nerd";
  pkgName = "SF Armenian Fonts.pkg";
  nerd = true;

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Armenian.dmg";
    hash = "sha256-/9cVrpPXwhW+P0NLhGJBhHebtQsrs9Zrj9QogMZfra0=";
  };
}
