{
  lib,
  config,
  ...
}:
let
  inherit (lib) types;
  cfg = config.gcloud;
  yamlFileAndPattern = types.submodule {
    options = {
      pattern = lib.mkOption { type = types.nonEmptyStr; };
      file = lib.mkOption { type = types.pathInStore; };
    };
  };
in
{
  options.gcloud = {
    source-json-secrets-from-yaml = lib.mkOption {
      default = [ ];
      type = types.listOf yamlFileAndPattern;
    };
    source-json-secrets = lib.mkOption {
      default = { };
      type = types.attrsOf (
        types.submodule {
          options = {
            version = lib.mkOption {
              type = types.int;
            };
          };
        }
      );
    };
    overrideEnv = lib.mkOption {
      default = { };
      type = types.lazyAttrsOf (
        types.oneOf [
          types.str
          types.bool
          types.number
        ]
      );
    };
  };
  config = lib.mkIf cfg.enable {
    shellHook =
      let
        sourceLines =
          (lib.mapAttrsToList (
            name: { version }: "source_secrets_from_gcsm_json ${name} ${builtins.toString version}"
          ) cfg.source-json-secrets)
          ++ (builtins.map (
            { file, pattern }: "source_secrets_from_yaml '${pattern}' '${file}'"
          ) cfg.source-json-secrets-from-yaml);
        overrideExports = lib.mapAttrsToList (
          name: value: ''export ${name}="${builtins.toString value}"''
        ) cfg.overrideEnv;
      in
      (builtins.readFile ./external-secrets.bash) + lib.concatStringsSep "\n" (sourceLines ++ overrideExports);
    interactiveShellHook = ''
      gcloudAccount=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
      if [ -z ''${gcloudAccount:+set} ]; then
        echo "Google Cloud SDK is not authorized"
        read -rp "In the browser tab about to open, authenticate to your Expo Google Cloud account. (press enter to continue)"
        gcloud auth login
      fi
      if ! gcloud auth application-default print-access-token&>/dev/null; then
        read -rp "You don't have any default application credentials for Google Cloud. In the browser tab about to open, authorize the use of your Expo Google Cloud account. (press enter to continue)"
        gcloud auth application-default login
      fi
    '';
  };
}
