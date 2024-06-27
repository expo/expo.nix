{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.expo.aliases = lib.mkOption {
    type = lib.types.attrsOf lib.types.singleLineStr;
    default = { };
  };
  config.packages =
    let
      inherit (lib.attrsets) mapAttrsToList;
      alias =
        name: command:
        (pkgs.writeShellScriptBin name ''exec ${command} "$@"'')
        // {
          meta.description = "alias for '${command}'";
        };
    in
    mapAttrsToList alias config.expo.aliases;
}
