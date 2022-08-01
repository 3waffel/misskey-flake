{
  config,
  lib,
  pkgs,
  misskey,
  ...
}:
with lib; let
  cfg = config.services.misskey;
  settingsFormat = pkgs.formats.yaml {};
  generatedConfig = settingsFormat.generate "default.yml" cfg.settings;
in {
  options.services.misskey = {
    enable = mkEnableOption "misskey";

    package = mkOption {
      type = types.package;
      default = misskey;
      description = "Misskey package to use. By default, this is the flake's Misskey package.";
    };

    settings = mkOption {
      type = lib.types.submodule {
        freeformType = settingsFormat.type;

        options = {
          url = mkOption {
            type = types.str;
            example = "https://misskey.example.com/";
            description = "Base URL of the Misseky instance.";
          };

          port = mkOption {
            type = types.int;
            default = 3000;
            description = "Port the Misskey daemon will listen on.";
          };

          db = {
            host = mkOption {
              type = types.str;
              default = "/run/postgresql";
              description = "Postgresql host to connect to.";
            };

            port = mkOption {
              type = types.int;
              default = config.services.postgresql.port;
              description = "Port of the database to connect to.";
            };

            db = mkOption {
              type = types.str;
              default = "misskey";
              description = "Name of the database that Misskey will use.";
            };

            user = mkOption {
              type = types.str;
              default = "misskey";
              description = "Name of the database user.";
            };

            pass = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                Password for connecting to the database. Will be stored in plain text
                in the Nix store; to avoid, use <option>database.passwordFile</option>
                instead.
              '';
            };
          };

          redis = {
            host = mkOption {
              type = types.str;
              default = "localhost";
              description = "Redis host to connect to.";
            };

            port = mkOption {
              type = types.int;
              default = config.services.redis.servers.misskey.port;
              description = "Redis port to connect to.";
            };
          };

          id = mkOption {
            type = types.enum ["aid" "meid" "ulid" "objectid"];
            default = "aid";
            description = ''
              ID generation method. Should not tbe changed after database is initalized.
            '';
          };

          filesPath = mkOption {
            type = types.str;
            default = "/var/lib/misskey/files";
            description = "Path to the directory in which Misskey will store media files and uploads.";
          };
        };
      };

      default = {};

      description = ''
        Misskey configuration. See <link xlink:href="https://github.com/misskey-dev/misskey/blob/develop/.config/example.yml">
        for an example configuration.
      '';
    };

    redis = {
      createLocally = mkOption {
        type = types.bool;
        default = true;
        description = "Ensure Redis is running locally and use it.";
      };
    };
  };

  config = mkIf cfg.enable {
    services.redis.servers.misskey = optionalAttrs cfg.redis.createLocally {
      enable = true;
    };

    systemd.services.misskey = {
      after = ["network-online.target" "postgresql.service"];
      wantedBy = ["multi-user.target"];
      environment.NODE_ENV = "production";

      preStart = ''
        ${pkgs.envsubst}/bin/envsubst -i "${generatedConfig}" > /run/misskey/default.yml
        cd ${misskey}/packages/backend
        ./node_modules/.bin/typeorm migration:run
      '';

      serviceConfig = {
        StateDirectory = "misskey";
        StateDirectoryMode = "700";
        RuntimeDirectory = "misskey";
        RuntimeDirectoryMode = "700";
        ExecStart = "${pkgs.nodejs}/bin/node --experimental-json-modules ${misskey}/packages/backend/built/index.js";
        TimeoutSec = 240;

        DynamicUser = true;
        LockPersonality = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectProc = "invisible";
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX AF_NETLINK";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service";
        UMask = "0077";
      };
    };
  };
}
