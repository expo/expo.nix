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
        make-shells.default = {
          packages = [ pkgs.skaffold ];
        };
        # Update skaffold.yaml with new skaffold version whenever the flake is updated
        update.after.bash = "nix run ./#skaffold-fix";
        packages.skaffold-fix = pkgs.writeShellApplication {
          name = "skaffold-fix";
          runtimeInputs = [ pkgs.skaffold ];
          text = "skaffold fix --output skaffold.yaml";
        };
      };
    }
  );
}
