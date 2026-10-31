# NixOS module for honk (services.honk-core), exported by this flake as
# nixosModules.honk and included in the nixosModules.default collection.
# Based on the upstream
# daeuniverse honk module (official style), with:
# - package via mkPackageOption pkgs "honk" (this flake's overlay)
# - ui option and the api.dae/doona native-API wiring
# - optional database-backed configuration store (--store db) for doona's
#   import and revisions
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    literalExpression
    types
    optional
    optionalString
    getExe
    mkPackageOption
    isString
    ;

  cfg = config.services.honk-core;
  inherit (cfg) assets nativeApiListen;

  genAssetsDrv =
    paths:
    pkgs.symlinkJoin {
      name = "honk-assets";
      inherit paths;
    };

  # ui option -> value for native_api.ui: the "embedded" literal passes
  # through; a package resolves to its static dashboard directory.
  uiPath = ui: if isString ui then ui else "${ui}/share/doona";

  # Native API block shared by both wiring paths (inline bake / config.d
  # include): honk serves the dashboard at /ui/, same origin as /api.
  nativeApiText = ui: ''
    # Every native_api field needs a restart; a reload rejects changes.
    experimental {
        native_api {
            enabled: true
            # Loopback by default; set services.honk-core.nativeApiListen
            # (e.g. '192.168.1.1:9527') to reach doona from other hosts.
            listen: '${nativeApiListen}'
            # Administrator password login. For token mode, delete this
            # line and set secret instead; the two cannot be combined.
            password_auth: true
            # secret: 'replace-with-a-long-random-token'
            # doona's config page writes sources through the engine (If-Match)
            config_write: true
            ui: '${uiPath ui}'
            # On by default; listed so the names are known.
            record_flows: true
            record_traffic: true
            record_memory: true
            record_logs: true
            record_dns_log: true
        }
    }
  '';

  apiDae = pkgs.writeText "api.dae" (nativeApiText cfg.ui);
