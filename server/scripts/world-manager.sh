#!/bin/bash
#---------------------------------------------------------------
# World Manager Script
# Provides world creation, listing, deletion, and management
#---------------------------------------------------------------

WORLD_DIR="${WORLD_DIR:-/terraria/worlds}"
SERVER_BIN="/terraria/server/TerrariaServer.bin.x86_64"
LOG_FILE="/terraria/logs/world-manager.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#---------------------------------------------------------------
# Logging helpers
#---------------------------------------------------------------
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WORLD-MANAGER] $1"
    echo -e "$msg"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [WORLD-MANAGER] [ERROR] $1"
    echo -e "${RED}$msg${NC}" >&2
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_success() {
    echo -e "${GREEN}$1${NC}"
}

log_warning() {
    echo -e "${YELLOW}$1${NC}"
}

#---------------------------------------------------------------
# Display usage/help
#---------------------------------------------------------------
usage() {
    echo ""
    echo "Terraria World Manager"
    echo "======================"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  list                   List all available worlds"
    echo "  info <name>            Show detailed info about a world"
    echo "  create                 Create a new world (interactive)"
    echo "  create-auto            Create world from environment variables"
    echo "  delete <name>          Delete a world (with confirmation)"
    echo "  copy <src> <dst>       Copy a world to a new name"
    echo "  help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 list"
    echo "  $0 create"
    echo "  $0 info MyWorld"
    echo "  $0 delete OldWorld"
    echo "  $0 copy MyWorld MyWorldBackup"
    echo ""
}

