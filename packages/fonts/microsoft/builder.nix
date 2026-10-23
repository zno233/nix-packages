{
  fetchurl,
  lib,
  sources ? import ../../tools/gen-ms-sources/sources.nix,
  stdenvNoCC,
  ...
}:
{
  files,
  fontFamily,
  meta ? { },
  pname,
  ...
}@args:
let
  inherit (lib)
    concatMapStrings
    escapeShellArg
    licenses
    maintainers
    platforms
    removeAttrs
    ;

  sourceFor =
    file:
    let
      source =
        sources.files.${file} or (throw ''
          chinese-fonts-overlay: no direct source for Microsoft font file `${file}`.

          Add a mapping for it to tools/gen-ms-sources/map.tsv and run
          tools/gen-ms-sources/gen.sh to regenerate
          tools/gen-ms-sources/sources.nix, or drop the file from `files`
          in the package definition.
        '');
    in
    fetchurl { inherit (source) url hash; };

  defaultInstallPhase = ''
      runHook preInstall

      fontDir=$out/share/fonts/truetype/microsoft

      mkdir -p $fontDir

    ${concatMapStrings (file: ''
      gunzip -c ${sourceFor file} > "$fontDir"/${escapeShellArg file}
      chmod 444 "$fontDir"/${escapeShellArg file}
    '') files}
      runHook postInstall
  '';

  defaultMeta = {
    description = "Microsoft ${fontFamily} font package";
    homepage = "https://learn.microsoft.com/en-us/typography/fonts/font-faq";
    license = licenses.microsoft-software-license;

    longDescription = ''
      Provides font files for ${fontFamily}, downloaded from the
      pjobson/Microsoft-Fonts archive of Microsoft Windows font files.

      Obtain a valid license under the Microsoft Software License
      Terms before use. After obtaining it, do not redistribute the
      font files or publish them through a binary cache unless that
      license permits it.
    '';

    maintainers = with maintainers; [ brsvh ];
    platforms = platforms.all;
    redistributable = false;
  };
in
stdenvNoCC.mkDerivation (
  (removeAttrs args [
    "files"
    "fontFamily"
  ])
  // {
    inherit pname;

    dontUnpack = args.dontUnpack or true;
    installPhase = args.installPhase or defaultInstallPhase;
    meta = defaultMeta // meta;
    version = args.version or sources.version;
  }
)
