#!/bin/bash
#---------------------------------------------------------------
# Backup Script
# Creates compressed backups of Terraria worlds
# Supports manual and scheduled backup operations
#---------------------------------------------------------------

WORLD_DIR="${WORLD_DIR:-/terraria/worlds}"
BACKUP_DIR="${BACKUP_DIR:-/terraria/backups}"
LOG_FILE="/terraria/logs/backup.log"

# Backup settings from environment
BACKUP_RETENTION="${BACKUP_RETENTION:-48}"        # Number of backups to keep
BACKUP_COMPRESSION="${BACKUP_COMPRESSION:-gzip}"  # gzip or none

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
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] $1"
    echo -e "$msg"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] [ERROR] $1"
    echo -e "${RED}$msg${NC}" >&2
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_success() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] [SUCCESS] $1"
    echo -e "${GREEN}$msg${NC}"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_warning() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [BACKUP] [WARNING] $1"
    echo -e "${YELLOW}$msg${NC}"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

#---------------------------------------------------------------
# Display usage/help
#---------------------------------------------------------------
usage() {
    echo ""
    echo "Terraria Backup Manager"
    echo "======================="
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  create [world]         Create a backup (all worlds or specific world)"
    echo "  list                   List all backups"
    echo "  info <backup_file>     Show backup details"
    echo "  cleanup                Remove old backups (keeps ${BACKUP_RETENTION})"
    echo "  verify <backup_file>   Verify backup integrity"
    echo "  help                   Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  BACKUP_RETENTION       Number of backups to keep (default: 48)"
    echo "  BACKUP_COMPRESSION     Compression type: gzip or none (default: gzip)"
    echo ""
    echo "Examples:"
    echo "  $0 create              # Backup all worlds"
    echo "  $0 create MyWorld      # Backup specific world"
    echo "  $0 list                # List all backups"
    echo "  $0 cleanup             # Remove old backups"
    echo ""
}

#---------------------------------------------------------------
# Generate backup filename with timestamp
#---------------------------------------------------------------
generate_backup_name() {
    local world_name="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    
    if [ "${BACKUP_COMPRESSION}" = "gzip" ]; then
        echo "backup_${world_name}_${timestamp}.tar.gz"
    else
        echo "backup_${world_name}_${timestamp}.tar"
    fi
}

#---------------------------------------------------------------
# Create a backup of a single world
#---------------------------------------------------------------
backup_world() {
    local world_name="$1"
    local world_file="${WORLD_DIR}/${world_name}.wld"
    
    if [ ! -f "${world_file}" ]; then
        log_error "World file not found: ${world_file}"
        return 1
    fi
    
    local backup_name
    backup_name=$(generate_backup_name "${world_name}")
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    log "Backing up world: ${world_name}"
    
    # Create a temporary directory for backup contents
    local temp_dir
    temp_dir=$(mktemp -d)
    local backup_content_dir="${temp_dir}/${world_name}"
    mkdir -p "${backup_content_dir}"
    
    # Copy world file and backup file if it exists
    cp "${world_file}" "${backup_content_dir}/"
    if [ -f "${world_file}.bak" ]; then
        cp "${world_file}.bak" "${backup_content_dir}/"
    fi
    
    # Create backup metadata
    cat > "${backup_content_dir}/backup_info.txt" << EOF
Terraria World Backup
=====================
World Name: ${world_name}
Backup Date: $(date '+%Y-%m-%d %H:%M:%S')
Backup Tool: TerrariaSteamDeckServer backup.sh
World File Size: $(stat -c%s "${world_file}" 2>/dev/null || echo "unknown") bytes
Hostname: $(hostname)
EOF
    
    # Create the archive
    if [ "${BACKUP_COMPRESSION}" = "gzip" ]; then
        tar -czf "${backup_path}" -C "${temp_dir}" "${world_name}"
    else
        tar -cf "${backup_path}" -C "${temp_dir}" "${world_name}"
    fi
    
    # Cleanup temp directory
    rm -rf "${temp_dir}"
    
    # Verify backup was created
    if [ -f "${backup_path}" ]; then
        local backup_size
        backup_size=$(du -h "${backup_path}" | cut -f1)
        log_success "Backup created: ${backup_name} (${backup_size})"
        return 0
    else
        log_error "Failed to create backup: ${backup_name}"
        return 1
    fi
}

