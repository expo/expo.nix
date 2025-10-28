{ flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.expo.skaffold.enable = lib.mkEnableOption "skaffold project";
      config = lib.mkIf config.expo.skaffold.enable {
        # Add skaffold to default devShell
        make-shells.default.expo.skaffold.enable = true;
        treefmt.settings.formatter.skaffold-fix = {
          command = "${pkgs.bash}/bin/bash";
          options = [
            "-euc"
            ''
              for file in "$@"; do
                ${pkgs.skaffold}/bin/skaffold fix --filename "$file" --output "$file"
              done
            ''
            "--" # bash swallows the second argument when using -c
          ];
          includes = [ "skaffold.yaml" ];
        };
      };
    }
  );
}
