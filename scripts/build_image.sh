#!/bin/bash
set -eo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "${SCRIPT_DIR}/lib/log.sh"

PROJECT_DIR="${SCRIPT_DIR}/.."
CACHE_DIR="${PROJECT_DIR}/cache"
COMPOSE_DIR="${PROJECT_DIR}/build/docker"
ENVRC="${PROJECT_DIR}/.envrc"

log_section "🐳 BUILD IMAGE"

# --- check dependencies
for cmd in curl jq docker; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "'$cmd' is required but not installed."
        exit 1
    fi
done

if [[ ! -f "${ENVRC}" ]]; then
    log_error "${ENVRC} not found. Copy .envrc.example to .envrc and fill in the values."
    exit 1
fi
source "${ENVRC}"

log_info "TARGET_ARCH: ${TARGET_ARCH}"
DOCKER_CLI="docker"
SHORT_NAME=$(basename "${IMAGE_NAME}")

log_info "Resolving version for ${IMAGE_NAME}:${IMAGE_TAG}..."
if [[ "${IMAGE_TAG}" == "latest" ]]; then
    log_info "IMAGE_TAG=latest → querying Docker Registry API"
    TOKEN=$(curl -s "https://auth.docker.io/token?service=registry.docker.io&scope=repository:${IMAGE_NAME}:pull" | jq -r .token)
    MANIFEST=$(curl -s \
      -H "Authorization: Bearer ${TOKEN}" \
      -H "Accept: application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.docker.distribution.manifest.v2+json" \
      "https://registry-1.docker.io/v2/${IMAGE_NAME}/manifests/${IMAGE_TAG}")
    if echo "${MANIFEST}" | jq -e '.manifests' > /dev/null 2>&1; then
        PLATFORM_DIGEST=$(echo "${MANIFEST}" | jq -r --arg arch "${TARGET_ARCH}" \
          '.manifests[] | select(.platform.architecture == $arch and .platform.os == "linux") | .digest' | head -1)
        PLATFORM_MANIFEST=$(curl -s \
          -H "Authorization: Bearer ${TOKEN}" \
          -H "Accept: application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.v2+json" \
          "https://registry-1.docker.io/v2/${IMAGE_NAME}/manifests/${PLATFORM_DIGEST}")
        CONFIG_DIGEST=$(echo "${PLATFORM_MANIFEST}" | jq -r .config.digest)
    else
        CONFIG_DIGEST=$(echo "${MANIFEST}" | jq -r .config.digest)
    fi
    RESOLVED_VERSION=$(curl -sL \
      -H "Authorization: Bearer ${TOKEN}" \
      "https://registry-1.docker.io/v2/${IMAGE_NAME}/blobs/${CONFIG_DIGEST}" \
      | jq -r '.config.Labels["org.opencontainers.image.version"]')
    RESOLVED_VERSION=${RESOLVED_VERSION:-latest}
else
    RESOLVED_VERSION="${IMAGE_TAG}"
fi

FILENAME="${SHORT_NAME}_${RESOLVED_VERSION}_${TARGET_ARCH}.tar.gz"
log_success "Version resolved: ${RESOLVED_VERSION}"

mkdir -p "${CACHE_DIR}"
mkdir -p "${PROJECT_DIR}/build"
echo "${RESOLVED_VERSION}" > "${PROJECT_DIR}/build/.resolved_version"

log_info "Checking cache for ${FILENAME}..."
if [[ -f "${CACHE_DIR}/${FILENAME}" ]]; then
    log_success "Cache hit → skipping pull and save"
else
    log_info "Cache miss → pulling ${IMAGE_NAME}:${IMAGE_TAG} (resolved: ${RESOLVED_VERSION})..."
    "${DOCKER_CLI}" pull "${IMAGE_NAME}:${IMAGE_TAG}" --platform "linux/${TARGET_ARCH}"
    log_info "Saving image to cache..."
    "${DOCKER_CLI}" save "${IMAGE_NAME}:${IMAGE_TAG}" | gzip > "${CACHE_DIR}/${FILENAME}"
    log_success "Cached: $(du -sh "${CACHE_DIR}/${FILENAME}" | cut -f1) — ${FILENAME}"
    "${DOCKER_CLI}" rmi "${IMAGE_NAME}:${IMAGE_TAG}"
fi

log_info "Staging for snap build..."
mkdir -p "${COMPOSE_DIR}"
rm -f "${COMPOSE_DIR}"/*.tar.gz
cp "${CACHE_DIR}/${FILENAME}" "${COMPOSE_DIR}/${FILENAME}"
cp "${PROJECT_DIR}/docker/docker-compose.yml" "${COMPOSE_DIR}/"

log_info "Generating docker-compose.env..."
rm -f "${COMPOSE_DIR}/docker-compose.env"
echo IMAGE_NAME=${IMAGE_NAME} >> "${COMPOSE_DIR}/docker-compose.env"
echo IMAGE_TAG=${IMAGE_TAG} >> "${COMPOSE_DIR}/docker-compose.env"
echo GATEWAY_ADMIN_USERNAME=${GATEWAY_ADMIN_USERNAME} >> "${COMPOSE_DIR}/docker-compose.env"
echo GATEWAY_ADMIN_PASSWORD=${GATEWAY_ADMIN_PASSWORD} >> "${COMPOSE_DIR}/docker-compose.env"
echo IGNITION_EDITION=${IGNITION_EDITION} >> "${COMPOSE_DIR}/docker-compose.env"
echo ACCEPT_IGNITION_EULA=${ACCEPT_IGNITION_EULA} >> "${COMPOSE_DIR}/docker-compose.env"

log_success "Staged: $(du -sh "${COMPOSE_DIR}/${FILENAME}" | cut -f1)"
