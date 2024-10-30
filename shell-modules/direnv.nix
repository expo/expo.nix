{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.direnv.exec = lib.mkOption {
    description = "A folder containing an .envrc file to evaluate and export into the shell environment";
    default = null;
    type = lib.types.nullOr lib.types.nonEmptyStr;
  };
  config =
    let
      cfg = config.expo.direnv;
    in
    lib.mkIf (cfg.exec != null) {
      shellHook = lib.mkBefore ''
        pushd ${cfg.exec} || exit 1
        ${pkgs.direnv}/bin/direnv allow
        eval "$(${pkgs.direnv}/bin/direnv export bash)"
        popd || exit 1
      '';
    };
}
