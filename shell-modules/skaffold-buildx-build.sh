#!/usr/bin/env bash

# This script is intended to be used as a custom builder for skaffold,
# letting it use the new `docker buildx build` CLI, gaining some speed and
# cache improvements.

# PLATFORMS is either a comma-separated list of platforms to build the image
# for, or blank.  This shell expansion replaces a blank or unset variable with
# `linux/amd64`, which is the only platform supported by several places we run
# docker images, and works on Apple Silicon via rosetta.
PLATFORMS=${PLATFORMS:-linux/amd64}

# PUSH_IMAGE is true when skaffold expects the script to push the built image,
# and unset when it only expects the script to build the image.
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
fi

set -x # Print the final command, to hide less of what's happening
# REF: https://docs.docker.com/reference/cli/docker/buildx/build/
docker buildx build \
  --tag "$IMAGE" \
  "${args[@]}" \
  "$@" \
  "$BUILD_CONTEXT"
