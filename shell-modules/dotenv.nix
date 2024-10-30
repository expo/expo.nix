{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.dotenv = lib.mkOption {
    description = "Dotenv (.env) format files to evaluate and export into the shell environment";
    default = [ ];
    type = lib.types.listOf lib.types.pathInStore;
  };
  config = lib.mkIf (config.expo.dotenv != [ ]) {
    shellHook = lib.mkBefore (
      lib.strings.concatMapStringsSep "\n" (f: ''
        echo Dotenv: loading ${f}
        eval "$(${pkgs.direnv}/bin/direnv dotenv bash ${f})"
      '') config.expo.dotenv
    );
  };
}
