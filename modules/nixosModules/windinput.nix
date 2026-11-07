# NixOS module for WindInput (清风输入法), exported by this flake as
# nixosModules.windinput and included in the nixosModules.default collection.
#
# WindInput is a Fcitx5 addon, not a daemon, so this module only registers the
# addon and sets two environment variables.  The addon spawns the service and
# the settings program from hard-coded Debian paths (/usr/lib/windinput/...);
# both launchers honour WIND_INPUT_SERVICE / WIND_INPUT_SETTING, so point them
# at the Nix store instead of patching the prebuilt binaries.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkPackageOption
    ;

  cfg = config.programs.windinput;
in
{
  options = {
    programs.windinput = {
      enable = mkEnableOption "WindInput (清风输入法) Fcitx5 input method";

      package = mkPackageOption pkgs "windinput" { };
    };
  };

  config = lib.mkIf cfg.enable {
    i18n.inputMethod = {
      enable = lib.mkDefault true;
      type = lib.mkDefault "fcitx5";
      fcitx5.addons = [ cfg.package ];
    };

    environment.sessionVariables = {
      WIND_INPUT_SERVICE = "${cfg.package}/lib/windinput/wind_input";
      WIND_INPUT_SETTING = "${cfg.package}/lib/windinput/wind_setting";
    };
  };
}
