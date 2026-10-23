# Vendored from github:Lyndeno/apple-fonts.nix fontPackage.nix, adapted:
# the dmg sources are pinned via fetchurl in each package.nix (instead of
# flake inputs) and an unfree license meta is attached (Apple EULA).
{
  name,
  pkgName,
  src,
  nerd,
  stdenvNoCC,
  p7zip,
  lib,
  parallel,
  nerd-font-patcher,
}:
let
  unpackPhase = pkgName: ''
    runHook preUnpack
    7z x $src
    if [ ! -f 'Payload~' ]; then
      7z x './*/${pkgName}'
    fi
    7z x -tcpio 'Payload~'
    runHook postUnpack
  '';

  commonInstall = ''
    mkdir -p "$out/share/fonts/opentype"
    mkdir -p "$out/share/fonts/truetype"
  '';
in
stdenvNoCC.mkDerivation {
  inherit name src;

  unpackPhase = unpackPhase pkgName;

  buildInputs = [
    p7zip
  ]
  ++ lib.optionals nerd [
    parallel
    nerd-font-patcher
  ];

  setSourceRoot = "sourceRoot=`pwd`";

  buildPhase = lib.optionalString nerd ''
    runHook preBuild
    find \( -name \*.ttf -o -name \*.otf \) -print0 | parallel --will-cite -j $NIX_BUILD_CORES -0 nerd-font-patcher --no-progressbars -c {}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
  ''
  + commonInstall
  + (
    if nerd then
      ''
        find -name \*.otf -maxdepth 1 -exec mv {} "$out/share/fonts/opentype/" \;
        find -name \*.ttf -maxdepth 1 -exec mv {} "$out/share/fonts/truetype/" \;
      ''
    else
      ''
        find -name \*.otf -exec mv {} "$out/share/fonts/opentype/" \;
        find -name \*.ttf -exec mv {} "$out/share/fonts/truetype/" \;
      ''
  )
  + "runHook postInstall";

  meta = {
    # Apple fonts are distributed under the Apple EULA, not a free license.
    license = lib.licenses.unfree;
  };
}
