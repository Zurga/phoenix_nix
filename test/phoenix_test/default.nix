{ pkgs ? import <nixpkgs> { }, port ? 4000, appName, branch ? "main", commit ? "", ... }:
let
  beamPackages = pkgs.beamPackages;
  fs = pkgs.lib.fileset;
  inherit (beamPackages) mixRelease;
  heroicons = pkgs.stdenv.mkDerivation {
    name = "heroicons";
    version = "2.2.1";
    src = builtins.fetchGit {
      url = "git@github.com:tailwindlabs/heroicons";
      rev = "88ab3a0d790e6a47404cba02800a6b25d2afae50";
    };
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r ./* $out
      runHook postInstall
    '';
  };
in 
mixRelease rec {
  pname = appName;
  # mixReleaseName = pname;
  version = "0.0.1";
  removeCookie = false;
  nativeBuildInputs = with pkgs; [ esbuild tailwindcss_3 ];
  erlangDeterministicBuilds = false;

  PORT = "${toString (port)}";
  RELEASE_COOKIE = "SUPER_SECRET_SECRET_COOKIE";
  SECRET_KEY_BASE = "SUPER_SECRET_SECRET_KEYBASE";

  src = fs.toSource {
    root = ./.;
    fileset = fs.unions [
      ./_build/tailwind-linux-x64
    (fs.difference ./. ( fs.unions [ (fs.maybeMissing ./result) ./deps ./_build ]))
    ];
  };

  mixNixDeps = import "${src}/mix.nix" {
    inherit (pkgs) lib;
    inherit beamPackages;
    overrides = final: prev: {  };
  };

  # nodeDependencies =
  #   (pkgs.callPackage "${src}/assets/default.nix" { }).shell.nodeDependencies;

  # ln -sf ${nodeDependencies}/lib/node_modules assets/node_modules
  postBuild = ''
    cp ${src}/_build/tailwind-linux-x64 _build/tailwind-linux-x64
    cp ${pkgs.esbuild}/bin/esbuild _build/esbuild-linux-x64
    mkdir -p ./deps/heroicons
    cp -r ${heroicons}/* ./deps/heroicons/

    # for external task you need a workaround for the no deps check flag
    # https://github.com/phoenixframework/phoenix/issues/2690
    mix do deps.loadpaths --no-deps-check, assets.deploy
  '';
}

