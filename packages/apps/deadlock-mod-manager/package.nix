# Deadlock Mod Manager — repackaged official prebuilt .deb release (Tauri
# binary; not rebuilt: webkitgtk/gtk3 stacks are distro-shared upstream).
# autoPatchelfHook handles ELF NEEDED entries; libs that the WebView dlopens
# at runtime (no NEEDED entries, invisible to autoPatchelf) go through the
# wrapper's LD_LIBRARY_PATH / GIO_EXTRA_MODULES.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  nix-update-script,

  # direct ldd dependencies
  gtk3,
  webkitgtk_4_1,
  dbus,
  openssl,

  # dlopen'd at runtime; absent from NEEDED (see wrapProgram below)
  libayatana-appindicator, # tray icon
  glib-networking, # libsoup TLS backend of the WebView (GIO module)
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "deadlock-mod-manager";
  version = "2.2.0";

  src = fetchurl {
    url = "https://github.com/deadlock-mod-manager/deadlock-mod-manager/releases/download/v${finalAttrs.version}/Deadlock.Mod.Manager_${finalAttrs.version}_amd64.deb";
    hash = "sha256-Fs0Rda5Qwz/EDzQNZ22FIc6uHFfNLcUZQLWLXGNzWRY=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    makeWrapper
  ];

  # autoPatchelfHook patches linked libraries
  buildInputs = [
    stdenv.cc.cc.lib
    gtk3
    webkitgtk_4_1
    dbus
    openssl
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    dpkg-deb -x "$src" .
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 usr/bin/deadlock-mod-manager "$out/bin/deadlock-mod-manager"

    install -Dm644 usr/share/applications/"Deadlock Mod Manager.desktop" \
      "$out/share/applications/deadlock-mod-manager.desktop"
    # plain `Exec=deadlock-mod-manager` (no action variants)
    substituteInPlace "$out/share/applications/deadlock-mod-manager.desktop" \
      --replace-fail 'Exec=deadlock-mod-manager' "Exec=$out/bin/deadlock-mod-manager"

    cp -r usr/share/icons $out/share/icons

    # dlopened libs are absent from rpath (nothing links them), so the fixup
    # phase cannot discover them either — hand them to the loader directly.
    # glib-networking is not a shared lib but a GIO module (dlopened by
    # libglib's TLS extension point), exposed through its own env var; it is
    # redundant but harmless on LD_LIBRARY_PATH.
    wrapProgram "$out/bin/deadlock-mod-manager" \
      --prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules" \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          libayatana-appindicator
          glib-networking
        ]
      }

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Mod manager for the Valve game Deadlock, built with Tauri";
    homepage = "https://github.com/deadlock-mod-manager/deadlock-mod-manager";
    changelog = "https://github.com/deadlock-mod-manager/deadlock-mod-manager/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "deadlock-mod-manager";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    # only amd64 is published as a deb
    platforms = [ "x86_64-linux" ];
  };
})
