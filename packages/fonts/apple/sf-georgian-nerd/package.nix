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

  name = "sf-georgian-nerd";
  pkgName = "SF Georgian Fonts.pkg";
  nerd = true;

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Georgian.dmg";
    hash = "sha256-wWsXmEcrJiMkRTMepRrIKZJgZ0/o+386NU7t61OQotI=";
  };
}
