self:
{ config, lib, pkgs, ... }:
let
  cfg = config.services.wg-homepage;
in
{
  options.services.wg-homepage = {
    enable = lib.mkEnableOption "wg-homepage service";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9001;
      description = "Port to listen on";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address to bind to";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "wg-homepage";
      description = "User account under which wg-homepage runs";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "wg-homepage";
      description = "Group under which wg-homepage runs";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wg-homepage;
      defaultText = lib.literalExpression "pkgs.wg-homepage";
      description = "The wg-homepage package to use";
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ self.overlays.default ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      description = "wg-homepage service user";
    };

    users.groups.${cfg.group} = {};

    security.sudo.extraRules = [
      {
        users = [ cfg.user ];
        commands = [
          {
            command = "${pkgs.wireguard-tools}/bin/wg";
            options = [ "NOPASSWD" ];
          }
        ];
      }
    ];

    systemd.services.wg-homepage = {
      description = "WG Homepage Service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/wg-homepage";
        Restart = "on-failure";
        RestartSec = "5s";

        PrivateTmp = true;
        ProtectSystem = "struct";
        ProtectHome = true;
        ReadWritePaths = [ ];
      };

      environment = {
        PATH = lib.mkForce "/run/wrappers/bin:${lib.makeBinPath [ pkgs.wireguard-tools ]}";
        HOST = cfg.host;
        PORT = toString cfg.port;
      };
    };
  };
}