#---------------------------------------------------------------
# Create backups for all worlds or a specific world
#---------------------------------------------------------------
create_backup() {
    local specific_world="$1"
    local success_count=0
    local fail_count=0
    
    # Ensure backup directory exists
    mkdir -p "${BACKUP_DIR}"
    
    log "Starting backup operation..."
    
    if [ -n "${specific_world}" ]; then
        # Backup specific world
        if backup_world "${specific_world}"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    else
        # Backup all worlds
        for world in "${WORLD_DIR}"/*.wld 2>/dev/null; do
            if [ -f "$world" ]; then
                local world_name
                world_name=$(basename "$world" .wld)
                if backup_world "${world_name}"; then
                    ((success_count++))
                else
                    ((fail_count++))
                fi
            fi
        done
    fi
    
    if [ ${success_count} -eq 0 ] && [ ${fail_count} -eq 0 ]; then
        log_warning "No worlds found to backup"
        return 0
    fi
    
    log "Backup complete: ${success_count} successful, ${fail_count} failed"
    
    # Run cleanup after creating backups
    cleanup_old_backups
    
    return ${fail_count}
}

#---------------------------------------------------------------
# List all backups
#---------------------------------------------------------------
list_backups() {
    log "Listing backups in ${BACKUP_DIR}"
    
    echo ""
    echo "Available Backups"
    echo "================="
    echo ""
    
    if [ ! -d "${BACKUP_DIR}" ]; then
        log_warning "Backup directory does not exist: ${BACKUP_DIR}"
        return 1
    fi
    
    local count=0
    local total_size=0
    
    printf "%-45s %-12s %-20s\n" "BACKUP FILE" "SIZE" "CREATED"
    printf "%s\n" "--------------------------------------------------------------------------------"
    
    # Sort by modification time (newest first)
    for backup in $(ls -t "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null); do
        if [ -f "$backup" ]; then
            local name
            name=$(basename "$backup")
            local size
            size=$(du -h "$backup" 2>/dev/null | cut -f1)
            local size_bytes
            size_bytes=$(stat -c%s "$backup" 2>/dev/null || echo 0)
            local created
            created=$(stat -c '%Y' "$backup" 2>/dev/null)
            local created_date
            created_date=$(date -d "@${created}" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
            
            printf "%-45s %-12s %-20s\n" "$name" "$size" "$created_date"
            ((count++))
            ((total_size += size_bytes))
        fi
    done
    
    if [ ${count} -eq 0 ]; then
        echo "No backups found."
    else
        echo ""
        echo "Total: ${count} backup(s), $(numfmt --to=iec ${total_size} 2>/dev/null || echo "${total_size} bytes")"
        echo "Retention policy: Keep last ${BACKUP_RETENTION} backups"
    fi
    echo ""
    
    return 0
}

#---------------------------------------------------------------
# Show backup info
#---------------------------------------------------------------
show_backup_info() {
    local backup_file="$1"
    
    if [ -z "${backup_file}" ]; then
        log_error "Backup file name is required"
        echo "Usage: $0 info <backup_file>"
        return 1
    fi
    
    # Handle both full path and just filename
    local backup_path
    if [ -f "${backup_file}" ]; then
        backup_path="${backup_file}"
    elif [ -f "${BACKUP_DIR}/${backup_file}" ]; then
        backup_path="${BACKUP_DIR}/${backup_file}"
    else
        log_error "Backup not found: ${backup_file}"
        return 1
    fi
    
    echo ""
    echo "Backup Information"
    echo "=================="
    echo ""
    
    local name
    name=$(basename "${backup_path}")
    local size
    size=$(du -h "${backup_path}" | cut -f1)
    local size_bytes
    size_bytes=$(stat -c%s "${backup_path}")
    local created
    created=$(stat -c '%Y' "${backup_path}")
    
    echo "File:       ${backup_path}"
    echo "Size:       ${size} (${size_bytes} bytes)"
    echo "Created:    $(date -d "@${created}" '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Contents:"
    
    # List archive contents
    if [[ "${backup_path}" == *.gz ]]; then
        tar -tzf "${backup_path}" 2>/dev/null | head -20
    else
        tar -tf "${backup_path}" 2>/dev/null | head -20
    fi
    
    echo ""
    
    # Try to extract and show backup_info.txt
    local temp_dir
    temp_dir=$(mktemp -d)
    
    if [[ "${backup_path}" == *.gz ]]; then
        tar -xzf "${backup_path}" -C "${temp_dir}" --wildcards "*/backup_info.txt" 2>/dev/null
    else
        tar -xf "${backup_path}" -C "${temp_dir}" --wildcards "*/backup_info.txt" 2>/dev/null
    fi
    
    local info_file
    info_file=$(find "${temp_dir}" -name "backup_info.txt" -type f 2>/dev/null | head -1)
    
    if [ -f "${info_file}" ]; then
        echo "Backup Metadata:"
        echo "----------------"
        cat "${info_file}"
        echo ""
    fi
    
    rm -rf "${temp_dir}"
    
    return 0
}

