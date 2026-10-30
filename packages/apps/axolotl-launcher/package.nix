# Axolotl Launcher — repackaged official prebuilt .deb release (Tauri binary;
# not rebuilt: webkitgtk/gtk3 stacks are distro-shared upstream). Both amd64
# and arm64 debs are published.
# Download comes from the official Update Server (Cloudflare edge behind
# update.axlmc.org / dist.axlmc.org), which is how the official website's
# download section serves installers; the catalog also carries the sha256
# of every installer, which tools/update-pins replays into the hashes below
# (nix-update cannot drive this URL, and a single run of it would only
# refresh one platform's hash anyway). autoPatchelfHook handles ELF NEEDED
# entries; libs that the WebView dlopens at runtime (no NEEDED entries,
# invisible to autoPatchelf) go through the wrapper's LD_LIBRARY_PATH /
# GIO_EXTRA_MODULES.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  nix-update-script,

  gtk3,
  webkitgtk_4_1,
  dbus,

  # dlopen'd at runtime; absent from NEEDED (see wrapProgram below)
  libayatana-appindicator, # tray icon (debian: libayatana-appindicator3-1)
  glib-networking, # libsoup TLS backend of the WebView (GIO module)
}:

let
  # upstream deb asset naming
  debArch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };
  # sha256 of the official Update Server catalog deb for each platform;
  # flat one-line entries, refreshed by tools/update-pins — do not edit
  # by hand!
  hashes.x86_64-linux = "sha256-5rduKWkxItBjTNiEFCyTR6zGLLBayYj6NKXMVqZoQjg=";
  hashes.aarch64-linux = "sha256-WzFEvtz49O4ACBTgTlSQwIZYx+v7eTWPERDYVFYvJH4=";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "axolotl-launcher";
  version = "1.10.4";

  src = fetchurl {
    # official website CDN (Axolotl Launcher update server catalog):
    # https://update.axlmc.org/api/downloads/latest?channel=release
    url = "https://update.axlmc.org/dist/${finalAttrs.version}/Axolotl.Launcher_${finalAttrs.version}_${
      debArch.${stdenv.hostPlatform.system}
    }.deb";
    hash = hashes.${stdenv.hostPlatform.system};
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
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    dpkg-deb -x "$src" .
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 "usr/bin/Axolotl Launcher" "$out/bin/axolotl-launcher"

    install -Dm644 'usr/share/applications/Axolotl Launcher.desktop' \
      "$out/share/applications/axolotl-launcher.desktop"
    # keep StartupWMClass="Axolotl Launcher" intact for window matching
    substituteInPlace "$out/share/applications/axolotl-launcher.desktop" \
      --replace-fail 'Exec="Axolotl Launcher"' "Exec=$out/bin/axolotl-launcher"

    cp -r usr/share/icons $out/share/icons
    # spaced icon filenames break hicolor cache generation in
    # user-environment builds; flatten every spaced icon file, then
    # point Icon= at the result
    find "$out/share/icons" -type f -name '* *' | while read -r f; do
      mv "$f" "$(dirname "$f")/$(basename "$f" | tr 'A-Z ' 'a-z-')"
    done
    [[ -z $(find "$out/share/icons" -type f -name '* *') ]]
    substituteInPlace "$out/share/applications/axolotl-launcher.desktop" \
      --replace-fail 'Icon=Axolotl Launcher' 'Icon=axolotl-launcher'

    # dlopened libs are absent from rpath (nothing links them), so the fixup
    # phase cannot discover them either — hand them to the loader directly.
    # glib-networking is not a shared lib but a GIO module (dlopened by
    # libglib's TLS extension point), exposed through its own env var; it is
    # redundant but harmless on LD_LIBRARY_PATH.
    wrapProgram "$out/bin/axolotl-launcher" \
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
    description = "Free, open-source and ad-free cross-platform Minecraft Java launcher (Modrinth App fork)";
    longDescription = ''
      Axolotl Launcher is a cross-platform Minecraft Java launcher built on
      the Modrinth App monorepo with the commercial components removed.
      It browses Modrinth and CurseForge for mods, modpacks, resource packs
      and shaders, keeps external .minecraft directories working as-is, adds
      locally usable offline accounts and MSA login, custom Yggdrasil
      authentication, instance snapshot backups, a skin editor, seed maps
      and projection tooling.
    '';
    homepage = "https://www.axlmc.org";
    changelog = "https://github.com/Axolotl-Launcher/Axolotl/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "axolotl-launcher";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    # both amd64 and arm64 are published as debs
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
