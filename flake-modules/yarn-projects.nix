{ flake-parts-lib, ... }:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (lib) mkOption mkPackageOption types;
      cfg = config.expo.yarn-projects;
    in
    {
      options.expo = {
        yarn-projects = mkOption {
          default = { };
          type = types.attrsOf (
            types.submodule (
              { config, ... }:
              {
                options =
                  let
                    filesetListOption = mkOption {
                      type = types.listOf types.raw;
                      default = [ ];
                    };
                  in
                  {
                    root = mkOption { type = types.path; };
                    files = filesetListOption;
                    nodejs = mkPackageOption pkgs "nodejs" { };
                    package-attributes = mkOption {
                      type = types.either (types.attrsOf types.anything) (
                        types.functionTo (types.attrsOf types.anything)
                      );
                      default =
                        if config.cloud-functions == { } then
                          { }
                        else
                          {
                            # When a yarn project is deployed as a cloud
                            # function, cloud build will run the `gcp-build`
                            # script, so make sure every package has one and it
                            # runs successfully.
                            buildPhase = "yarn gcp-build";
                            # Stripping is unnecessary, since the built c
                            # aren't copying the built nix package anywhere
                            # besides caches. Disabling it is a speedup.
                            dontStrip = true;
                          };
                    };
                    cloud-function-defaults = mkOption {
                      default = { };
                      type = types.deferredModule;
                    };
                    cloud-functions = mkOption {
                      default = { };
                      type = types.attrsOf (
                        types.submodule {
                          imports = [ config.cloud-function-defaults ];
                          options = {
                            project = mkOption { type = types.nonEmptyStr; };
                            flags = mkOption {
                              default = { };
                              type = types.attrsOf (
                                types.oneOf [
                                  types.nonEmptyStr
                                  types.bool
                                  types.path
                                  (types.listOf types.nonEmptyStr)
                                ]
                              );
                            };
                          };
                        }
                      );
                    };
                    checks = mkOption {
                      default = { };
                      type = types.attrsOf (
                        types.submodule ({
                          options = {
                            command = mkOption { type = types.nonEmptyStr; };
                            packages = mkOption {
                              default = [ ];
                              type = types.listOf types.package;
                            };
                            extra-files = filesetListOption;
                            exclude-files = filesetListOption;
                            gcloud-components = mkOption {
                              default = [ ];
                              type = types.listOf (types.enum (lib.attrNames pkgs.google-cloud-sdk.components));
                            };
                          };
                        })
                      );
                    };
                  };
              }
            )
          );
        };
      };
      config.packages = lib.concatMapAttrs (
        name:
        {
          root,
          nodejs,
          files,
          package-attributes,
          ...
        }:
        let
          project = pkgs.callPackage (root + "/yarn-project.nix") { inherit nodejs; };
          fs = lib.fileset;
          fileset = fs.unions (
            files
            ++ [
              (fs.maybeMissing (root + "/.yarn"))
              (fs.maybeMissing (root + "/.yarnrc.yml"))
              (root + "/package.json")
              (root + "/yarn.lock")
            ]
          );
          package = project {
            src = fs.toSource { inherit root fileset; };
            overrideAttrs = package-attributes;
          };
          devPackage = project {
            # Include every file in `root` in the package source
            src = fs.toSource {
              inherit root;
              fileset = root;
            };
            overrideAttrs = package-attributes // {
              # Don't run any build commands
              buildPhase = "";
              # Include every file in `root` in the package output
              installPhase = ''
                mkdir -p "$out/libexec"
                mv $PWD "$out/libexec/$name"
              '';
            };
          };
        in
        {
          ${name} = package;
          "${name}-dev" = devPackage;
        }
      ) cfg;
      config.make-shells = lib.concatMapAttrs (
        name:
        {
          nodejs,
          checks,
          cloud-functions,
          ...
        }:
        let
          from = setOfSets: attrName: lib.flatten (lib.catAttrs attrName (lib.attrsets.attrValues setOfSets));
        in
        {
          ${name} = {
            expo.yarn-nixify.enable = true;
            packages = from checks "packages";
            javascript.node = {
              enable = true;
              package = nodejs;
            };
            gcloud = lib.mkMerge [
              # If any checks need google cloud, or if any cloud-function
              # modules are defined, then add `gcloud` to the shell, with any
              # components needed to run the checks
              (
                let
                  extra-components = from checks "gcloud-components";
                in
                lib.mkIf (cloud-functions != { } || extra-components != [ ]) {
                  enable = true;
                  inherit extra-components;
                }
              )
              # If every cloud-function module has the same project, set that in the shell.
              (
                let
                  projects = from cloud-functions "project";
                in
                lib.mkIf (lib.lists.all (v: v == builtins.head projects) projects) {
                  properties.core.project = builtins.head projects;
                }
              )
            ];
          };
        }
      ) cfg;
      config.expo.cloud-functions = lib.concatMapAttrs (
        name:
        { nodejs, cloud-functions, ... }:
        builtins.mapAttrs (
          _functionName: functionConfig:
          functionConfig
          // {
            # Unfortunately, vendoring yarn dependencies is not supported by
            # Cloud Build.  If it was, we could deploy a pre-built package
            # for faster rollouts and a clearer picture of what's getting
            # deployed.  Instead, we upload the `src` field of the package,
            # and depend on Cloud Build to install dependencies, run the
            # "gcp-build" field, and remove dev dependencies.
            # REF: https://github.com/GoogleCloudPlatform/buildpacks/blob/662ebcd5cf95d74824184fef2b7e992fac3a5636/pkg/nodejs/yarn.go
            source = config.packages.${name}.src;
            # REF: https://cloud.google.com/functions/docs/runtime-support, or run `gcloud functions runtimes list`
            runtime = "nodejs${builtins.head (builtins.splitVersion nodejs.version)}";
          }
        ) cloud-functions
      ) cfg;
      config.checks = lib.concatMapAttrs (
        name:
        { root, checks, ... }:
        {
          "${name}-build" = config.packages.${name};
        }
        // lib.mapAttrs' (
          checkName:
          {
            exclude-files,
            extra-files,
            packages,
            command,
            gcloud-components,
            ...
          }:
          {
            name = "${name}-${checkName}";
            value = config.packages.${name}.overrideAttrs (prevAttrs: {
              name = "${prevAttrs.name}-${checkName}";
              src =
                let
                  fs = pkgs.lib.fileset;
                in
                fs.toSource {
                  inherit root;
                  fileset = fs.difference (fs.unions (extra-files ++ [ (fs.fromSource prevAttrs.src) ])) (
                    fs.unions exclude-files
                  );
                };
              nativeBuildInputs =
                packages
                ++ (prevAttrs.nativeBuildInputs or [ ])
                ++ (lib.optional (gcloud-components != [ ]) (
                  pkgs.google-cloud-sdk.withExtraComponents (
                    builtins.map (c: pkgs.google-cloud-sdk.components.${c}) gcloud-components
                  )
                ));
              buildPhase = command;
              installPhase = "echo check successful; touch $out";
            });
          }
        ) checks
      ) cfg;
    }
  );
}
