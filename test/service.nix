{ config, lib, ... }:
let
  appName = "phoenix_test";

  phoenixService = import ../phoenix.nix {
    inherit lib config appName;
    package = ./phoenix_test/default.nix;
  };
in {
  options.services."${appName}" = phoenixService.options appName;
  config = lib.mkIf config.services."${appName}".enable {
    systemd.services = phoenixService.services;
    systemd.tmpfiles.rules = phoenixService.rules;
    users.users = phoenixService.users;
    services.nginx = phoenixService.nginx;
    services.postgresql = phoenixService.postgresql;
  };
}
