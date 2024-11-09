{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.yarn-nixify.enable = lib.mkEnableOption "yarn-nixify helper";
  config = lib.mkIf config.expo.yarn-nixify.enable {
    packages = [
      (pkgs.writeShellApplication {
        name = "yarn-nixify";
        text = ''
          yarn plugin import https://raw.githubusercontent.com/stephank/yarn-plugin-nixify/main/dist/yarn-plugin-nixify.js
          yarn config set supportedArchitectures --json '{"os":["darwin","linux"],"cpu":["arm64","x64"],"libc":["current"]}'
          yarn install
        '';
        meta.description = "Configure yarn to explicitly support all platforms we run and build on.";
      })
    ];
  };
}
