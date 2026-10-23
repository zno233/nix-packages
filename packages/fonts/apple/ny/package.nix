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

  name = "ny";
  pkgName = "NY Fonts.pkg";
  nerd = false;

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/NY.dmg";
    hash = "sha256-HC7ttFJswPMm+Lfql49aQzdWR2osjFYHJTdgjtuI+PQ=";
  };
}
