#!/bin/bash

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
ORANGE='\033[38;5;208m'
BOLD='\033[1m'
RESET='\033[0m'

log_section()      { echo -e "\n${BOLD}${BLUE}$1\033[0m\n${BLUE}──────────────────────────────────────${RESET}"; }
log_section_snap() { echo -e "\n${BOLD}${ORANGE}$1\033[0m\n${ORANGE}──────────────────────────────────────${RESET}"; }
log_info()    { echo -e "${BLUE}[INFO]${RESET}  $*"; }
log_success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
