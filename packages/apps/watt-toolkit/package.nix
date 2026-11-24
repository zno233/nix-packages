# Watt Toolkit (formerly Steam++) — repackaged official prebuilt release.
# Since 3.3.0 upstream ships a NativeAOT single-file executable together
# with the native libraries it loads from its own directory; there is no
# bundled .NET runtime anymore. autoPatchelfHook handles the ELF NEEDED
# entries of the shipped .so files; libraries that the app dlopens by name
# at runtime (no NEEDED entries, invisible to autoPatchelf) are provided
# uniformly through the wrapper's LD_LIBRARY_PATH.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  nix-update-script,
  # Network-accelerator environment-check tools (probed by upstream's
  # environment_check.sh; missing ones raise a "run environment_check.sh
  # in a terminal to install dependencies" dialog):
  nssTools, # certutil — initialises ~/.pki/nssdb and imports the SteamTools CA
  jq, # parses the update API responses
  zenity, # GUI dialogs
  # Spawned directly by the app itself (not probed by environment_check.sh):
  # the Linux system-proxy backend runs `gsettings set/get org.gnome.system.proxy.*`
  # when starting acceleration; a missing binary surfaces as the
  # "Failed to start gsettings" / ProxyStatusError toast
  glib, # provides the gsettings CLI
  gsettings-desktop-schemas, # org.gnome.system.proxy.* schema definitions
  # ELF NEEDED or dlopen'd at runtime (see dlopenLibs below):
  icu,
  openssl,
  fontconfig, # NEEDED of libSkiaSharp.so
  gtk3,
  dbus, # libdbus-1.so.3 (dlopen'd by the Avalonia/GTK stack)
  libglvnd, # libGL.so.1 (Avalonia GLX/Skia)
  libice, # libICE.so.6 (Avalonia X11 ICE)
  libsm, # libSM.so.6
  vulkan-loader, # libvulkan.so.1 (optional Avalonia render backend)
  libx11,
  libxcursor,
  libxfixes,
  libxrandr,
  libxi,
  libxext,
}:

