{
  config,
  lib,
  pkgs,
  utils,
  ...
}:
let
  inherit (lib) maintainers;
  inherit (lib.meta) getExe;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options)
    literalExpression
    mkEnableOption
    mkOption
    mkPackageOption
    ;
  inherit (lib.types)
    bool
    enum
    nullOr
    port
    str
    submodule
    ;
  inherit (utils) genJqSecretsReplacementSnippet;

  cfg = config.services.scrutiny;
  # Define the settings format used for this program
  settingsFormat = pkgs.formats.yaml { };
in
{
  options = {
    services.scrutiny = {
      enable = mkEnableOption "Scrutiny, a web application for drive monitoring";

      package = mkPackageOption pkgs "scrutiny" { };

      openFirewall = mkEnableOption "opening the default ports in the firewall for Scrutiny";

      influxdb.enable = mkOption {
        type = bool;
        default = true;
        description = ''
          Enables InfluxDB on the host system using the `services.influxdb2` NixOS module
          with default options.

          If you already have InfluxDB configured, or wish to connect to an external InfluxDB
          instance, disable this option.
        '';
      };

      settings = mkOption {
        description = ''
          Scrutiny settings to be rendered into the configuration file.

          See <https://github.com/AnalogJ/scrutiny/blob/master/example.scrutiny.yaml>.

          Options containing secret data should be set to an attribute set
          containing the attribute `_secret`. This attribute should be a string
          or structured JSON with `quote = false;`, pointing to a file that
          contains the value the option should be set to.
        '';
        default = { };
        type = submodule {
          freeformType = settingsFormat.type;

          options.web.listen.port = mkOption {
            type = port;
            default = 8080;
            description = "Port for web application to listen on.";
          };

          options.web.listen.host = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "Interface address for web application to bind to.";
          };

          options.web.listen.basepath = mkOption {
            type = str;
            default = "";
            example = "/scrutiny";
            description = ''
              If Scrutiny will be behind a path prefixed reverse proxy, you can override this
              value to serve Scrutiny on a subpath.
            '';
          };

          options.log.level = mkOption {
            type = enum [
              "INFO"
              "DEBUG"
            ];
            default = "INFO";
            description = "Log level for Scrutiny.";
          };

          options.web.influxdb.scheme = mkOption {
            type = str;
            default = "http";
            description = "URL scheme to use when connecting to InfluxDB.";
          };

          options.web.influxdb.host = mkOption {
            type = str;
            default = "0.0.0.0";
            description = "IP or hostname of the InfluxDB instance.";
          };

          options.web.influxdb.port = mkOption {
            type = port;
            default = 8086;
            description = "The port of the InfluxDB instance.";
          };

          options.web.influxdb.tls.insecure_skip_verify =
            mkEnableOption "skipping TLS verification when connecting to InfluxDB";

          options.web.influxdb.token = mkOption {
            type = nullOr str;
            default = null;
            description = "Authentication token for connecting to InfluxDB.";
          };

          options.web.influxdb.org = mkOption {
            type = nullOr str;
            default = null;
            description = "InfluxDB organisation under which to store data.";
          };

          options.web.influxdb.bucket = mkOption {
            type = nullOr str;
            default = null;
            description = "InfluxDB bucket in which to store data.";
          };
        };
      };

      collector = {
        enable = mkEnableOption "the Scrutiny metrics collector" // {
          default = cfg.enable;
          defaultText = lib.literalExpression "config.services.scrutiny.enable";
        };

        package = mkPackageOption pkgs "scrutiny-collector" { };

        schedule = mkOption {
          type = str;
          default = "daily";
          description = ''
            How often to run the collector in systemd calendar format.
          '';
        };

        settings = mkOption {
          description = ''
            Collector settings to be rendered into the collector configuration file.

            See <https://github.com/AnalogJ/scrutiny/blob/master/example.collector.yaml>.

            Options containing secret data should be set to an attribute set
            containing the attribute `_secret`. This attribute should be a string
            or structured JSON with `quote = false;`, pointing to a file that
            contains the value the option should be set to.
          '';
          default = { };
          type = submodule {
            freeformType = settingsFormat.type;

            options.host.id = mkOption {
              type = nullOr str;
              default = null;
              description = "Host ID for identifying/labelling groups of disks";
            };

            options.api.endpoint = mkOption {
              type = str;
              default = "http://${cfg.settings.web.listen.host}:${toString cfg.settings.web.listen.port}${cfg.settings.web.listen.basepath}";
              defaultText = literalExpression ''"http://''${config.services.scrutiny.settings.web.listen.host}:''${config.services.scrutiny.settings.web.listen.port}''${config.services.scrutiny.settings.web.listen.basepath}"'';
              description = "Scrutiny app API endpoint for sending metrics to.";
            };

            options.log.level = mkOption {
              type = enum [
                "INFO"
                "DEBUG"
              ];
              default = "INFO";
              description = "Log level for Scrutiny collector.";
            };
          };
        };
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.influxdb2.enable = cfg.influxdb.enable;

      networking.firewall = mkIf cfg.openFirewall {
        allowedTCPPorts = [ cfg.settings.web.listen.port ];
      };

      systemd.services.scrutiny = {
        description = "Hard Drive S.M.A.R.T Monitoring, Historical Trends & Real World Failure Thresholds";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ] ++ lib.optional cfg.influxdb.enable "influxdb2.service";
        wants = lib.optional cfg.influxdb.enable "influxdb2.service";
        environment = {
          SCRUTINY_VERSION = "1";
          SCRUTINY_WEB_DATABASE_LOCATION = "/var/lib/scrutiny/scrutiny.db";
          SCRUTINY_WEB_SRC_FRONTEND_PATH = "${cfg.package}/share/scrutiny";
        };
        preStart = ''
          ${genJqSecretsReplacementSnippet cfg.settings "/run/scrutiny/config.yaml"}
        '';
        postStart = ''
          for i in $(seq 300); do
              if "${lib.getExe pkgs.curl}" --fail --silent --head "http://${cfg.settings.web.listen.host}:${toString cfg.settings.web.listen.port}" >/dev/null; then
                  echo "Scrutiny is ready (port is open)"
                  exit 0
              fi
              echo "Waiting for Scrutiny to open port..."
              sleep 0.2
          done
          echo "Timeout waiting for Scrutiny to open port" >&2
          exit 1
        '';
        serviceConfig = {
          DynamicUser = true;
          ExecStart = "${getExe cfg.package} start --config /run/scrutiny/config.yaml";
          Restart = "always";
          RuntimeDirectory = "scrutiny";
          RuntimeDirectoryMode = "0700";
          StateDirectory = "scrutiny";
          StateDirectoryMode = "0750";
        };
      };
    })
    (mkIf cfg.collector.enable {
      services.smartd = {
        enable = true;
        extraOptions = [
          "-A /var/log/smartd/"
          "--interval=600"
        ];
      };

      systemd = {
        services.scrutiny-collector = {
          description = "Scrutiny Collector Service";
          after = lib.optional cfg.enable "scrutiny.service";
          wants = lib.optional cfg.enable "scrutiny.service";
          environment = {
            COLLECTOR_VERSION = "1";
            COLLECTOR_API_ENDPOINT = cfg.collector.settings.api.endpoint;
          };
          preStart = ''
            ${genJqSecretsReplacementSnippet cfg.collector.settings "/run/scrutiny-collector/config.yaml"}
          '';
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${getExe cfg.collector.package} run --config /run/scrutiny-collector/config.yaml";
            RuntimeDirectory = "scrutiny-collector";
            RuntimeDirectoryMode = "0700";
          };
          startAt = cfg.collector.schedule;
        };

        timers.scrutiny-collector.timerConfig.Persistent = true;
      };
    })
  ];

  meta.maintainers = [ maintainers.jnsgruk ];
}
