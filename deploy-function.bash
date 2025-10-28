force=
while :; do
  case "${1:-}" in
  -h | --help)
    shift
    echo "Usage:"
    echo "  $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -f, --force    Run the the deploy command, even if the function has been deployed"
    exit
    ;;
  -f | --force)
    force=1
    ;;
  -?*)
    echo "Error: unknown option: $1" >&2
    exit 1
    ;;
  *)
    break
    ;;
  esac

  shift
done

declare outPath
packageId="${outPath#/nix/store/}"
hashLabelValue="${packageId%%-*}"
hashLabelKey=function-hash
hashLabel="$hashLabelKey=$hashLabelValue"

deployedHash="$(gcloud functions describe --format="value(labels.$hashLabelKey)" "${functionName:?}" || echo function not deployed yet)"
if [[ $deployedHash == "$hashLabelValue" ]]; then
  echo "The function $functionName already has the label $hashLabel"
  echo "That means it already has all the source and configuration which this command would deploy."
  if [[ $force != 1 ]]; then
    echo "Run with --force to force deployment"
    exit 0
  else
    echo "This script was run with --force; deploying the function anyway!"
  fi
else
  if [[ $force == 1 ]]; then
    echo "This script was run with --force, but that was unnecessary; it was going to deploy the function anyway."
  fi
fi

echo "Deploying $functionName to Google Cloud Platform..."

gcloud functions deploy "$functionName" \
  --update-labels "$hashLabel" \
  "${deployFlags[@]:?}"

echo "Cloud Function $functionName has been deployed"
