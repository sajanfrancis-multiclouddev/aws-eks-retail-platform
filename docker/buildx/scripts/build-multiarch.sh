#!/usr/bin/env bash

set -Eeuo pipefail

: "${DOCKERHUB_USER:?Set DOCKERHUB_USER}"
: "${IMAGE_VERSION:?Set IMAGE_VERSION}"

IMAGE_REPOSITORY="${DOCKERHUB_USER}/retail-ui-multiarch"
IMAGE="${IMAGE_REPOSITORY}:${IMAGE_VERSION}"
CACHE_IMAGE="${IMAGE_REPOSITORY}:buildcache"
BUILDER_NAME="${BUILDER_NAME:-multiarch}"

echo "Builder: ${BUILDER_NAME}"
echo "Image:   ${IMAGE}"

docker buildx inspect "${BUILDER_NAME}" --bootstrap

docker buildx build \
  --builder "${BUILDER_NAME}" \
  --platform linux/amd64,linux/arm64 \
  --tag "${IMAGE}" \
  --cache-from "type=registry,ref=${CACHE_IMAGE}" \
  --cache-to "type=registry,ref=${CACHE_IMAGE},mode=max" \
  --sbom=true \
  --provenance=mode=max \
  --push .

echo "Published ${IMAGE}"
