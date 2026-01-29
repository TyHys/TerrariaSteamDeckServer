#!/bin/bash
#---------------------------------------------------------------
# Restore Script
# Restores Terraria worlds from compressed backups
#---------------------------------------------------------------

WORLD_DIR="${WORLD_DIR:-/terraria/worlds}"
BACKUP_DIR="${BACKUP_DIR:-/terraria/backups}"
LOG_FILE="/terraria/logs/restore.log"

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
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [RESTORE] $1"
    echo -e "$msg"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [RESTORE] [ERROR] $1"
    echo -e "${RED}$msg${NC}" >&2
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [RESTORE] [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [RESTORE] [WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

#---------------------------------------------------------------
# Display usage/help
#---------------------------------------------------------------
usage() {
    echo ""
    echo "Terraria Backup Restore Tool"
    echo "============================"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  restore <backup_file>           Restore a specific backup"
    echo "  restore-latest [world_name]     Restore the latest backup for a world"
    echo "  preview <backup_file>           Preview backup contents without restoring"
    echo "  list                            List available backups"
    echo "  help                            Show this help message"
    echo ""
    echo "Options:"
    echo "  --force                         Skip confirmation prompt"
    echo "  --no-backup                     Don't create backup of current world before restore"
    echo ""
    echo "Examples:"
    echo "  $0 restore backup_MyWorld_20260128_120000.tar.gz"
    echo "  $0 restore-latest MyWorld"
    echo "  $0 preview backup_MyWorld_20260128_120000.tar.gz"
    echo ""
    echo "Notes:"
    echo "  - The server should be stopped before restoring"
    echo "  - By default, current world is backed up before restore"
    echo "  - Restored worlds replace existing worlds with the same name"
    echo ""
}

#---------------------------------------------------------------
# Check if server is running
#---------------------------------------------------------------
is_server_running() {
    if pgrep -f "TerrariaServer" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

#---------------------------------------------------------------
# Get backup path (handle filename or full path)
#---------------------------------------------------------------
get_backup_path() {
    local backup_file="$1"
    
    if [ -f "${backup_file}" ]; then
        echo "${backup_file}"
    elif [ -f "${BACKUP_DIR}/${backup_file}" ]; then
        echo "${BACKUP_DIR}/${backup_file}"
    else
        echo ""
    fi
}

#---------------------------------------------------------------
# Extract world name from backup filename
#---------------------------------------------------------------
get_world_name_from_backup() {
    local backup_file="$1"
    local basename
    basename=$(basename "${backup_file}")
    
    # Format: backup_WORLDNAME_YYYYMMDD_HHMMSS.tar.gz
    echo "${basename}" | sed 's/^backup_\(.*\)_[0-9]*_[0-9]*.tar.*/\1/'
}

#---------------------------------------------------------------
# Preview backup contents
#---------------------------------------------------------------
preview_backup() {
    local backup_file="$1"
    
    if [ -z "${backup_file}" ]; then
        log_error "Backup file is required"
        echo "Usage: $0 preview <backup_file>"
        return 1
    fi
    
    local backup_path
    backup_path=$(get_backup_path "${backup_file}")
    
    if [ -z "${backup_path}" ] || [ ! -f "${backup_path}" ]; then
        log_error "Backup not found: ${backup_file}"
        return 1
    fi
    
    local world_name
    world_name=$(get_world_name_from_backup "${backup_path}")
    
    echo ""
    echo "Backup Preview"
    echo "=============="
    echo ""
    echo "Backup file:  $(basename "${backup_path}")"
    echo "World name:   ${world_name}"
    echo "Backup size:  $(du -h "${backup_path}" | cut -f1)"
    echo "Created:      $(date -d "@$(stat -c '%Y' "${backup_path}")" '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Contents:"
    echo "---------"
    
    # List archive contents
    if [[ "${backup_path}" == *.gz ]]; then
        tar -tzf "${backup_path}" 2>/dev/null
    else
        tar -tf "${backup_path}" 2>/dev/null
    fi
    
    echo ""
    
    # Check if current world exists
    local current_world="${WORLD_DIR}/${world_name}.wld"
    if [ -f "${current_world}" ]; then
        echo "Current world status:"
        echo "  File:     ${current_world}"
        echo "  Size:     $(du -h "${current_world}" | cut -f1)"
        echo "  Modified: $(date -d "@$(stat -c '%Y' "${current_world}")" '+%Y-%m-%d %H:%M:%S')"
        echo ""
        log_warning "Restoring will REPLACE the current world!"
    else
        echo "No existing world with name '${world_name}' found."
        echo "Restore will create a new world."
    fi
    echo ""
    
    return 0
}

#---------------------------------------------------------------
# Restore a specific backup
#---------------------------------------------------------------
restore_backup() {
    local backup_file="$1"
    local force=false
    local create_backup=true
    
    # Parse additional arguments
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --force) force=true ;;
            --no-backup) create_backup=false ;;
        esac
        shift
    done
    
    if [ -z "${backup_file}" ]; then
        log_error "Backup file is required"
        echo "Usage: $0 restore <backup_file> [--force] [--no-backup]"
        return 1
    fi
    
    local backup_path
    backup_path=$(get_backup_path "${backup_file}")
    
    if [ -z "${backup_path}" ] || [ ! -f "${backup_path}" ]; then
        log_error "Backup not found: ${backup_file}"
        return 1
    fi
    
    # Check if server is running
    if is_server_running; then
        log_error "Terraria server is running. Please stop the server before restoring."
        log "Hint: Use 'supervisorctl stop terraria' to stop the server"
        return 1
    fi
    
    local world_name
    world_name=$(get_world_name_from_backup "${backup_path}")
    local current_world="${WORLD_DIR}/${world_name}.wld"
    
    log "Preparing to restore backup: $(basename "${backup_path}")"
    log "Target world: ${world_name}"
    
    # Show preview
    preview_backup "$(basename "${backup_path}")"
    
    # Confirm restore
    if [ "${force}" != true ]; then
        echo ""
        log_warning "This will restore the backup and replace the current world (if it exists)."
        read -r -p "Type 'RESTORE' to confirm: " confirm
        
        if [ "${confirm}" != "RESTORE" ]; then
            echo "Restore cancelled."
            return 1
        fi
    fi
    
    # Create backup of current world before restoring
    if [ "${create_backup}" = true ] && [ -f "${current_world}" ]; then
        log "Creating backup of current world before restore..."
        
        local pre_restore_backup="${BACKUP_DIR}/pre_restore_${world_name}_$(date '+%Y%m%d_%H%M%S').tar.gz"
        
        # Create a quick backup
        local temp_dir
        temp_dir=$(mktemp -d)
        mkdir -p "${temp_dir}/${world_name}"
        cp "${current_world}" "${temp_dir}/${world_name}/"
        if [ -f "${current_world}.bak" ]; then
            cp "${current_world}.bak" "${temp_dir}/${world_name}/"
        fi
        
        tar -czf "${pre_restore_backup}" -C "${temp_dir}" "${world_name}"
        rm -rf "${temp_dir}"
        
        if [ -f "${pre_restore_backup}" ]; then
            log_success "Pre-restore backup created: $(basename "${pre_restore_backup}")"
        else
            log_warning "Failed to create pre-restore backup, continuing anyway..."
        fi
    fi
    
    # Extract backup to temporary location
    log "Extracting backup..."
    
    local temp_extract
    temp_extract=$(mktemp -d)
    
    if [[ "${backup_path}" == *.gz ]]; then
        tar -xzf "${backup_path}" -C "${temp_extract}"
    else
        tar -xf "${backup_path}" -C "${temp_extract}"
    fi
    
    if [ $? -ne 0 ]; then
        log_error "Failed to extract backup"
        rm -rf "${temp_extract}"
        return 1
    fi
    
    # Find the world file in extracted contents
    local extracted_world
    extracted_world=$(find "${temp_extract}" -name "*.wld" -type f | head -1)
    
    if [ -z "${extracted_world}" ] || [ ! -f "${extracted_world}" ]; then
        log_error "No world file found in backup"
        rm -rf "${temp_extract}"
        return 1
    fi
    
    # Copy extracted files to world directory
    log "Restoring world files..."
    
    # Get the directory containing the world file
    local extracted_dir
    extracted_dir=$(dirname "${extracted_world}")
    
    # Copy world file
    cp "${extracted_world}" "${WORLD_DIR}/"
    
    # Copy backup file if it exists
    local extracted_bak="${extracted_world}.bak"
    if [ -f "${extracted_bak}" ]; then
        cp "${extracted_bak}" "${WORLD_DIR}/"
    fi
    
    # Cleanup
    rm -rf "${temp_extract}"
    
    # Verify restoration
    local restored_world_name
    restored_world_name=$(basename "${extracted_world}" .wld)
    local restored_world="${WORLD_DIR}/${restored_world_name}.wld"
    
    if [ -f "${restored_world}" ]; then
        log_success "World restored successfully!"
        echo ""
        echo "Restored World:"
        echo "  Name:     ${restored_world_name}"
        echo "  File:     ${restored_world}"
        echo "  Size:     $(du -h "${restored_world}" | cut -f1)"
        echo ""
        log "You can now start the server with: supervisorctl start terraria"
        return 0
    else
        log_error "Restore verification failed - world file not found"
        return 1
    fi
}

#---------------------------------------------------------------
# Restore the latest backup for a world
#---------------------------------------------------------------
restore_latest() {
    local world_name="$1"
    local force=false
    local create_backup=true
    
    # Parse additional arguments
    shift
    while [ $# -gt 0 ]; do
        case "$1" in
            --force) force=true ;;
            --no-backup) create_backup=false ;;
        esac
        shift
    done
    
    if [ -z "${world_name}" ]; then
        log_error "World name is required"
        echo "Usage: $0 restore-latest <world_name> [--force] [--no-backup]"
        return 1
    fi
    
    # Find the latest backup for this world
    local latest_backup
    latest_backup=$(ls -t "${BACKUP_DIR}"/backup_${world_name}_*.tar* 2>/dev/null | head -1)
    
    if [ -z "${latest_backup}" ] || [ ! -f "${latest_backup}" ]; then
        log_error "No backups found for world: ${world_name}"
        echo ""
        echo "Available backups:"
        ls "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null | while read -r f; do
            echo "  $(basename "$f")"
        done
        return 1
    fi
    
    log "Found latest backup: $(basename "${latest_backup}")"
    
    # Build restore arguments
    local restore_args=()
    if [ "${force}" = true ]; then
        restore_args+=(--force)
    fi
    if [ "${create_backup}" = false ]; then
        restore_args+=(--no-backup)
    fi
    
    # Call restore with the latest backup
    restore_backup "$(basename "${latest_backup}")" "${restore_args[@]}"
}

