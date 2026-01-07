#!/usr/bin/env bash
#
# Copyright (c) 2024 Intel Corporation
# Copyright (c) 2026 IBM Corporation
#
# SPDX-License-Identifier: Apache-2.0
#

set -o errexit
set -o pipefail
set -o nounset


function _publish_multiarch_manifest()
{
	IFS=',' read -ra TAGS <<< "${IMAGE_TAGS:?"Image tags must be provided"}"

	ARCHES=${ARCHES:-"amd64,arm64,ppc64le,s390x"}
	IFS=',' read -ra MULTI_ARCHES <<< "${ARCHES}"

	for tag in "${TAGS[@]}"; do
		images=()
		for arch in "${MULTI_ARCHES[@]}"; do
			images+=("${IMAGE_REGISTRY:?}/${IMAGE_NAME:?}:${tag}-${arch}")
		done

		# Validate that all required arch-specific images exist before creating manifest
		echo "Validating architecture-specific images for tag: ${tag}"
		for image in "${images[@]}"; do
			if ! docker manifest inspect "${image}" > /dev/null 2>&1; then
				echo "Error: Required image does not exist: ${image}" >&2
				echo "Please ensure all architecture-specific images are built and pushed before creating the manifest." >&2
				exit 1
			fi
		done

		docker manifest create "${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}" "${images[@]}"
		docker manifest push "${IMAGE_REGISTRY}/${IMAGE_NAME}:${tag}"
	done
}

function _main()
{
	action="${1:-}"

	case "${action}" in
		publish-multiarch-manifest) _publish_multiarch_manifest ;;
		*) >&2 echo "Invalid argument"; exit 2 ;;
	esac
}

_main "$@"
