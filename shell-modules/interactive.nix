{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkAfter
    mkIf
    mkOption
    types
    ;
in
{
  options.interactiveShellHook = mkOption {
    default = "";
    description = "Bash code evaluated when the shell environment starts, either in an interactive context or when `nix-direnv-reload` has been called.";
    type = types.lines;
  };
  config = mkIf (config.interactiveShellHook != "") {
    shellHook = mkAfter ''
      if [[ -n "''${_nix_direnv_force_reload:-}" || $- == *i* ]]; then
        ${config.interactiveShellHook}
      fi
    '';
  };
}
