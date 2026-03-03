#!/bin/bash
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "${SCRIPT_DIR}/lib/log.sh"

CACHE_DIR="${SCRIPT_DIR}/../cache"

log_section "🗑️  CLEAN CACHE"

if [[ ! -d "${CACHE_DIR}" ]] || [[ -z "$(ls "${CACHE_DIR}"/*.tar.gz 2>/dev/null)" ]]; then
    log_info "Cache is already empty."
    exit 0
fi

log_info "Cached images:"
for f in "${CACHE_DIR}"/*.tar.gz; do
    echo -e "        $(du -sh "$f" | cut -f1)    $(basename "$f")"
done
echo ""
log_info "Total: $(du -sh "${CACHE_DIR}" | cut -f1)"
echo ""
read -p "$(echo -e "${YELLOW}Clean all cached images? [y/N]${RESET} ")" CONFIRM
if [[ "${CONFIRM}" == "y" || "${CONFIRM}" == "Y" ]]; then
    rm -f "${CACHE_DIR}"/*.tar.gz
    log_success "Cache cleared."
else
    log_info "Cancelled."
fi
