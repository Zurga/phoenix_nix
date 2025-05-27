# Nix module to setup Phoenix

This repo contains a nixos module definition for setting up Phoenix servers.
Alongside there are two example files that can be used as templates in a Phoenix project.

## Usage
### Set up `default.nix` 
This is where your project will get built. Set the `src` attribute to point to the correct git repository.
Any extra dependencies should go here alongside `mix.nix`.

### Change `service.nix`
This will include the `phoenix.nix` and make the `services.my-app` module available. To use it, edit this line to contain the name of you app.:
```
  appName = "CHANGE ME";
```

### Change `config/runtime.exs` 
Phoenix_nix assumes that the database is setup using a UNIX socket. The Repo setup in `config/runtime.exs` should be similar to this:
```
...
if config_env() == :prod do
  database =
    System.get_env("DATABASE") ||
      raise """
      environment variable DATABASE is missing.
      For example: my_database
      """

  config :phoenix_test, PhoenixTest.Repo,
    hostname: "/run/postgresql",
    port: 5432,
    socket_dir: "/run/postgresql",
    database: database,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
...
```

### Configuring the environments
Let's assume that the Phoenix app is called `phoenix-test`, in your `configuration.nix` you can now add the following:
```
services.phoenix-test = {
  enable = true
  environments = {
    prod = {
      branch = "main";
      commit = "commit-sha";     
      host = example.com;
      ssl = true;
      port = 5000;
      migrateCommand = "PhoenixTest.Release.migrate";
      seedCommand = "PhoenixTest.Release.seed";
      runtimePackages = with pkgs; [ mogrify ];
      secretKeyBase = "aQXmDHnmezs7x5NRsQWOg7MDf0GpqOP1FWPNGJzeueqk+zNCq+PJN+yWLiNfNhWe"; # You should probably use sops-nix or agenix for this
      releaseCookie = "aQXmDHnmezs7x5NRsQWOg7MDf0GpqOP1FWPNGJzeueqk+zNCq+PJN+yWLiNfNhWe"; # You should probably use sops-nix or agenix for this
    };
  };
};
```
This will setup three services: `phoenix-test_prod_seed.service`, `phoenix-test_migration.service`, `phoenix-test_prod.service`.
It will also create a user with the name `phoenix-test_prod`, and a database with the same name. Then it will create an nginx proxy config for the host and setup the LetsEncrypt certificates.
