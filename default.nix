{ pkgs ? import <nixpkgs> { }, port ? 4000, branch, commit, ... }:
let
  beamPackages = pkgs.beamPackages;
  inherit (beamPackages) mixRelease;
in 
mixRelease rec {
  pname = "inspection_${env}";
  mixReleaseName = pname;
  version = "0.0.1";
  mixEnv = env;
  removeCookie = false;
  nativeBuildInputs = with pkgs; [ esbuild ];
  erlangDeterministicBuilds = false;

  PORT = "${toString (port)}";
  RELEASE_COOKIE = "my_cookie_AOEUSNTAHO_AOE_UAO_NETUAOE_UAOEUH";
  SECRET_KEY_BASE =
    "GyZeSEliuuBOLha18lsCxUM//HhlJlOk3E5QGNU07BZ4fIVdQBAaISPEztAAWxUp";

  src = builtins.fetchGit {
    url = "git@gitlab.com:Zurga/inspection.git";
    # rev = "f106426b862899556c422e167a8324606ed4112c";
    rev = commit;
    ref = branch;
  };


  mixNixDeps = import "${src}/mix.nix" {
    inherit (pkgs) lib;
    inherit beamPackages;
    overrides = final: prev: {
      ecto = beamPackages.buildMix {
        name = "ecto";
        version = "3.11.2";
        src = builtins.fetchGit {
          url = "git@github.com:Zurga/ecto.git";
          ref = "has_many_as_3.11.2";
        };

        beamDeps = with final; [ telemetry decimal jason];
      };

      ex_cldr_territories =
        prev.ex_cldr_territories.override { mixEnv = "dev"; };

      vix = prev.vix.override {
        buildInputs = [ pkgs.vips pkgs.pkg-config ];
        preBuild = ''
          export VIX_COMPILATION_MODE="PLATFORM_PROVIDED_LIBVIPS"
          export ELIXIR_MAKE_CACHE_DIR="$TEMPDIR/cache"
        '';
      };
    };
  };

  nodeDependencies =
    (pkgs.callPackage "${src}/assets/default.nix" { }).shell.nodeDependencies;

  postBuild = ''
    ln -sf ${nodeDependencies}/lib/node_modules assets/node_modules

    cp ${pkgs.esbuild}/bin/esbuild _build/esbuild-linux-x64

    # for external task you need a workaround for the no deps check flag
    # https://github.com/phoenixframework/phoenix/issues/2690
    mix do deps.loadpaths --no-deps-check, assets.deploy
  '';
}

