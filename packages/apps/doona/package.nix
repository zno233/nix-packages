{
  lib,
  stdenv,
  fetchurl,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "doona";
  version = "0.1.0-rc.7";

  src = fetchurl {
    url = "https://github.com/Zakkaus/doona/releases/download/v${finalAttrs.version}/doona-${finalAttrs.version}.tar.gz";
    hash = "sha256-Xlm+9HDHCxzdMEshH/HhJ/ghbqRZk89Owh07f272MOM=";
  };

  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -d "$out/share/doona"
    shopt -s dotglob
    cp -a ./* "$out/share/doona/"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Web UI for the daeuniverse engines honk/dae native API";
    homepage = "https://github.com/Zakkaus/doona";
    changelog = "https://github.com/Zakkaus/doona/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.all;
  };
})