stdenv.mkDerivation (
  finalAttrs:
  let
    # Libraries that the app dlopens by name at runtime (no NEEDED entries,
    # so autoPatchelf cannot see them). SSOT: consumed twice — the wrapper's
    # LD_LIBRARY_PATH (primary, see preFixup) and the tail of buildInputs
    # (lets autoPatchelf search them as well; no NEEDED references them
    # today, kept defensively).
    # - icu: the NativeAOT runtime's ICU shim dlopens unversioned
    #   libicuuc.so/libicui18n.so; nixpkgs icu's out/lib ships exactly those
    #   unversioned symlinks
    # - openssl: System.Security.Cryptography.Native.OpenSsl dlopens libssl.so.3
    # - libglvnd / vulkan-loader: libGL.so.1 / libvulkan.so.1
    # - libice / libsm: libICE.so.6 / libSM.so.6 (missing => DllNotFoundException)
    # - x11 family / gtk3 / dbus: Avalonia's X11 backend dlopens them by name
    dlopenLibs = [
      icu
      openssl
      gtk3
      dbus
      libglvnd
      libice
      libsm
      vulkan-loader
      libx11
      libxcursor
      libxfixes
      libxrandr
      libxi
      libxext
    ];

    # Runtime tools probed by environment_check.sh -c, injected via wrapper
    # --prefix PATH: the app's AcceleratorPageViewModel.EnvironmentCheck runs
    # <BaseDirectory>/script/environment_check.sh -c through /bin/bash and
    # only proceeds on exit 200 (command -v certutil succeeded), otherwise it
    # shows the "run environment_check.sh manually" dialog. The ~/.pki/nssdb
    # initialisation runs idempotently via wrapper --run (same no-sql: path
    # form as the app's own certutil call, so both share one database).
    runtimeTools = [
      nssTools # certutil
      jq
      zenity
      # Not probed by environment_check.sh: the app's own process starter
      # resolves `gsettings` from PATH (execvp), so it must be injected here
      glib
    ];
  in
  {
    pname = "watt-toolkit-bin";
    version = "3.3.0";

    src = fetchurl {
      # "++" must be URL-encoded as %2B%2B. Upstream switched to NativeAOT
      # assets in 3.3.0 (`_aot` suffix, no more self-contained dotnet/ tree).
      url = "https://github.com/BeyondDimension/SteamTools/releases/download/${finalAttrs.version}/Steam%2B%2B_v${finalAttrs.version}_linux_x64_aot.tgz";
      hash = "sha256-4P1Dj9Z2T58m7URYqsbIlov8ZZsKlrzHnU+81ZImH+E=";
    };

    strictDeps = true;
    # the tgz has no single top-level dir (Steam++, lib*.so, Icons/, ... flat);
    # anchor sourceRoot explicitly
    sourceRoot = ".";
    dontBuild = true;
    dontConfigure = true;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      copyDesktopItems
    ];

    buildInputs = [
      (lib.getLib stdenv.cc.cc) # libstdc++.so.6 / libgcc_s.so.1
      fontconfig # NEEDED of libSkiaSharp.so
    ]
    ++ dlopenLibs;

    desktopItems = [
      (makeDesktopItem {
        name = "watt-toolkit";
        desktopName = "Watt Toolkit";
        exec = "watt-toolkit";
        icon = "watt-toolkit";
        # actual WM_CLASS of the upstream Avalonia window (verified with
        # Xvfb + xwininfo)
        startupWMClass = "Steam++";
        comment = "Cross-platform toolbox for Steam (formerly Steam++)";
        categories = [
          "Utility"
          "Game"
        ];
      })
    ];

    installPhase = ''
      runHook preInstall

      install -dm755 $out/opt/watt-toolkit
      # 3.3.0+ is a NativeAOT single-file build: the executable, the native
      # libraries, the accelerator helper and the environment-check script
      # all live flat in the archive and must stay next to each other.
      # script/environment_check.sh must be installed: the app runs it with
      # /bin/bash (<BaseDirectory>/script/environment_check.sh -c) before
      # "network acceleration / install certificate" and only proceeds on
      # exit 200 (certutil present); otherwise it prompts to run the script
      # manually in a terminal
      cp -r Icons modules script \
        Steam++ libSkiaSharp.so libHarfBuzzSharp.so libe_sqlite3.so \
        $out/opt/watt-toolkit/

      # every member of the tar is 0700; add the world-readable bits the
      # store payload needs
      chmod -R u+rwX,go+rX $out/opt/watt-toolkit

      install -Dm644 Icons/Watt-Toolkit.png \
        $out/share/icons/hicolor/512x512/apps/watt-toolkit.png

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script { };

    preFixup = ''
      makeWrapper $out/opt/watt-toolkit/Steam++ $out/bin/watt-toolkit \
        --prefix PATH : ${lib.makeBinPath runtimeTools} \
        --set GSETTINGS_SCHEMA_DIR ${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}/glib-2.0/schemas \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath dlopenLibs}:$out/opt/watt-toolkit \
        --run '${nssTools}/bin/certutil -d $HOME/.pki/nssdb -L >/dev/null 2>&1 || { mkdir -p -m 700 $HOME/.pki/nssdb; ${nssTools}/bin/certutil -d $HOME/.pki/nssdb -N --empty-password; }'
    '';

    meta = {
      description = "Cross-platform toolbox for Steam (formerly Steam++)";
      longDescription = ''
        Watt Toolkit is a cross-platform Steam toolbox supporting account
        switching, authenticator, network acceleration and more. This package
        repackages the official prebuilt release.
      '';
      homepage = "https://steampp.net";
      changelog = "https://github.com/BeyondDimension/SteamTools/releases/tag/${finalAttrs.version}";
      license = lib.licenses.gpl3Only;
      mainProgram = "watt-toolkit";
      sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      # arm64 tgz appeared in the 3.0.0-rc series only; stable releases are x64
      platforms = [ "x86_64-linux" ];
    };
  }
)