#---------------------------------------------------------------
# List all worlds
#---------------------------------------------------------------
list_worlds() {
    log "Listing worlds in ${WORLD_DIR}"
    
    echo ""
    echo "Available Worlds"
    echo "================"
    echo ""
    
    if [ ! -d "${WORLD_DIR}" ]; then
        log_warning "World directory does not exist: ${WORLD_DIR}"
        return 1
    fi
    
    local count=0
    local total_size=0
    
    printf "%-30s %-12s %-20s\n" "NAME" "SIZE" "LAST MODIFIED"
    printf "%s\n" "--------------------------------------------------------------"
    
    for world in "${WORLD_DIR}"/*.wld 2>/dev/null; do
        if [ -f "$world" ]; then
            local name
            name=$(basename "$world" .wld)
            local size
            size=$(du -h "$world" 2>/dev/null | cut -f1)
            local size_bytes
            size_bytes=$(stat -c%s "$world" 2>/dev/null || echo 0)
            local modified
            modified=$(stat -c '%Y' "$world" 2>/dev/null)
            local modified_date
            modified_date=$(date -d "@${modified}" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
            
            printf "%-30s %-12s %-20s\n" "$name" "$size" "$modified_date"
            ((count++))
            ((total_size += size_bytes))
        fi
    done
    
    if [ ${count} -eq 0 ]; then
        echo "No worlds found."
    else
        echo ""
        echo "Total: ${count} world(s), $(numfmt --to=iec ${total_size} 2>/dev/null || echo "${total_size} bytes")"
    fi
    echo ""
    
    return 0
}

#---------------------------------------------------------------
# Show world info
#---------------------------------------------------------------
show_world_info() {
    local world_name="$1"
    
    if [ -z "${world_name}" ]; then
        log_error "World name is required"
        echo "Usage: $0 info <world_name>"
        return 1
    fi
    
    local world_file="${WORLD_DIR}/${world_name}.wld"
    
    if [ ! -f "${world_file}" ]; then
        log_error "World not found: ${world_name}"
        return 1
    fi
    
    echo ""
    echo "World Information: ${world_name}"
    echo "================================="
    echo ""
    
    # Basic file info
    local size
    size=$(du -h "${world_file}" | cut -f1)
    local size_bytes
    size_bytes=$(stat -c%s "${world_file}")
    local created
    created=$(stat -c '%W' "${world_file}" 2>/dev/null)
    local modified
    modified=$(stat -c '%Y' "${world_file}")
    
    echo "File:          ${world_file}"
    echo "Size:          ${size} (${size_bytes} bytes)"
    echo "Modified:      $(date -d "@${modified}" '+%Y-%m-%d %H:%M:%S')"
    
    if [ "${created}" != "0" ] && [ "${created}" != "-" ]; then
        echo "Created:       $(date -d "@${created}" '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # Check for backup file
    local bak_file="${world_file}.bak"
    if [ -f "${bak_file}" ]; then
        local bak_size
        bak_size=$(du -h "${bak_file}" | cut -f1)
        local bak_modified
        bak_modified=$(stat -c '%Y' "${bak_file}")
        echo ""
        echo "Backup file:   ${bak_file}"
        echo "Backup size:   ${bak_size}"
        echo "Backup date:   $(date -d "@${bak_modified}" '+%Y-%m-%d %H:%M:%S')"
    fi
    
    echo ""
    
    return 0
}

#---------------------------------------------------------------
# Create a new world (interactive)
#---------------------------------------------------------------
create_world_interactive() {
    log "Starting interactive world creation..."
    
    echo ""
    echo "Create New World"
    echo "================"
    echo ""
    
    # World name
    read -r -p "World name: " world_name
    if [ -z "${world_name}" ]; then
        log_error "World name cannot be empty"
        return 1
    fi
    
    # Sanitize world name (remove special characters)
    world_name=$(echo "${world_name}" | tr -cd '[:alnum:]_-')
    
    # Check if world exists
    if [ -f "${WORLD_DIR}/${world_name}.wld" ]; then
        log_error "World already exists: ${world_name}"
        return 1
    fi
    
    # World size
    echo ""
    echo "World size options:"
    echo "  1. Small  (4200 x 1200)"
    echo "  2. Medium (6400 x 1800)"
    echo "  3. Large  (8400 x 2400)"
    read -r -p "Select size [1-3] (default: 2): " size_choice
    
    case "${size_choice}" in
        1) world_size=1 ;;
        3) world_size=3 ;;
        *) world_size=2 ;;
    esac
    
    # Difficulty
    echo ""
    echo "Difficulty options:"
    echo "  0. Classic (Normal)"
    echo "  1. Expert"
    echo "  2. Master"
    echo "  3. Journey"
    read -r -p "Select difficulty [0-3] (default: 0): " diff_choice
    
    case "${diff_choice}" in
        1) difficulty=1 ;;
        2) difficulty=2 ;;
        3) difficulty=3 ;;
        *) difficulty=0 ;;
    esac
    
    # Seed (optional)
    echo ""
    read -r -p "World seed (leave empty for random): " world_seed
    
    # Evil type (optional for non-random)
    echo ""
    echo "Evil biome options:"
    echo "  1. Random"
    echo "  2. Corruption"
    echo "  3. Crimson"
    read -r -p "Select evil biome [1-3] (default: 1): " evil_choice
    
    case "${evil_choice}" in
        2) evil_type="corruption" ;;
        3) evil_type="crimson" ;;
        *) evil_type="random" ;;
    esac
    
    # Confirm
    echo ""
    echo "World Configuration:"
    echo "  Name:       ${world_name}"
    echo "  Size:       ${world_size} ($([ ${world_size} -eq 1 ] && echo "Small" || [ ${world_size} -eq 2 ] && echo "Medium" || echo "Large"))"
    echo "  Difficulty: ${difficulty} ($([ ${difficulty} -eq 0 ] && echo "Classic" || [ ${difficulty} -eq 1 ] && echo "Expert" || [ ${difficulty} -eq 2 ] && echo "Master" || echo "Journey"))"
    echo "  Seed:       ${world_seed:-Random}"
    echo "  Evil:       ${evil_type}"
    echo ""
    read -r -p "Create this world? [y/N]: " confirm
    
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo "World creation cancelled."
        return 1
    fi
    
    # Create the world
    _create_world "${world_name}" "${world_size}" "${difficulty}" "${world_seed}" "${evil_type}"
}

#---------------------------------------------------------------
# Create a world from environment variables
#---------------------------------------------------------------
create_world_auto() {
    local world_name="${WORLD_NAME:-world}"
    local world_size="${AUTOCREATE:-2}"
    local difficulty="${DIFFICULTY:-0}"
    local world_seed="${WORLD_SEED:-}"
    
    log "Creating world from environment: ${world_name}"
    
    # Check if world already exists
    if [ -f "${WORLD_DIR}/${world_name}.wld" ]; then
        log "World already exists: ${world_name}, skipping creation"
        return 0
    fi
    
    _create_world "${world_name}" "${world_size}" "${difficulty}" "${world_seed}" "random"
}

#---------------------------------------------------------------
# Internal: Create a world using TerrariaServer
#---------------------------------------------------------------
_create_world() {
    local name="$1"
    local size="$2"
    local difficulty="$3"
    local seed="$4"
    local evil="$5"
    
    log "Creating world: ${name} (size=${size}, difficulty=${difficulty})"
    
    # Check server binary
    if [ ! -x "${SERVER_BIN}" ]; then
        log_error "Server binary not found or not executable: ${SERVER_BIN}"
        return 1
    fi
    
    # Create a temporary config for world creation
    local temp_config
    temp_config=$(mktemp)
    
    cat > "${temp_config}" << EOF
# Temporary config for world creation
autocreate=${size}
worldname=${name}
worldpath=${WORLD_DIR}/
difficulty=${difficulty}
EOF
    
    if [ -n "${seed}" ]; then
        echo "seed=${seed}" >> "${temp_config}"
    fi
    
    log "Starting world generation (this may take a few minutes)..."
    
    # Run the server with the world creation config
    # The server will create the world and exit when given an empty stdin or "exit"
    echo "exit" | timeout 300 "${SERVER_BIN}" -config "${temp_config}" 2>&1 | while read -r line; do
        echo "  ${line}"
    done
    
    # Check result
    rm -f "${temp_config}"
    
    if [ -f "${WORLD_DIR}/${name}.wld" ]; then
        log_success "World created successfully: ${name}"
        show_world_info "${name}"
        return 0
    else
        log_error "World creation may have failed - world file not found"
        return 1
    fi
}

#---------------------------------------------------------------
# Delete a world
#---------------------------------------------------------------
delete_world() {
    local world_name="$1"
    
    if [ -z "${world_name}" ]; then
        log_error "World name is required"
        echo "Usage: $0 delete <world_name>"
        return 1
    fi
    
    local world_file="${WORLD_DIR}/${world_name}.wld"
    local bak_file="${world_file}.bak"
    
    if [ ! -f "${world_file}" ]; then
        log_error "World not found: ${world_name}"
        return 1
    fi
    
    # Show world info
    show_world_info "${world_name}"
    
    # Confirm deletion
    log_warning "WARNING: This will permanently delete the world and its backup!"
    read -r -p "Type '${world_name}' to confirm deletion: " confirm
    
    if [ "${confirm}" != "${world_name}" ]; then
        echo "Deletion cancelled."
        return 1
    fi
    
    # Delete the world files
    log "Deleting world: ${world_name}"
    
    rm -f "${world_file}"
    rm -f "${bak_file}"
    
    if [ ! -f "${world_file}" ]; then
        log_success "World deleted successfully: ${world_name}"
        return 0
    else
        log_error "Failed to delete world"
        return 1
    fi
}

#---------------------------------------------------------------
# Copy a world
#---------------------------------------------------------------
copy_world() {
    local src_name="$1"
    local dst_name="$2"
    
    if [ -z "${src_name}" ] || [ -z "${dst_name}" ]; then
        log_error "Source and destination names are required"
        echo "Usage: $0 copy <source_name> <destination_name>"
        return 1
    fi
    
    # Sanitize destination name
    dst_name=$(echo "${dst_name}" | tr -cd '[:alnum:]_-')
    
    local src_file="${WORLD_DIR}/${src_name}.wld"
    local dst_file="${WORLD_DIR}/${dst_name}.wld"
    
    if [ ! -f "${src_file}" ]; then
        log_error "Source world not found: ${src_name}"
        return 1
    fi
    
    if [ -f "${dst_file}" ]; then
        log_error "Destination world already exists: ${dst_name}"
        return 1
    fi
    
    log "Copying world: ${src_name} -> ${dst_name}"
    
    cp "${src_file}" "${dst_file}"
    
    # Also copy backup if it exists
    if [ -f "${src_file}.bak" ]; then
        cp "${src_file}.bak" "${dst_file}.bak"
    fi
    
    if [ -f "${dst_file}" ]; then
        log_success "World copied successfully"
        show_world_info "${dst_name}"
        return 0
    else
        log_error "Failed to copy world"
        return 1
    fi
}

#---------------------------------------------------------------
# Main entry point
#---------------------------------------------------------------
main() {
    # Ensure world directory exists
    mkdir -p "${WORLD_DIR}"
    
    local command="${1:-help}"
    shift 2>/dev/null || true
    
    case "${command}" in
        list|ls)
            list_worlds
            ;;
        info|show)
            show_world_info "$@"
            ;;
        create)
            create_world_interactive
            ;;
        create-auto)
            create_world_auto
            ;;
        delete|rm)
            delete_world "$@"
            ;;
        copy|cp)
            copy_world "$@"
            ;;
        help|-h|--help)
            usage
            ;;
        *)
            log_error "Unknown command: ${command}"
            usage
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
