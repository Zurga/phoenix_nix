let
  pkgs = import <nixpkgs> {};
in
  pkgs.testers.runNixOSTest {
  name = "phoenix-nix-test";
  nodes = {
    vm = {lib, pkgs, nodes, ...}: {
      imports = [ ./service.nix ];
      services.phoenix_test = {
        enable = true;
        migrateCommand = "PhoenixTest.Release.migrate";
        seedCommand = "PhoenixTest.Release.seed";
        environments = {
          prod = {
            host = "localhost";
            ssl = false;
            port = 5000;
            migrateCommand = "PhoenixTest.Release.migrate";
            seedCommand = "PhoenixTest.Release.seed";
            runtimePackages = with pkgs; [curl];
          };
        };
      };
    };
  };   
  testScript = ''
    vm.start()
    print(vm.execute("ls /etc/systemd/system/"))
    vm.wait_for_unit("phoenix_test_prod_seed")
    vm.wait_for_unit("phoenix_test_prod")
    vm.shell_interact()          # Open an interactive shell in the VM (drop-in login shell)
  '';
}