#---------------------------------------------------------------
# Verify backup integrity
#---------------------------------------------------------------
verify_backup() {
    local backup_file="$1"
    
    if [ -z "${backup_file}" ]; then
        log_error "Backup file name is required"
        echo "Usage: $0 verify <backup_file>"
        return 1
    fi
    
    # Handle both full path and just filename
    local backup_path
    if [ -f "${backup_file}" ]; then
        backup_path="${backup_file}"
    elif [ -f "${BACKUP_DIR}/${backup_file}" ]; then
        backup_path="${BACKUP_DIR}/${backup_file}"
    else
        log_error "Backup not found: ${backup_file}"
        return 1
    fi
    
    log "Verifying backup: $(basename "${backup_path}")"
    
    # Test archive integrity
    local test_result
    if [[ "${backup_path}" == *.gz ]]; then
        test_result=$(tar -tzf "${backup_path}" 2>&1)
    else
        test_result=$(tar -tf "${backup_path}" 2>&1)
    fi
    
    if [ $? -eq 0 ]; then
        # Check for expected files
        if echo "${test_result}" | grep -q ".wld"; then
            log_success "Backup is valid and contains world file(s)"
            return 0
        else
            log_warning "Backup is valid but does not contain .wld files"
            return 1
        fi
    else
        log_error "Backup is corrupted or invalid"
        echo "${test_result}"
        return 1
    fi
}

#---------------------------------------------------------------
# Cleanup old backups (retention policy)
#---------------------------------------------------------------
cleanup_old_backups() {
    log "Checking backup retention (keeping last ${BACKUP_RETENTION} backups per world)..."
    
    if [ ! -d "${BACKUP_DIR}" ]; then
        return 0
    fi
    
    # Get list of unique world names from backups
    local worlds
    worlds=$(ls "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null | \
             sed 's/.*backup_\(.*\)_[0-9]*_[0-9]*.tar.*/\1/' | \
             sort -u)
    
    local deleted_count=0
    
    for world in ${worlds}; do
        # Get backups for this world, sorted by date (oldest first)
        local backups
        backups=$(ls -t "${BACKUP_DIR}"/backup_${world}_*.tar* 2>/dev/null)
        local backup_count
        backup_count=$(echo "${backups}" | wc -w)
        
        if [ "${backup_count}" -gt "${BACKUP_RETENTION}" ]; then
            local to_delete=$((backup_count - BACKUP_RETENTION))
            log "World '${world}': ${backup_count} backups, deleting ${to_delete} oldest"
            
            # Delete oldest backups (they're at the end since we sorted by -t)
            echo "${backups}" | tail -n "${to_delete}" | while read -r backup; do
                if [ -f "${backup}" ]; then
                    log "Deleting old backup: $(basename "${backup}")"
                    rm -f "${backup}"
                    ((deleted_count++))
                fi
            done
        fi
    done
    
    if [ ${deleted_count} -gt 0 ]; then
        log "Cleanup complete: ${deleted_count} old backup(s) deleted"
    fi
    
    return 0
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
        create|backup)
            create_backup "$@"
            ;;
        list|ls)
            list_backups
            ;;
        info|show)
            show_backup_info "$@"
            ;;
        verify|check)
            verify_backup "$@"
            ;;
        cleanup|clean)
            cleanup_old_backups
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
