{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.yarn-nixify.enable = lib.mkEnableOption "yarn-nixify helper";
  options.expo.yarn-nixify.supportedArchitectures = lib.mkOption {
    default = {
      os = [
        "darwin"
        "linux"
      ];
      cpu = [
        "arm64"
        "x64"
      ];
      libc = [
        "glibc"
        "musl"
      ];
    };
    type = lib.types.anything;
  };
  config =
    let
      cfg = config.expo.yarn-nixify;
    in
    lib.mkIf cfg.enable {
      packages = [
        (pkgs.writeShellApplication {
          name = "yarn-nixify";
          text = ''
            yarn plugin import https://raw.githubusercontent.com/stephank/yarn-plugin-nixify/main/dist/yarn-plugin-nixify.js
            yarn config set supportedArchitectures --json '${builtins.toJSON cfg.supportedArchitectures}'
            yarn install
          '';
          meta.description = "Configure yarn to explicitly support all platforms we run and build on.";
        })
      ];
    };
}
