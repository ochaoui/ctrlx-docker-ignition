#!/bin/bash
set -e
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "${SCRIPT_DIR}/lib/log.sh"

ENVRC="${SCRIPT_DIR}/../.envrc"

if [[ ! -f "${ENVRC}" ]]; then
    log_error "${ENVRC} not found. Copy .envrc.example to .envrc and fill in the values."
    exit 1
fi
source "${ENVRC}"

bash "${SCRIPT_DIR}/build_image.sh"
bash "${SCRIPT_DIR}/build_snap.sh"

log_section "✅ BUILD COMPLETE"
log_success "Snap: $(ls ${SCRIPT_DIR}/../build/*.snap 2>/dev/null | xargs -I{} basename {})"
