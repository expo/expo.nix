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
      options.expo.bun.enable = lib.mkEnableOption "bun project";
      config = lib.mkIf config.expo.bun.enable {
        # add bun to default devShell
        make-shells.default = {
          packages = [ pkgs.bun ];
        };
        # Update bun.lockb with new bun version whenever the flake is updated
        update.after.bash = "nix run .#bun-install";
        packages.bun-install = pkgs.writeShellApplication {
          name = "bun-install";
          runtimeInputs = [ pkgs.bun ];
          text = "bun install";
        };
      };
    }
  );
}
