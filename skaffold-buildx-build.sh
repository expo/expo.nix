#!/usr/bin/env bash

# PLATFORMS is either a comma-separated list of platforms to build the image
# for, or blank.  This shell expansion replaces a blank or unset variable with
# `linux/amd64`, which is the only platform supported by several places we run
# docker images, and works on Apple Silicon via rosetta.
PLATFORMS=${PLATFORMS:-linux/amd64}

# `docker buildx build` requires a builder instance, and builder instances also
# have a platform.  For each value of PLATFORMS, we create or re-use
# a builder instance.
# REF: https://docs.docker.com/reference/cli/docker/buildx/create/

# PLATFORMS can have `/` and `,` characters in it, but builder names can't.
# This shell expansion replaces those with `-` characters
builder="skaffold-${PLATFORMS//[,\/]/-}"
if docker buildx inspect "$builder" >/dev/null 2>&1; then
  echo "Using existing builder $builder"
else
  echo "Creating builder $builder"
  docker buildx create --name "$builder" --platform "$PLATFORMS"
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

  # For each image repository, create a cache repository
  CACHE_REPO="$IMAGE_REPO-cache"

  # Write and read a cache for this exact image tag.
  # NOTE: With the skaffold tagging strategy `sha256`, IMAGE_TAG will always be
  # `latest`, which makes these arguments less useful.
  TAG_CACHE_IMAGE="$CACHE_REPO:$IMAGE_TAG"
  args+=(--cache-from="type=registry,ref=$TAG_CACHE_IMAGE" --cache-to="mode=max,image-manifest=true,oci-mediatypes=true,type=registry,ref=$TAG_CACHE_IMAGE")

  # We want valid image tag that's consistent for a given git branch or ref
  # name, but many characters are allowed in ref names that aren't in image
  # tags, so we run it through MD5.
  cacheTag() {
    echo "$@" | md5sum | head -c 10
  }

  # Write and read a cache for this branch or pull request
  # NOTE: in PRs, GITHUB_REF_NAME will be "<pr_number>/merge"
  if [ -n "${GITHUB_REF_NAME:-}" ]; then
    BRANCH_CACHE_IMAGE="$CACHE_REPO:$(cacheTag "$GITHUB_REF_NAME")"
    args+=(--cache-from="type=registry,ref=$BRANCH_CACHE_IMAGE" --cache-to="mode=max,image-manifest=true,oci-mediatypes=true,type=registry,ref=$BRANCH_CACHE_IMAGE")
  fi

  # As a fall-back, read a cache from the `main` branch.
  if [ "${GITHUB_REF_NAME:-}" != "main" ]; then
    args+=(--cache-from="type=registry,ref=$CACHE_REPO:$(cacheTag main)")
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
