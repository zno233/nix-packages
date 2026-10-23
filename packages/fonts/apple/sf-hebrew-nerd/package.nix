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

  name = "sf-hebrew-nerd";
  pkgName = "SF Hebrew Fonts.pkg";
  nerd = true;

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Hebrew.dmg";
    hash = "sha256-MljkBxW4vPRelEHbv3IYruqlcAZdzB97+lXJ7W0Lk4Q=";
  };
}
