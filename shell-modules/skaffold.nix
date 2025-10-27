{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.skaffold.enable = lib.mkEnableOption "Skaffold and some related tools, for building and deploying docker images";
  config = lib.mkIf config.expo.skaffold.enable { packages = [ pkgs.skaffold ]; };
}