in
{
  options = {
    services.honk-core = {
      enable = mkEnableOption "honk, a Linux high-performance transparent proxy solution based on eBPF";

      package = mkPackageOption pkgs "honk" { };

      assets = mkOption {
        type = with types; (listOf path);
        default = with pkgs; [
          v2ray-geoip
          v2ray-domain-list-community
        ];
        defaultText = literalExpression "with pkgs; [ v2ray-geoip v2ray-domain-list-community ]";
        description = "Assets required to run honk.";
      };

      assetsPath = mkOption {
        type = types.str;
        default = "${genAssetsDrv assets}/share/v2ray";
        defaultText = literalExpression ''
          "''${(symlinkJoin {
              name = "honk-assets";
              paths = assets;
          })}/share/v2ray"
        '';
        description = ''
          Directory containing `geoip.dat` / `geosite.dat` used as the
          first-run seed: missing files are copied from here into
          `/var/lib/honk` at service start (never overwriting files already
          there). honk loads and updates the `/var/lib/honk` copies in place,
          so doona's geodata updates survive restarts.
          This option will override `assets`.
        '';
      };

      openFirewall = mkOption {
        type = types.submodule {
          options = {
            enable = mkEnableOption "opening {option}`port` in the firewall";
            port = mkOption {
              type = types.port;
              description = ''
                Port to be opened. Consist with field `tproxy_port` in config file.
              '';
            };
          };
        };
        default = {
          enable = true;
          port = 12345;
        };
        defaultText = literalExpression ''
          {
            enable = true;
            port = 12345;
          }
        '';
        description = ''
          Open the firewall port.
        '';
      };

      configFile = mkOption {
        type =
          let
            inherit (types) nullOr addCheck str;
            isAbsolutePathString = x: lib.substring 0 1 x == "/";
            isNotInStore = x: !lib.hasPrefix builtins.storeDir x;
            combineTopic = x: isAbsolutePathString x && isNotInStore x;
          in
          (nullOr (addCheck str combineTopic))
          // {
            description = "${types.str.description} (with check: should be absolute path **string** which not a store path)";
          };
        default = null;
        example = ''"/path/to/your/config.dae"'';
        description = ''
          The absolute path string of honk config file which not in nix store,
          end with `.dae`. Will fallback to `"/etc/honk/config.dae"` if this is not set.
        '';
      };

      config = mkOption {
        type = with types; (nullOr str);
        default = null;
        description = ''
          WARNING: This option will expose your config unencrypted world-readable in the nix store.
          Config text for honk.

          See <https://github.com/daeuniverse/honk/blob/main/example.dae>.
        '';
      };

      disableTxChecksumIpGeneric = mkEnableOption "" // {
        description = "See <https://github.com/daeuniverse/dae/issues/43>";
      };

      nativeApiListen = mkOption {
        type = types.str;
        default = "127.0.0.1:9527";
        example = "192.168.1.1:9527";
        description = ''
          Address/name and port (`host:port`) the native API listens on.
          Only applies when `ui` is set (the module writes the native_api
          block itself); a manual `native_api` in `config` overrides the
          module's wiring entirely. Both parts need a service restart.
          Set a LAN address (e.g. `192.168.1.1:9527`) to reach doona from
          other hosts; a firewall entry is not opened for it here.
        '';
      };

      ui = mkOption {
        type = types.nullOr (types.either types.package (types.enum [ "embedded" ]));
        default = null;
        example = "pkgs.doona";
        description = ''
          Dashboard hosted by honk's native API at /ui/ (same origin as /api).
          Set to "embedded" to serve the dashboard inside honk's `-full`
          build (always matches the engine version), or to a package (e.g.
          pkgs.doona) whose `/share/doona` contains it, to run the panel
          from a separate build. When set, the module only places
          `config.d/api.dae` next to `configFile` with experimental.native_api
          enabled. The `include { config.d/*.dae }` in `configFile` is a module
          default maintained independently of this option (a legacy
          `include { api.dae }` is normalized to the glob form). The include is
          a separate file so the main file stays editable from the UI's config
          page. All native_api fields are restart-required.
        '';
      };

      storeDb = mkEnableOption ''
        the database-backed configuration store (`--store db`), which enables
        doona's export, import and revisions: the administered `.dae` sources
        are kept as revisions in `/var/lib/honk/state/honk.db`. File mode can
        still export; import and the revision routes are db-mode-only. The
        first db-mode start imports the config file and records revision 1
        (needs the native API with `config_write: true` and a credential —
        both provided by the module's native_api wiring). Afterwards the
        recorded revision drives the engine and the config file is ignored:
        startup runs the revision, and so does a reload — `honk reload`
        (SIGHUP) re-activates honk's startup path, db mode's active revision,
        not the config file. Regenerating `config` therefore reaches honk
        only through the import API (what doona's configuration-import
        button calls: `POST /api/v1/x-honk/config/import` with
        `{"replace": true}` and an `Idempotency-Key`; a plain curl works —
        the engine re-reads the config file) or by activating a recorded
        revision. Db mode runs without the Clash API — a non-empty
        `experimental.clash_api.external_controller` refuses startup. To
        leave the mode, run `honk-core config export --out <file>` (listener
        secrets restored unless `--without-secrets`; refuses to overwrite an
        existing file), then switch this option off and restart.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # Inline config: no external configFile for the ExecStartPre wiring to
      # hook into, so bake native_api straight into the generated text
      # (skipped when the config already mentions native_api).
      (lib.mkIf (cfg.configFile == null) {
        environment.etc."honk/config.dae" = {
          mode = "0400";
          source = pkgs.writeText "config.dae" (
            cfg.config
            + optionalString (cfg.ui != null && !(lib.hasInfix "native_api" cfg.config)) (
              "\n" + nativeApiText cfg.ui
            )
          );
        };
      })
      {
        environment.systemPackages = [ cfg.package ];

        networking = lib.mkIf cfg.openFirewall.enable {
          firewall =
            let
              portToOpen = cfg.openFirewall.port;
            in
            {
              allowedTCPPorts = [ portToOpen ];
              allowedUDPPorts = [ portToOpen ];
            };
        };

        # Requires root + eBPF/netadmin; do not harden until the datapath is verified.
        # Conflicts with another real datapath (e.g. daed) — only one per host.
        systemd =
          let
            honkBin = getExe cfg.package;

            # Upstream calls getExe without parentheses around this derivation
            # (broken when the option is on); nixos dae module wraps it — do too.
            TxChecksumIpGenericWorkaround = getExe (
              pkgs.writeShellApplication {
                name = "disable-tx-checksum-ip-generic";
                text = ''
                  iface=$(${pkgs.iproute2}/bin/ip route | ${getExe pkgs.gawk} '/default/ {print $5}')
                  ${getExe pkgs.ethtool} -K "$iface" tx-checksum-ip-generic off
                '';
              }
            );

            configPath = if cfg.configFile != null then cfg.configFile else "/etc/honk/config.dae";

            # ui option: only place doona's native_api fragment. Runs on every
            # start (ExecStartPre) when ui and an external configFile are set:
            # writes config.d/api.dae. config.d is created with the parent's
            # owner/mode because UMask 0077 would otherwise make it
            # root-only inside the user's home. Paths resolve against the
            # entry config's directory and symlinks leaving it are rejected
            # -> copy, don't symlink.
            writeApiDae = pkgs.writeShellScript "honk-write-api-dae" ''
              set -eu
              cfgDir=${lib.escapeShellArg (builtins.dirOf cfg.configFile)}
              if [ ! -d "$cfgDir" ]; then
                echo "honk: config dir $cfgDir missing, skipping api.dae placement" >&2
              else
                if [ ! -d "$cfgDir/config.d" ]; then
                  ${pkgs.coreutils}/bin/mkdir -m 0755 "$cfgDir/config.d"
                  ${pkgs.coreutils}/bin/chown --reference="$cfgDir" "$cfgDir/config.d"
                  ${pkgs.coreutils}/bin/chmod --reference="$cfgDir" "$cfgDir/config.d"
                fi
                ${pkgs.coreutils}/bin/install -m 0644 ${apiDae} "$cfgDir/config.d/api.dae"
              fi
            '';

            # Module default (independent of ui): make sure the external
            # configFile carries `include { config.d/*.dae }` so drop-ins in
            # config.d/ are loaded. A zero-match glob is fine (honk's tests
            # cover missing dirs and unmatched patterns), so this stays safe
            # before config.d exists. Skips configs that set native_api
            # inline (a second definition would be rejected), and rewrites a
            # legacy `include { api.dae }` or a precise
            # `include { config.d/api.dae }` to the glob form. Runs on every
            # start (ExecStartPre) whenever an external configFile is set.
            #
            # Also enforces group write access: honk runs as root and its
            # native-API config_write replaces the file by rename, preserving
            # only the mode (never the owner), so after a doona save the main
            # config becomes root-owned. A setgid config dir + group-writable
            # mode keeps the config owner able to edit it: new files inherit
            # the dir's group and honk carries the 0664 mode through the
            # rename. config.d/api.dae stays excluded (module-managed).
            ensureInclude = pkgs.writeShellScript "honk-ensure-include" ''
              set -eu
              cfgDir=${lib.escapeShellArg (builtins.dirOf cfg.configFile)}
              mainConfig=${lib.escapeShellArg cfg.configFile}
              if [ ! -d "$cfgDir" ]; then
                echo "honk: config dir $cfgDir missing, skipping include wiring" >&2
              else
                ${pkgs.coreutils}/bin/chmod g+s,g+w "$cfgDir"
                if [ -d "$cfgDir/config.d" ]; then
                  ${pkgs.coreutils}/bin/chmod g+s,g+w "$cfgDir/config.d"
                  for dropIn in "$cfgDir"/config.d/*.dae; do
                    if [ -e "$dropIn" ] && [ "$dropIn" != "$cfgDir/config.d/api.dae" ]; then
                      ${pkgs.coreutils}/bin/chgrp --reference="$cfgDir" "$dropIn"
                      ${pkgs.coreutils}/bin/chmod g+rw "$dropIn"
                    fi
                  done
                fi
                if [ ! -f "$mainConfig" ]; then
                  echo "honk: $mainConfig missing, skipping include wiring" >&2
                else
                  ${pkgs.coreutils}/bin/chgrp --reference="$cfgDir" "$mainConfig"
                  ${pkgs.coreutils}/bin/chmod g+rw "$mainConfig"
                  if ${pkgs.gnugrep}/bin/grep -q 'native_api' "$mainConfig"; then
                    echo "honk: $mainConfig already sets native_api inline, not appending include" >&2
                  elif ${pkgs.gnugrep}/bin/grep -qF 'config.d/*.dae' "$mainConfig"; then
                    # covers the single-line and the pretty-printed multi-line form
                    :
                  elif ${pkgs.gnugrep}/bin/grep -qE '(^[[:space:]]*include[[:space:]]*[{][[:space:]]*(config\.d/api\.dae|api\.dae)|^[[:space:]]*(config\.d/api\.dae|api\.dae)[[:space:]]*$)' "$mainConfig"; then
                    owner=$(${pkgs.coreutils}/bin/stat -c %u:%g "$mainConfig")
                    mode=$(${pkgs.coreutils}/bin/stat -c %a "$mainConfig")
                    ${pkgs.gnused}/bin/sed -i -E \
                      -e 's#^[[:space:]]*include[[:space:]]*[{][[:space:]]*(config\.d/api\.dae|api\.dae).*#include {\n    config.d/*.dae\n}#' \
                      -e 's#^([[:space:]]*)(config\.d/api\.dae|api\.dae)[[:space:]]*$#\1config.d/*.dae#' \
                      "$mainConfig"
                    ${pkgs.coreutils}/bin/chown "$owner" "$mainConfig"
                    ${pkgs.coreutils}/bin/chmod "$mode" "$mainConfig"
                    ${pkgs.coreutils}/bin/rm -f "$cfgDir/api.dae"
                    echo "honk: normalized include to config.d/*.dae in $mainConfig" >&2
                  else
                    printf '\n# managed by NixOS (services.honk-core): drop-in includes\ninclude {\n    config.d/*.dae\n}\n' >> "$mainConfig"
                    echo "honk: appended include { config.d/*.dae } to $mainConfig" >&2
                  fi
                fi
              fi
            '';

            # Seed geo assets into the writable data dir. DAE_LOCATION_ASSET
            # points at /var/lib/honk, so honk loads these files and replaces
            # them in place on a geodata update — the store copy below is only
            # the first-run source and is never re-copied over a runtime
            # update. Assumes the default `global.data_dir` (/var/lib/honk).
            seedGeoAssets = pkgs.writeShellScript "honk-seed-geo-assets" ''
              set -eu
              state=/var/lib/honk
              src=${lib.escapeShellArg cfg.assetsPath}
              # Checked at start, not at eval: the default assetsPath points
              # into a built symlinkJoin, so pathExists in an assertion would
              # force the asset build during evaluation (breaking
              # `nix flake check --no-build` on a cold store).
              if [ ! -d "$src" ]; then
                echo "honk: assets path $src does not exist; set services.honk-core.assetsPath" >&2
                exit 1
              fi
              for name in geoip.dat geosite.dat; do
                if [ ! -e "$state/$name" ] && [ -e "$src/$name" ]; then
                  ${pkgs.coreutils}/bin/cp -L "$src/$name" "$state/$name"
                fi
              done
            '';
          in
          {
            packages = [ cfg.package ];

            services.honk = {
              description = "honk transparent proxy engine";
              wantedBy = [ "multi-user.target" ];
              wants = [ "network-online.target" ];
              after = [ "network-online.target" ];
              # Force a reload when the inline config text changes; external
              # configFile edits are picked up via `honk reload` manually.
              # With storeDb, the recorded revision overrides the file at
              # startup AND on reload: SIGHUP re-activates the active
              # revision, never the file. Imported content enters the db only
              # through the import API (doona's config import, replace: true)
              # or by activating a revision.
              reloadTriggers = optional (cfg.config != null) cfg.config;

              serviceConfig = {
                Type = "notify";
                ExecStartPre = [
                  ""
                ]
                ++ optional cfg.disableTxChecksumIpGeneric TxChecksumIpGenericWorkaround
                ++ [ seedGeoAssets ]
                ++ optional (cfg.ui != null && cfg.configFile != null) writeApiDae
                ++ optional (cfg.configFile != null) ensureInclude;
                ExecStart = [
                  ""
                  "${honkBin} -c ${configPath} --disable-timestamp"
                ]
                # db mode stores the administered .dae sources as revisions
                # in /var/lib/honk/state/honk.db (doona's import and
                # revisions need this); file mode keeps only export.
                ++ optional cfg.storeDb "--store db";
                # reload asks the running instance via /run/honk-core.lock and
                # ignores -c, so no configPath here.
                ExecReload = "${honkBin} reload";
                # Writable dir, not the store: honk must replace geo files in
                # place (updates via doona) and keep loading them after a
                # restart — a store path here makes every post-restart update
                # fail with EEXIST against the shadow copy.
                Environment = "DAE_LOCATION_ASSET=/var/lib/honk";
                TimeoutStartSec = 120;
                Restart = "on-failure";
                RestartSec = "2s";
                TimeoutStopSec = "30s";
                LimitNOFILE = 1048576;
                LimitMEMLOCK = "infinity";
                UMask = "0077";
                StateDirectory = "honk";
                ConfigurationDirectory = "honk";
              };
            };

            tmpfiles.rules = [ "d /etc/honk 0755 root root -" ];
          };

        assertions = [
          {
            assertion =
              let
                A = config.services.honk-core.config == null;
                B = config.services.honk-core.configFile == null;
              in
              (A && !B) || (!A && B); # xor
            message = ''
              Either `config` or `configFile` should be only set.
            '';
          }
        ];
      }
    ]
  );
}
