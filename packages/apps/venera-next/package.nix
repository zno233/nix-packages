# Venera-Next — repackaged upstream prebuilt .deb (Flutter desktop bundle;
# not rebuilt: the engine and plugins are shipped as precompiled shared
# libraries). Both amd64 and arm64 debs are published.
#
# The bundle resolves `data/` and `lib/` relative to /proc/self/exe, so the
# payload keeps its upstream layout and only the entry point is wrapped.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  nix-update-script,

  # direct ELF dependencies
  gtk3,
  webkitgtk_4_1, # desktop_webview_window plugin
  libepoxy, # flutter_linux_gtk engine
  fontconfig,

  # dlopen'd by libepoxy; absent from NEEDED (see wrapper below)
  libglvnd,
}:

let
  # upstream deb asset naming
  debArch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };
  # refreshed by tools/update-pins — do not edit by hand!
  hashes = {
    x86_64-linux = "sha256-GG93jjqGXtdsWOU/0Prvz1lnKXgprlJMg86ZSC1/Bc4=";
    aarch64-linux = "sha256-wXL7atZGeVwMsU1woAXIl5jm72kt3WGCpAQuNf9O6Ic=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "venera-next";
  version = "1.18.3";

  src = fetchurl {
    url = "https://github.com/CyrilPeng/Venera-Next/releases/download/v${finalAttrs.version}/venera-next_${finalAttrs.version}_${
      debArch.${stdenv.hostPlatform.system}
    }.deb";
    hash = hashes.${stdenv.hostPlatform.system};
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  # Satisfies DT_NEEDED during autoPatchelfHook
  buildInputs = [
    stdenv.cc.cc.lib
    gtk3
    webkitgtk_4_1
    libepoxy
    fontconfig
    libglvnd
  ];

  dontConfigure = true;
  dontBuild = true;
  dontWrapGApps = true;

  unpackPhase = ''
    dpkg-deb -x "$src" .
  '';

  installPhase = ''
    runHook preInstall

    # Keep the flat bundle layout: venera-next looks up lib/ and data/ next
    # to its own executable.
    install -d "$out/lib/venera-next"
    cp -a usr/local/lib/venera-next/. "$out/lib/venera-next/"

    install -Dm644 usr/share/applications/venera-next.desktop \
      "$out/share/applications/venera-next.desktop"
    substituteInPlace "$out/share/applications/venera-next.desktop" \
      --replace-fail 'Exec=/usr/local/lib/venera-next/venera-next' "Exec=$out/bin/venera-next"

    cp -r usr/share/icons "$out/share/icons"

    runHook postInstall
  '';

  preFixup = ''
    # flutter plugins carry build-machine RPATHs and NEED libflutter_linux_gtk.so
    # from their own directory; expose the bundle lib dir to autoPatchelfHook.
    addAutoPatchelfSearchPath "$out/lib/venera-next/lib"
  '';

  postFixup = ''
    # librhttp.so and the other flutter_rust_bridge bundles are opened by
    # bare soname from libapp.so (empty RUNPATH), so dlopen only finds them
    # through the loader path. libglvnd is dlopen'd by libepoxy.
    makeWrapper "$out/lib/venera-next/venera-next" "$out/bin/venera-next" \
      "''${gappsWrapperArgs[@]}" \
      --prefix LD_LIBRARY_PATH : "$out/lib/venera-next/lib:${lib.makeLibraryPath [ libglvnd ]}"
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Cross-platform comic reader supporting local, WebDAV and third-party online sources";
    longDescription = ''
      VeneraNext is a Flutter-based comic reader for Android, iOS, Windows,
      Linux and macOS. It reads local comic archives, WebDAV libraries and
      third-party online comic sources.
    '';
    homepage = "https://github.com/CyrilPeng/Venera-Next";
    changelog = "https://github.com/CyrilPeng/Venera-Next/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "venera-next";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    # both amd64 and arm64 are published as debs
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
