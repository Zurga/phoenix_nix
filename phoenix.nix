{ pkgs ? import <nixpkgs> { }, lib, appName, config, package, ... }:
with lib;
let
  cfg = config.services.${appName};
  releaseName = env: "${appName}_${env}";
  workingDirectory = env: "/home/${releaseName env}";
  applyConfig = function:
    mkMerge
    (mapAttrsToList (env: envConfig: function env envConfig) cfg.environments);

  nginxHosts = env: envConfig:
    let
      port = toString envConfig.port;
      host = toString envConfig.host;
    in {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;
      virtualHosts = {
        "${host}" = {
          addSSL = envConfig.ssl;
          enableACME = envConfig.ssl;
          locations = {
            "/" = {
              proxyPass = "http://0.0.0.0:${port}";
              recommendedProxySettings = true;
              proxyWebsockets = true;
            };
            "/uploads/" = { alias = "${workingDirectory env}/uploads/"; };
          };
        };
      };
    };

  postgresDatabases = env: envConfig: {
    enable = true;
    ensureDatabases = [ (releaseName env) ];
    ensureUsers = [{
      name = (releaseName env);
      ensureDBOwnership = true;
    }];
  };
  tmpFiles = env: envConfig:
    [ "d ${workingDirectory env}/uploads 0755 ${(releaseName env)} uploads -" ];

  users = env: envConfig: {
    "${(releaseName env)}" = {
      isNormalUser = true;
      home = workingDirectory env;
      extraGroups = [ "uploads" ];
      homeMode = "755";
    };
  };

  serviceDescription = env: envConfig:
    let
      port = toString envConfig.port;
      releaseTmp = "RELEASE_TMP='${workingDirectory env}'";
      workDir = workingDirectory env;
      envReleaseName = releaseName env;
      seedFlagPath = "${workDir}/seed.done";
      PhoenixService =  "${envReleaseName}.service";
      seedService = "${envReleaseName}_seed.service";
      migrationService =  "${envReleaseName}_migration.service";
      path = [ pkgs.bash ] ++ (if envConfig.runtimePackages != [] then envConfig.runtimePackages else cfg.runtimePackages );
      environment = [
        "DATABASE=${envReleaseName}"
        "PORT=${port}"
        "SECRET_KEY_BASE=${envConfig.secretKeyBase}"
        releaseTmp
        "RELEASE_COOKIE=${envConfig.releaseCookie}"
      ];
      release = pkgs.callPackage package {
        inherit lib;
        branch = env;
        appName = envReleaseName;
        commit = envConfig.commit;
        port = port;
        env = env;
      };
    in {
      "${envReleaseName}_migration" = {
        inherit path;
        unitConfig = {
          Description = "${release.pname} ${env} migrator";
          PartOf = [PhoenixService];
          Requires = ["postgresql.service"  seedService ];
          After = ["postgresql.service"  seedService];
        };
        serviceConfig = {
          ExecStart = ''
            ${release}/bin/${appName} eval "${envConfig.migrateCommand}"
          '';
          User = envReleaseName;
          Group = "users";
          Type = "oneshot";
          WorkingDirectory = workDir;
          Environment = environment;
        };
      };
      "${envReleaseName}_seed" = {
        inherit path;
        before = [migrationService PhoenixService];
        unitConfig = {
          ConditionPathExists = "!${seedFlagPath}";
          Description = "${release.pname} ${env} seeder";
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = envReleaseName;
          Group = "users";
          ExecStart = ''
            ${release}/bin/${appName} eval "${envConfig.seedCommand}"; touch ${seedFlagPath}
          '';
          WorkingDirectory = workDir;
          Environment = environment;
        };
      };

      "${envReleaseName}" = {
        inherit path;
        wantedBy = [ "multi-user.target" ];
        # enable = true;
        # note that if you are connecting to a postgres instance on a different host
        # postgresql.service should not be included in the requires.
        # Unit.Requires = [ "network-online.target" "postgresql.service" ];
        unitConfig = {
          Description = "${release.pname} ${env}";
          # equires bash
          Requires = [ seedService migrationService ];
          After = [ seedService migrationService ];
          StartLimitInterval = 10;
        };
        serviceConfig = {
          Type = "exec";
          ExecStart = "${release}/bin/${appName} start";
          ExecStop = "${release}/bin/${appName} stop";
          ExecReload = "${release}/bin/${appName} reload";
          User = envReleaseName;
          Group = "users";
          Restart = "on-failure";
          RestartSec = 5;
          StartLimitBurst = 3;
          WorkingDirectory = workDir;
          Environment = environment;
        };
      };
    };
runtimePackages = mkOption {
  type = types.listOf types.package;
  default = [];
  description = "The list of packages to include in the service"; 
};
seedCommand = mkOption {
  type = types.str;
  default = "${appName}.Release.seed";
  description = "The command to run when seeding the database";
};
migrateCommand = mkOption {
  type = types.str;
  default = "${appName}.Release.migrate";
  description = "The command to run when migrating the database";
};
in {
  options = appName:
    with types; {
      inherit seedCommand migrateCommand runtimePackages;
      enable = mkEnableOption "${release.pname} service";
      environments = mkOption {
        type = attrsOf (submodule {
          options = {
            inherit seedCommand migrateCommand runtimePackages;
            port = mkOption {
              type = port;
              default = 4000;
              description = "The port on which this service will listen";
            };
            ssl = mkEnableOption "Whether to use SSL or not";
            host = mkOption {
              type = str;
              description = "The host for this environment";
            };
            branch = mkOption {
              type = str;
              description = "The branch to use for this environment, will default to the environment name";
            };
            commit = mkOption {
              type = str;
              default = "";
              description = "The commit to deploy for this environment";
            };
            secretKeyBase = mkOption {
              type = str;
              default = "YOUR_SUPER_SECRET_KEYBASE_THAT_YOU_SHOULD_CHANGE";
              description = "Secret keybase to use with Phoenix";
            };
            releaseCookie = mkOption {
              type = str;
              default = "YOUR_SUPER_SECRET_COOKIE_THAT_YOU_SHOULD_CHANGE";
              description = "Release cookie to use with Phoenix";
            };
          };
        });
      };
    };
  services = applyConfig serviceDescription;
  rules = applyConfig tmpFiles;
  users = applyConfig users;
  nginx = applyConfig nginxHosts;
  postgresql = applyConfig postgresDatabases;
}
