#!/bin/bash
#===============================================================================
# Common Library - Shared constants and helper functions
# Source this file from other scripts to access shared functionality
#===============================================================================

# Prevent double-sourcing
[[ -n "${_LIB_COMMON_LOADED:-}" ]] && return
_LIB_COMMON_LOADED=1

#-------------------------------------------------------------------------------
# Path Constants
# Note: LIB_DIR is set here, SCRIPT_DIR should be set by the sourcing script
#-------------------------------------------------------------------------------
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${LIB_DIR}/.." && pwd)"

# Use PROJECT_ROOT for all paths to ensure consistency
CONTAINER_NAME="terraria-server"
COMPOSE_FILE="${PROJECT_ROOT}/docker/docker-compose.yml"
ENV_FILE="${PROJECT_ROOT}/.env"
BACKUP_DIR="${PROJECT_ROOT}/data/backups"
DATA_DIR="${PROJECT_ROOT}/data"
COMMAND_FIFO="/tmp/terraria-command.fifo"

#-------------------------------------------------------------------------------
# Color Codes
#-------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------

# Print colored message
print_msg() {
    local color="$1"
    local msg="$2"
    echo -e "${color}${msg}${NC}"
}

print_info()    { print_msg "${BLUE}" "$1"; }
print_success() { print_msg "${GREEN}" "✓ $1"; }
print_warning() { print_msg "${YELLOW}" "⚠ $1"; }
print_error()   { print_msg "${RED}" "✗ $1"; }
print_header()  { echo -e "\n${BOLD}${CYAN}$1${NC}\n"; }
