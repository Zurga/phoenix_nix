let
  pkgs = import <nixpkgs> {};
in
  pkgs.testers.runNixOSTest {
  name = "phoenix-nix-test";
  nodes = {
    machine1 = {lib, pkgs, nodes, ...}: {
      imports = [ ./service.nix ];
      services.phoenixTest = {
        enable = true;
        migrateCommand = "PhoenixTest.Release.migrate";
        seedCommand = "PhoenixTest.Release.seed";
        environments = {
          prod = {
            host = "localhost";
            ssl = false;
            port = 5000;
          };
        };
      };
    };
  };   
  testScript = ''
  machine1.start()
  '';
}
