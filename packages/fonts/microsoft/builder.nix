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

          Run tools/gen-ms-sources/gen.sh to regenerate
          tools/gen-ms-sources/sources.nix (its coverage check reports the
          missing files), or drop the file from `files` in the package
          definition.
        '');
    in
    fetchurl { inherit (source) url hash; };

  defaultInstallPhase = ''
      runHook preInstall

      fontDir=$out/share/fonts/truetype/microsoft

      mkdir -p $fontDir

    ${concatMapStrings (file: ''
      src=${sourceFor file}
      fontFile="$fontDir"/${escapeShellArg file}
      # legacy pjobson-era sources were gzipped; the current uinv
      # windows-fonts snapshot ships the font files as-is
      if gzip -t "$src" 2>/dev/null; then
        gunzip -c "$src" > "$fontFile"
        chmod 444 "$fontFile"
      else
        install -m 444 "$src" "$fontFile"
      fi
    '') files}
      runHook postInstall
  '';

  defaultMeta = {
    description = "Microsoft ${fontFamily} font package";
    homepage = "https://learn.microsoft.com/en-us/typography/fonts/font-faq";
    license = licenses.microsoft-software-license;

    longDescription = ''
      Provides font files for ${fontFamily}, downloaded from the
      uinv/windows-fonts Windows font snapshot.

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
