#!/usr/bin/env bash

# PLATFORMS is either a comma-separated list of platforms to build the image
# for, or blank.  This shell expansion replaces a blank or unset variable with
# `linux/amd64`, which is the only platform supported by several places we run
# docker images, and works on Apple Silicon via rosetta.
PLATFORMS=${PLATFORMS:-linux/amd64}

# `docker buildx build` requires a builder instance.  Builder instances have an
# associated set of platforms, and a context.  Therefore, we create or re-use a
# builder for each combination of those things
# REF: https://docs.docker.com/reference/cli/docker/buildx/create/

if [[ -n "${MINIKUBE_ACTIVE_DOCKERD:-}" ]]; then
  context=minikube
  echo "Deploying to a minikube cluster, using '$context' docker context"
  # Since minikube instances can change without this context changing, it must
  # be kept up-to-date, and the simplest way to do that is by always
  # re-creating it.
  docker context rm $context &> /dev/null || echo "'$context' docker context not found, creating it"
  docker context create $context &> /dev/null
else
  context=$(docker context show)
fi

# PLATFORMS can have `/` and `,` characters in it, but builder names can't.
# This shell expansion replaces those with `-` characters
builder="skaffold-${PLATFORMS//[,\/]/-}-$context"

if docker buildx inspect "$builder" >/dev/null 2>&1; then
  echo "Using existing builder $builder"
else
  echo "Creating builder $builder"
  docker buildx create --name "$builder" --platform "$PLATFORMS" --use "$context"
fi

if [ "$PUSH_IMAGE" = "true" ]; then
  args=(--platform "$PLATFORMS" --push)
else
  args=(--load)
fi

# This condition is true when IMAGE contains a `/`, which it does when it
# includes a full repository address.
if [[ "$IMAGE" == */* ]]; then
  # No matter what, we make sure that docker is configured to use `gcloud auth`.
  # This shell expansion removes everything after the first `/`, inclusive.  So
  # for example:
  # `gcr.io/aProjectName/aRepositoryName/image-name:tag` -> `gcr.io`
  gcloud auth configure-docker "${IMAGE%%/*}"

  # We want valid image tag that's consistent for a given git branch or ref
  # name, but many characters are allowed in ref names that aren't in image
  # tags, so we run it through MD5.
  cacheTag() {
    echo "$@" | md5sum | head -c 10
  }

  # Write and read a cache for this branch or pull request
  # NOTE: in PRs, GITHUB_REF_NAME will be "<pr_number>/merge"
  if [ -n "${GITHUB_REF_NAME:-}" ]; then
    BRANCH_CACHE_IMAGE="$IMAGE_REPO:cache-$(cacheTag "$GITHUB_REF_NAME")"
    args+=(--cache-from="type=registry,ref=$BRANCH_CACHE_IMAGE")
    if [ "$PUSH_IMAGE" = "true" ]; then
      args+=(--cache-to="mode=max,image-manifest=true,oci-mediatypes=true,type=registry,ref=$BRANCH_CACHE_IMAGE")
    fi
  fi

  # As a fall-back, read a cache from the `main` branch.
  if [ "${GITHUB_REF_NAME:-}" != "main" ]; then
    args+=(--cache-from="type=registry,ref=$IMAGE_REPO:cache-$(cacheTag main)")
  fi
fi

if [ -f package.json ]; then
  NODE_VERSION="$(jq --raw-output .volta.node package.json)"
  if [ -n "$NODE_VERSION" ]; then
    echo "Volta node pin detected in package.json!  Setting build argument 'node_version'"
    args+=(--build-arg "node_version=$NODE_VERSION")
  fi
fi

set -x # Print the final command, to hide less of what's happening
# REF: https://docs.docker.com/reference/cli/docker/buildx/build/
docker buildx build \
  --builder "$builder" \
  --tag "$IMAGE" \
  "${args[@]}" \
  "$@" \
  "$BUILD_CONTEXT"
