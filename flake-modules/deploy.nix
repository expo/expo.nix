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
      options.expo.run =
        let
          inherit (lib) mkOption types;
        in
        mkOption {
          default = { };
          type = types.attrsOf (
            types.submodule {
              options = {
                checks = mkOption {
                  type = types.listOf (types.enum (lib.attrsets.attrNames config.checks));
                  default = [ ];
                };
                script = mkOption { type = types.nonEmptyStr; };
              };
            }
          );
        };
      config.packages =
        {
          runnable = pkgs.writeShellApplication {
            name = "runnable";
            runtimeInputs = [ pkgs.jo ];
            text =
              let
                arrayname = "targets";
                targetAdd =
                  target:
                  { checks, ... }:
                  let
                    checkAttrs = lib.concatMapStringsSep " " (
                      c: ".#checks.${pkgs.stdenv.hostPlatform.system}." + c
                    ) checks;
                    targetCondition = if checkAttrs != "" then "nix path-info ${checkAttrs} &>/dev/null" else "true";
                  in
                  ''
                    if ${targetCondition}; then
                      ${arrayname}+=(${target})
                    fi
                  '';
              in
              ''
                declare -a ${arrayname}
                ${arrayname}=()
                ${lib.concatStringsSep "\n" (lib.attrValues (lib.mapAttrs targetAdd config.expo.run))}
                jo -a "''${${arrayname}[@]}" < /dev/null
              '';
          };
        }
        // (builtins.mapAttrs (
          name:
          { script, ... }:
          pkgs.writeShellApplication {
            inherit name;
            text = script;
          }
        ) config.expo.run);
    }
  );
}
