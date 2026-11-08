# WindInput (清风输入法) — repackaged upstream Debian release.  The archive
# contains the Fcitx5 addon, the Rust service, the settings GUI and the
# generated dictionary data.  Building the service and data from source means
# assembling several third-party dictionaries and generators, so this follows
# the AUR package fcitx5-windinput-bin and repackages the release artefact.
# Both amd64 and arm64 debs are published.
#
# The addon is built against Fcitx5 5.0.x but only uses the stable sonames
# (libFcitx5Core.so.7 / libFcitx5Config.so.6 / libFcitx5Utils.so.2), which are
# unchanged in 5.1.x.
{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  nix-update-script,

  # direct ELF dependencies
  fcitx5,
  libxcb,
  wayland,
  glib,
  libgcc,

  # dlopen'd at runtime by the service / settings GUI; absent from NEEDED
  # (see runtimeDependencies below)
  fontconfig,
  dbus,
  libxkbcommon,
}:

let
  # upstream deb asset naming
  debArch = {
    x86_64-linux = "amd64";
    aarch64-linux = "arm64";
  };

  hashes = {
    x86_64-linux = "sha256-HktkEKF14PaVduFtuTS/HVkTewFZ9/hiRJGNS15jU+g=";
    aarch64-linux = "sha256-4pX7Ix2BHnxJv7+50zRInAqilOHZuFfJJjjdQHd/Mzo=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "windinput";
  version = "0.131.0";

  src = fetchurl {
    # Canonical GitHub release first, then the link published on
    # windinput.com/download (an official alias that redirects to GitHub).
    urls = [
      "https://github.com/huanfeng/WindInput/releases/download/v${finalAttrs.version}/WindInput-${finalAttrs.version}-linux-${
        debArch.${stdenv.hostPlatform.system}
      }.deb"
      "https://dl.windinput.com/WindInput-${finalAttrs.version}-linux-${
        debArch.${stdenv.hostPlatform.system}
      }.deb"
    ];
    hash = hashes.${stdenv.hostPlatform.system};
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
  ];

  # autoPatchelfHook patches linked libraries
  buildInputs = [
    stdenv.cc.cc.lib
    libgcc
    fcitx5
    libxcb
    wayland
    glib
  ];

  # The service and the settings GUI dlopen fontconfig / dbus / xkbcommon
  # instead of linking them, so they are absent from DT_NEEDED and
  # autoPatchelfHook cannot discover them on its own.
  runtimeDependencies = [
    fontconfig
    dbus
    libxkbcommon
  ];

  dontConfigure = true;
  dontBuild = true;

  unpackPhase = ''
    dpkg-deb -x "$src" .
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/windinput" "$out/lib/fcitx5" "$out/bin"

    # The service resolves its data directory as `dirname $(current_exe)/data`,
    # so both files must stay in the same directory.
    install -Dm755 usr/lib/windinput/wind_input "$out/lib/windinput/wind_input"
    install -Dm755 usr/lib/windinput/wind_setting "$out/lib/windinput/wind_setting"
    cp -a usr/lib/windinput/data "$out/lib/windinput/data"

    # Debian puts the addon in a multiarch directory.
    install -Dm755 "$(find usr/lib -type f -name libwindinput.so -print -quit)" \
      "$out/lib/fcitx5/libwindinput.so"

    cp -a usr/share "$out/share"

    # The desktop files use Debian's hard-coded /usr path.
    substituteInPlace "$out/share/applications/windinput-setting.desktop" \
      --replace-fail "/usr/lib/windinput/wind_setting" "$out/lib/windinput/wind_setting"
    substituteInPlace "$out/share/applications/windinput-import.desktop" \
      --replace-fail "/usr/lib/windinput/wind_setting" "$out/lib/windinput/wind_setting"

    # Convenience entry point for `nix run`.
    ln -s ../lib/windinput/wind_setting "$out/bin/windinput-setting"

    runHook postInstall
  '';

  passthru = {
    updateScript = nix-update-script { };

    # Consumed by nixpkgs' fcitx5-with-addons wrapper, which exports
    # LD_LIBRARY_PATH for the addon-spawned service.
    extraLdLibraries = [
      fontconfig
      dbus
      libxkbcommon
    ];
  };

  meta = {
    description = "WindInput (清风输入法) Fcitx5 input method engine";
    longDescription = ''
      WindInput is a lightweight Chinese input method for Wubi and table-based
      schemas, with pinyin and shuangpin support.  This package provides the
      Fcitx5 addon, the Rust input service and its dictionaries, and the
      graphical settings program.

      On NixOS, enable `programs.windinput.enable`; it adds the addon to
      Fcitx5 and points the addon at the Nix store paths of the service and
      settings program.  Without the module, set `WIND_INPUT_SERVICE` and
      `WIND_INPUT_SETTING` to the binaries under `lib/windinput/` manually.
    '';
    homepage = "https://windinput.com";
    changelog = "https://github.com/huanfeng/WindInput/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    mainProgram = "windinput-setting";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