#---------------------------------------------------------------
# List available backups
#---------------------------------------------------------------
list_backups() {
    # Use the backup.sh list function if available
    if [ -x "/terraria/scripts/backup.sh" ]; then
        /terraria/scripts/backup.sh list
    else
        # Fallback implementation
        echo ""
        echo "Available Backups"
        echo "================="
        echo ""
        
        if [ ! -d "${BACKUP_DIR}" ]; then
            echo "Backup directory does not exist: ${BACKUP_DIR}"
            return 1
        fi
        
        ls -lht "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null | \
            awk '{print $NF, $5}' | \
            while read -r file size; do
                echo "  $(basename "$file") (${size})"
            done
        
        local count
        count=$(ls "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null | wc -l)
        echo ""
        echo "Total: ${count} backup(s)"
    fi
}

#---------------------------------------------------------------
# Main entry point
#---------------------------------------------------------------
main() {
    # Ensure directories exist
    mkdir -p "${BACKUP_DIR}" "${WORLD_DIR}"
    
    local command="${1:-help}"
    shift 2>/dev/null || true
    
    case "${command}" in
        restore)
            restore_backup "$@"
            ;;
        restore-latest|latest)
            restore_latest "$@"
            ;;
        preview|view)
            preview_backup "$@"
            ;;
        list|ls)
            list_backups
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
