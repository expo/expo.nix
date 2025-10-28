{
  inputs = {
    expo-nix.url = "..";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.expo-nix.flakeModules.default ];
      perSystem = {
        treefmt = {
          programs = {
            shellcheck.enable = true;
            shfmt.enable = true;
            yamlfmt.enable = true;
            actionlint.enable = true;
          };
          projectRoot = inputs.expo-nix;
          settings.formatter.shellcheck.options = [ "-x" ];
        };
      };
    };
}
