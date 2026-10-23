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

  name = "sf-compact";
  pkgName = "SFCompactFontsPackage.pkg";
  nerd = false;

  src = fetchurl {
    url = "https://devimages-cdn.apple.com/design/resources/download/SF-Compact.dmg";
    hash = "sha256-wdDjROut1m62LwP4I3hMzknxeH9WVj+wmPygH8VUE1w=";
  };
}
