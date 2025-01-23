{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.skaffold.enable = lib.mkEnableOption "Skaffold and some related tools, for building and deploying docker images";
  config = lib.mkIf config.expo.skaffold.enable {
    packages = [
      (pkgs.skaffold.overrideAttrs {
        version = "2.14.0";
        src = pkgs.fetchFromGitHub {
          owner = "GoogleContainerTools";
          repo = "skaffold";
          rev = "v2.14.0";
          hash = "sha256-pr9PFdTMr7tIWj87OKzY5tu7sRVjIv+vhp18dRzN5E8=";
        };
      })
    ];
  };
}
