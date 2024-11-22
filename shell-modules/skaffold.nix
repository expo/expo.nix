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
      pkgs.skaffold
      (pkgs.writeShellApplication {
        name = "skaffold-buildx-build";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.docker-client
          pkgs.google-cloud-sdk
          pkgs.jq
        ];
        text = builtins.readFile ../skaffold-buildx-build.sh;
        meta.description = "A custom image build script for skaffold which uses 'docker buildx'";
      })
    ];
  };
}
