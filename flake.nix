{
  inputs = {
    javascript-nix.url = "github:nicknovitski/javascript-nix/v1";
    make-shell.url = "github:nicknovitski/make-shell";
    update-flake.url = "github:nicknovitski/update-flake";
    gcloud-nix.url = "github:nicknovitski/gcloud-nix/v1";
  };

  outputs =
    {
      gcloud-nix,
      javascript-nix,
      make-shell,
      update-flake,
      ...
    }:
    {
      flakeModules.default =
        {
          inputs,
          lib,
          ...
        }:
        {
          imports = [
            make-shell.flakeModules.default
            update-flake.flakeModules.default
            ./flake-modules
          ];
          # Default supported systems
          systems = [
            "aarch64-darwin" # Apple Silicon Laptops
            "aarch64-linux" # Devcontainers
            "x86_64-linux" # Cloud Services
          ];
          perSystem =
            {
              pkgs,
              system,
              ...
            }:
            {
              # add expo options and defaults to all shells
              make-shell.imports = [
                gcloud-nix.shellModules.default
                javascript-nix.shellModules.default
                ./shell-modules
              ];
              # create update-flake package
              update.enable = true;
              _module.args.pkgs = import inputs.nixpkgs {
                inherit system;
                # Permit installing certain packages with unfree software licenses
                config.allowUnfreePredicate =
                  pkg:
                  builtins.elem (lib.getName pkg) [
                    "graphite-cli"
                    "terraform"
                  ];
                overlays = [
                  (final: prev: {
                    lib = prev.lib.recursiveUpdate prev.lib {
                      fileset =
                        let
                          fs = prev.lib.fileset;
                        in
                        {
                          byRegex = root: regexes: fs.fromSource (prev.lib.sources.sourceByRegex root regexes);
                          excludeByRegex = root: excludes: fs.difference root (final.lib.fileset.byRegex root excludes);
                        };

                    };
                  })
                ];
              };
              # enable `nix fmt` command
              formatter = pkgs.nixfmt-rfc-style;
            };
        };
    };
}
