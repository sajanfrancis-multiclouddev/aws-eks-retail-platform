#!/usr/bin/env bash

set -Eeuo pipefail

IMAGE="${1:-sajanvethakumar/retail-ui-multiarch:1.0.0}"

echo "Inspecting image: ${IMAGE}"

manifest="$(docker buildx imagetools inspect "${IMAGE}")"

printf '%s\n' "${manifest}"

printf '%s\n' "${manifest}" |
  grep -q 'Platform:[[:space:]]*linux/amd64'

printf '%s\n' "${manifest}" |
  grep -q 'Platform:[[:space:]]*linux/arm64'

echo "PASS: ${IMAGE} contains AMD64 and ARM64 variants."
