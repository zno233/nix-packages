# mark-shot — repackaged upstream prebuilt release (native Rust build).
#
# The release tarball is an FHS-style `usr/` tree, so autoPatchelfHook fixes the
# interpreter and rpath and the rest is installed verbatim.
#
# The binary resolves its recording library as
# `$(dirname /proc/self/exe)/media/libmarkshot-media.so`, so that library has to
# stay next to the executable in lib/mark-shot/media.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  nix-update-script,

  # direct ELF dependencies
  fontconfig,
  openssl,
  libxkbcommon,
  libxcb,
  pipewire,
  libva,
  libgbm,

  # dlopen'd, absent from NEEDED
  wayland,
  pulseaudio,
}:

let
  version = "0.2.3";

  tarArch = {
    x86_64-linux = "x86_64";
    aarch64-linux = "aarch64";
  };

  archive = "mark-shot-native-${version}-linux-${tarArch.${stdenv.hostPlatform.system}}.tar.gz";

  hashes = {
    x86_64-linux = "sha256-2TeIw2I4ILqj661iNXsc7oPbFNBFYBeidqrxpZfHo7M=";
    aarch64-linux = "sha256-BkO0HdEo+85H8e+4mT6PrbRDICeJyuE6VgK9rs5xYP4=";
  };
in
stdenv.mkDerivation {
  pname = "mark-shot";
  inherit version;

  src = fetchurl {
    url = "https://github.com/jswysnemc/mark-shot/releases/download/v${version}/${archive}";
    hash = hashes.${stdenv.hostPlatform.system};
  };

  sourceRoot = "mark-shot-native-${version}-linux-${tarArch.${stdenv.hostPlatform.system}}";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    fontconfig
    openssl
    libxkbcommon
    libxcb
    pipewire
    libva
    libgbm
  ];

  runtimeDependencies = [
    wayland
    pulseaudio
    stdenv.cc.cc.lib
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/mark-shot" "$out/bin"

    # usr/bin/mark-shot in the tarball is a shell shim; the wrapper replaces it.
    cp -a usr/lib/mark-shot/. "$out/lib/mark-shot/"
    cp -a usr/share "$out/share"

    # Upstream's FFmpeg source archive is not needed at runtime.
    rm "$out/lib/mark-shot/media/MEDIA-SOURCES.tar.xz"

    # The ONNX Runtime that mark-shot installs on first OCR use is dlopen'd
    # from the user's data directory, so it cannot pick up a store rpath and
    # needs libstdc++ on the loader path.
    makeWrapper "$out/lib/mark-shot/mark-shot" "$out/bin/mark-shot" \
      --set MARK_SHOT_MEDIA_LIBRARY "$out/lib/mark-shot/media/libmarkshot-media.so" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ stdenv.cc.cc.lib ]}"

    # 0.2.3 made the Exec path absolute; pin the substitution to the Exec
    # key but leave any trailing arguments (currently %f) untouched.
    substituteInPlace "$out/share/applications/io.github.jswysnemc.MarkShot.desktop" \
      --replace-fail "Exec=/usr/bin/mark-shot" "Exec=$out/bin/mark-shot"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Screenshot, annotation and screen recording tool";
    longDescription = ''
      Mark Shot is a screenshot and screen recording tool with annotation
      editing, scrolling capture, OCR, translation, image host uploads and a
      pinned-image viewer.

      Wayland capture requires a desktop portal implementation
      (xdg-desktop-portal-kde or xdg-desktop-portal-gnome). OCR downloads the
      ONNX Runtime build on first use.
    '';
    homepage = "https://github.com/jswysnemc/mark-shot";
    changelog = "https://github.com/jswysnemc/mark-shot/releases/tag/v${version}";
    license = with lib.licenses; [
      asl20
      mit
    ];
    mainProgram = "mark-shot";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
