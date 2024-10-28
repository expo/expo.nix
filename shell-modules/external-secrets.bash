# shellcheck shell=bash

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
  if [ -z "${secrets:-}" ]; then
    echo "Failed to read secrets"
    exit 1
  fi
  if [ "${CI:-}" ]; then
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
