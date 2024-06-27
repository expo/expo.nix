{
  inputs = {
    javascript-nix.url = "github:nicknovitski/javascript-nix";
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
              # Permit installing certain packages with unfree software licenses
              _module.args.pkgs = import inputs.nixpkgs {
                inherit system;
                config = {
                  allowUnfreePredicate =
                    pkg:
                    builtins.elem (lib.getName pkg) [
                      "graphite-cli"
                      "terraform"
                    ];
                };
              };
              # enable `nix fmt` command
              formatter = pkgs.nixfmt-rfc-style;
            };
        };
    };
}
