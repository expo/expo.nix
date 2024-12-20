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
      options.expo.cloud-functions =
        let
          inherit (lib) mkOption types;
        in
        mkOption {
          default = { };
          type = types.attrsOf (
            types.submodule {
              options = {
                source = mkOption { type = types.path; };
                runtime = mkOption { type = types.nonEmptyStr; };
                project = mkOption { type = types.nonEmptyStr; };
                flags = mkOption {
                  default = { };
                  type = types.attrsOf (
                    types.oneOf [
                      types.nonEmptyStr
                      types.bool
                      types.path
                    ]
                  );
                };
              };
            }
          );
        };
      config =
        let
          packages = lib.mapAttrs' (
            functionName:
            {
              source,
              runtime,
              project,
              flags,
              ...
            }:

            let
              name = "deploy-${functionName}";
            in
            {
              inherit name;
              value = pkgs.writeShellApplication {
                inherit name;
                runtimeInputs = [ pkgs.google-cloud-sdk ];
                runtimeEnv =
                  let
                    mergedFlags = flags // {
                      inherit source runtime project;
                    };
                    flagToString =
                      flag: value:
                      if value == true then
                        "--${flag}"
                      else if value == false then
                        "--no-${flag}"
                      else
                        "--${flag}=${value}";
                  in
                  {
                    inherit functionName;
                    deployFlags = lib.mapAttrsToList flagToString mergedFlags;
                    outPath = builtins.placeholder "out";
                  };
                text = builtins.readFile ../deploy-function.bash;
              };
            }
          ) config.expo.cloud-functions;
        in
        {
          inherit packages;
          checks = packages;
        };
    }
  );
}
