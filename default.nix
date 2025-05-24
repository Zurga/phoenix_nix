{ pkgs ? import <nixpkgs> { }, lib, port ? 4000, appName, branch, commit ? "", ... }:
let
  beamPackages = pkgs.beamPackages;
  inherit (beamPackages) mixRelease;
in 
mixRelease rec {
  pname = appName;
  mixReleaseName = pname;
  version = "0.0.1";
  removeCookie = false;
  nativeBuildInputs = with pkgs; [ esbuild ];
  erlangDeterministicBuilds = false;

  PORT = "${toString (port)}";
  RELEASE_COOKIE = "my_cookie_AOEUSNTAHO_AOE_UAO_NETUAOE_UAOEUH";
  SECRET_KEY_BASE = "GyZeSEliuuBOLha18lsCxUM//HhlJlOk3E5QGNU07BZ4fIVdQBAaISPEztAAWxUp";

  src = builtins.fetchGit  {
    url = "git@gitlab.com:Zurga/inspection.git";
    rev = "f106426b862899556c422e167a8324606ed4112c";
    ref = branch;
  };

  mixNixDeps = import "${src}/mix.nix" {
    inherit (pkgs) lib;
    inherit beamPackages;
    overrides = final: prev: {
    };
  };

  # nodeDependencies =
  #   (pkgs.callPackage "${src}/assets/default.nix" { }).shell.nodeDependencies;

  # postBuild = ''
  #   ln -sf ${nodeDependencies}/lib/node_modules assets/node_modules

  #   cp ${pkgs.esbuild}/bin/esbuild _build/esbuild-linux-x64

  #   # for external task you need a workaround for the no deps check flag
  #   # https://github.com/phoenixframework/phoenix/issues/2690
  #   mix do deps.loadpaths --no-deps-check, assets.deploy
  # '';
}

