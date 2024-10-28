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
    write-json-secrets-from-yaml = lib.mkOption {
      default = [ ];
      type = types.listOf yamlFileAndPattern;
    };
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
        prefix = ''
          SECRETS_DIRECTORY=$(mktemp -d)
          export SECRETS_DIRECTORY
          delete_secrets() {
            rm -r "$SECRETS_DIRECTORY"
          }
          trap delete_secrets EXIT

          access_secret_version() {
            name="$1"
            version="$2"
            >&2 echo "reading version $version of secret $name"
            gcloud secrets versions access "$version" --secret "$name"
          }

          source_secrets_from_gcsm_json() {
            name="$1"
            version="$2"
            secrets=$(access_secret_version "$name" "$version")
            if [ -z "''${secrets:-}" ]; then
              echo "Failed to read secrets"
              exit 1
            fi
            if [ "''${CI:-}" ]; then
              echo "$secrets" | jq --raw-output 'to_entries | map("::add-mask::\(.value)") | .[]'
            fi
            eval "export $(echo "$secrets" | jq --raw-output 'to_entries | map("\(.key)=\(.value)") | @sh')"
          }

          source_secrets_from_yaml() {
            pattern="$1"
            yaml_file="$2"
            IFS=$'\n'
            for row in $(yq --raw-output "$pattern | [ .key, .version ] | @tsv" "$yaml_file"); do
              IFS=$'\t' read -r secret_name secret_version <<<"$row"
              source_secrets_from_gcsm_json "$secret_name" "$secret_version"
            done
          }

          external_secret_to_files() {
            pattern="$1"
            yaml_file="$2"
            IFS=$'\n'
            for row in $(yq --raw-output "$pattern | [ .secretKey, .remoteRef.key, .remoteRef.version ] | @tsv" "$yaml_file"); do
              IFS=$'\t' read -r secret_file_name secret_name secret_version <<<"$row"
              access_secret_version "$secret_name" "$secret_version" > "$SECRETS_DIRECTORY/$secret_file_name"
            done
          }
        '';
        sourceLines =
          (lib.mapAttrsToList (
            name: { version }: "source_secrets_from_gcsm_json ${name} ${builtins.toString version}"
          ) cfg.source-json-secrets)
          ++ (builtins.map (
            { file, pattern }: "source_secrets_from_yaml '${pattern}' '${file}'"
          ) cfg.source-json-secrets-from-yaml)
          ++ (builtins.map (
            { file, pattern }: "external_secret_to_files '${pattern}' '${file}'"
          ) cfg.write-json-secrets-from-yaml);
        overrideExports = lib.mapAttrsToList (
          name: value: ''export ${name}="${builtins.toString value}"''
        ) cfg.overrideEnv;
      in
      prefix + lib.concatStringsSep "\n" (sourceLines ++ overrideExports);
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
