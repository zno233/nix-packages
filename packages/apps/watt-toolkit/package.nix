# Watt Toolkit (formerly Steam++) — repackaged official prebuilt release
# with its bundled .NET runtime kept intact (not rebuilt against nixpkgs
# dotnet: version-coupled to AspNetCore.App 10.0.4). autoPatchelfHook
# handles ELF NEEDED entries; libs that .NET/Avalonia dlopen at runtime
# (no NEEDED entries, invisible to autoPatchelf) are provided uniformly
# through the wrapper's LD_LIBRARY_PATH.
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
  # ELF NEEDED or dlopen'd at runtime (see dlopenLibs below):
  icu,
  openssl,
  fontconfig, # NEEDED of libSkiaSharp.so
  gtk3,
  libglvnd, # libGL.so.1 (Avalonia GLX/Skia)
  libice, # libICE.so.6 (Avalonia X11 ICE)
  libsm, # libSM.so.6
  vulkan-loader, # libvulkan.so.1 (optional Avalonia render backend)
  libx11,
  libxcursor,
  libxrandr,
  libxi,
  libxext,
}:

stdenv.mkDerivation (
  finalAttrs:
  let
    # Libraries that .NET/Avalonia managed code dlopen by name at runtime
    # (no NEEDED entries, so autoPatchelf cannot see them). SSOT: consumed
    # twice — the wrapper's LD_LIBRARY_PATH (primary, see preFixup) and the
    # tail of buildInputs (lets autoPatchelf search them as well; no NEEDED
    # references them today, kept defensively).
    # - icu: .NET 10's ICU shim dlopens unversioned libicuuc.so/libicui18n.so;
    #   nixpkgs icu's out/lib ships exactly those unversioned symlinks
    # - openssl: System.Security.Cryptography.Native.OpenSsl dlopens libssl.so.3
    # - libglvnd / vulkan-loader: libGL.so.1 / libvulkan.so.1
    # - libice / libsm: libICE.so.6 / libSM.so.6 (missing => DllNotFoundException)
    # - x11 family / gtk3: Avalonia's X11 backend dlopens them by name
    dlopenLibs = [
      icu
      openssl
      gtk3
      libglvnd
      libice
      libsm
      vulkan-loader
      libx11
      libxcursor
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
    ];
  in
  {
    pname = "watt-toolkit-bin";
    version = "3.1.0";

    src = fetchurl {
      # "++" must be URL-encoded as %2B%2B
      url = "https://github.com/BeyondDimension/SteamTools/releases/download/${finalAttrs.version}/Steam%2B%2B_v${finalAttrs.version}_linux_x64.tgz";
      hash = "sha256-+5m81PpqxkkihwD5CIGf4ZoWzCmoZq1D0oc+UEpBeD8=";
    };

    strictDeps = true;
    # the tgz has no single top-level dir (assemblies/ dotnet/ ... flat);
    # anchor sourceRoot explicitly
    sourceRoot = ".";
    dontBuild = true;
    dontConfigure = true;
    # lttng-ust >= 2.14 bumped the soname to liblttng-ust.so.1 (ABI break)
    # while upstream's libcoreclrtraceptprovider.so still NEEDs the old
    # liblttng-ust.so.0, which nixpkgs no longer ships. The provider is only
    # dlopen'd when an LTTng tracing session is enabled — irrelevant for
    # desktop use — so the dangling NEEDED is exempted explicitly (it only
    # ever affects that one lazy load).
    autoPatchelfIgnoreMissingDeps = [ "liblttng-ust.so.0" ];

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
      # script/environment_check.sh must be installed: the app runs it with
      # /bin/bash (<BaseDirectory>/script/environment_check.sh -c) before
      # "network acceleration / install certificate" and only proceeds on
      # exit 200 (certutil present); otherwise it prompts to run the script
      # manually in a terminal
      cp -r assemblies dotnet modules native Icons $out/opt/watt-toolkit/
      install -Dm755 script/environment_check.sh \
        $out/opt/watt-toolkit/script/environment_check.sh
      # Replaces upstream's Steam++.sh (upstream creates a Steam++ -> dotnet
      # symlink in the install dir; the store is read-only). Installing a
      # certificate runs pkexec <BaseDirectory>/Steam++.sh linux -ceri ...
      # as root, so this file must exist
      printf '%s\n' \
        '#!/bin/sh' \
        'run_path="$(dirname "$0")"' \
        'export DOTNET_ROOT="$run_path/dotnet"' \
        'exec "$run_path/dotnet/dotnet" "$run_path/assemblies/Steam++.dll" "$@"' \
        > $out/opt/watt-toolkit/Steam++.sh
      chmod 755 $out/opt/watt-toolkit/Steam++.sh

      # every member of the tar is 0700; add the world-readable bits the
      # store payload needs
      chmod -R u+rwX,go+rX $out/opt/watt-toolkit

      install -Dm644 Icons/Watt-Toolkit.png \
        $out/share/icons/hicolor/512x512/apps/watt-toolkit.png

      runHook postInstall
    '';

    passthru.updateScript = nix-update-script { };

    preFixup = ''
      makeWrapper $out/opt/watt-toolkit/dotnet/dotnet $out/bin/watt-toolkit \
        --set DOTNET_ROOT $out/opt/watt-toolkit/dotnet \
        --prefix PATH : ${lib.makeBinPath runtimeTools} \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath dlopenLibs}:$out/opt/watt-toolkit/native/linux-x64 \
        --run '${nssTools}/bin/certutil -d $HOME/.pki/nssdb -L >/dev/null 2>&1 || { mkdir -p -m 700 $HOME/.pki/nssdb; ${nssTools}/bin/certutil -d $HOME/.pki/nssdb -N --empty-password; }' \
        --add-flags $out/opt/watt-toolkit/assemblies/Steam++.dll
    '';

    meta = {
      description = "Cross-platform toolbox for Steam (formerly Steam++)";
      longDescription = ''
        Watt Toolkit is a cross-platform Steam toolbox supporting account
        switching, authenticator, network acceleration and more. This package
        repackages the official prebuilt release with its bundled .NET runtime.
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
