#!/bin/bash
set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "${SCRIPT_DIR}/lib/log.sh"

PROJECT_DIR="${SCRIPT_DIR}/.."
BUILD_DIR="${PROJECT_DIR}/build"
DIST_DIR="${BUILD_DIR}/dist"
ENVRC="${PROJECT_DIR}/.envrc"

if [[ ! -f "${ENVRC}" ]]; then
    log_error "${ENVRC} not found. Copy .envrc.example to .envrc and fill in the values."
    exit 1
fi
set -a; source "${ENVRC}"; set +a

log_section_snap "📦 BUILD SNAP"

if [[ "${IMAGE_TAG}" == "latest" ]]; then
    RESOLVED_FILE="${BUILD_DIR}/.resolved_version"
    if [[ ! -f "${RESOLVED_FILE}" ]]; then
        log_error "IMAGE_TAG=latest but ${RESOLVED_FILE} not found. Run build_image.sh first."
        exit 1
    fi
    export DOCKER_IMAGE_VERSION=$(cat "${RESOLVED_FILE}")
else
    export DOCKER_IMAGE_VERSION="${IMAGE_TAG}"
fi

log_info "TARGET_ARCH: ${TARGET_ARCH}"

log_info "Staging snap/snapcraft.yaml → build/snap/..."
mkdir -p "${BUILD_DIR}/snap"
cp "${PROJECT_DIR}/snapcraft/snapcraft.yaml" "${BUILD_DIR}/snap/snapcraft.yaml"
if [[ -d "${PROJECT_DIR}/snapcraft/gui" ]]; then
    cp -r "${PROJECT_DIR}/snapcraft/gui" "${BUILD_DIR}/snap/gui"
fi

cd "${BUILD_DIR}"

log_info "Cleaning previous build artifacts..."
rm -f "${BUILD_DIR}"/*.snap
snapcraft clean --destructive-mode

log_info "Building snap for ${TARGET_ARCH}..."
snapcraft pack --build-for=${TARGET_ARCH} --destructive-mode --verbosity=verbose

SNAP_FILE=$(ls "${BUILD_DIR}"/*.snap 2>/dev/null | xargs -I{} basename {} || true)
log_success "Snap created: ${SNAP_FILE}"

log_info "Moving snap to dist/..."
mkdir -p "${DIST_DIR}"
mv "${BUILD_DIR}/${SNAP_FILE}" "${DIST_DIR}/${SNAP_FILE}"

log_info "Cleaning build artifacts..."
snapcraft clean --destructive-mode

log_info "Cleaning staging files..."
rm -f "${BUILD_DIR}/snap/snapcraft.yaml"
rm -rf "${BUILD_DIR}/snap/gui"
rm -f "${BUILD_DIR}/docker/docker-compose.yml"
rm -f "${BUILD_DIR}/docker/docker-compose.env"
rm -f "${BUILD_DIR}/docker/"*.tar.gz
rm -f "${BUILD_DIR}/.resolved_version"

log_success "Done — build/dist/${SNAP_FILE}"
