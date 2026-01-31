#!/bin/bash
#===============================================================================
# Backup Commands - backup, restore, backups, backup-schedule
# Sourced by server.sh - do not run directly
#===============================================================================

#-------------------------------------------------------------------------------
# Command: backup
#-------------------------------------------------------------------------------
cmd_backup() {
    local world_name="$1"
    
    print_header "Creating Backup"
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    # Ensure backup directory exists
    mkdir -p "${BACKUP_DIR}"
    
    print_info "Running backup..."
    
    if [ -n "$world_name" ]; then
        docker_exec /terraria/scripts/backup.sh create "$world_name"
    else
        docker_exec /terraria/scripts/backup.sh create
    fi
    
    echo ""
    print_success "Backup complete!"
    
    # List recent backups
    echo ""
    echo -e "${BOLD}Recent backups:${NC}"
    ls -lt "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null | head -5 | while read -r line; do
        echo "  $line"
    done
}

#-------------------------------------------------------------------------------
# Command: restore
# Runs entirely on the host - no container required
#-------------------------------------------------------------------------------
cmd_restore() {
    local backup_file="$1"
    local WORLD_DIR="${DATA_DIR}/worlds"
    
    print_header "Restore from Backup"
    
    if [ -z "$backup_file" ]; then
        print_error "Backup file name is required"
        echo ""
        echo "Usage: $0 restore <backup-file-name>"
        echo ""
        echo "Available backups:"
        ls -lt "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null | head -10 | while read -r line; do
            echo "  $(basename "$(echo "$line" | awk '{print $NF}')")"
        done
        return 1
    fi
    
    # Check if file exists
    local backup_path
    if [ -f "${backup_file}" ]; then
        backup_path="${backup_file}"
    elif [ -f "${BACKUP_DIR}/${backup_file}" ]; then
        backup_path="${BACKUP_DIR}/${backup_file}"
    else
        print_error "Backup file not found: ${backup_file}"
        return 1
    fi
    
    # Extract world name from backup filename (format: backup_WORLDNAME_YYYYMMDD_HHMMSS.tar.gz)
    local backup_basename
    backup_basename=$(basename "${backup_path}")
    local world_name
    world_name=$(echo "${backup_basename}" | sed 's/^backup_\(.*\)_[0-9]*_[0-9]*.tar.*/\1/')
    
    # Show backup info
    echo ""
    echo "Backup file:  ${backup_basename}"
    echo "World name:   ${world_name}"
    echo "Backup size:  $(du -h "${backup_path}" | cut -f1)"
    echo ""
    
    # Check if current world exists
    local current_world="${WORLD_DIR}/${world_name}.wld"
    if [ -f "${current_world}" ]; then
        print_warning "Current world '${world_name}' exists and will be replaced!"
        echo "  Current size: $(du -h "${current_world}" | cut -f1)"
        echo "  Modified:     $(date -d "@$(stat -c '%Y' "${current_world}")" '+%Y-%m-%d %H:%M:%S')"
        echo ""
    fi
    
    print_warning "This will restore the backup and may overwrite the current world."
    print_warning "The server will be stopped during the restore process."
    echo ""
    read -r -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Restore cancelled."
        return 1
    fi
    
    # Track if we need to restart
    local was_running=false
    
    # Stop container if running
    if container_running; then
        was_running=true
        print_info "Stopping container..."
        sudo docker stop "${CONTAINER_NAME}" >/dev/null
        sleep 2
    fi
    
    # Ensure world directory exists
    mkdir -p "${WORLD_DIR}"
    
    # Create pre-restore backup if current world exists
    if [ -f "${current_world}" ]; then
        print_info "Creating pre-restore backup of current world..."
        local pre_restore_backup="${BACKUP_DIR}/pre_restore_${world_name}_$(date '+%Y%m%d_%H%M%S').tar.gz"
        local temp_backup_dir
        temp_backup_dir=$(mktemp -d)
        mkdir -p "${temp_backup_dir}/${world_name}"
        cp "${current_world}" "${temp_backup_dir}/${world_name}/"
        if [ -f "${current_world}.bak" ]; then
            cp "${current_world}.bak" "${temp_backup_dir}/${world_name}/"
        fi
        tar -czf "${pre_restore_backup}" -C "${temp_backup_dir}" "${world_name}"
        rm -rf "${temp_backup_dir}"
        if [ -f "${pre_restore_backup}" ]; then
            print_success "Pre-restore backup created: $(basename "${pre_restore_backup}")"
        fi
    fi
    
    # Extract backup to temporary location
    print_info "Extracting backup..."
    local temp_extract
    temp_extract=$(mktemp -d)
    
    if [[ "${backup_path}" == *.gz ]]; then
        tar -xzf "${backup_path}" -C "${temp_extract}"
    else
        tar -xf "${backup_path}" -C "${temp_extract}"
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to extract backup"
        rm -rf "${temp_extract}"
        return 1
    fi
    
    # Find the world file in extracted contents
    local extracted_world
    extracted_world=$(find "${temp_extract}" -name "*.wld" -type f | head -1)
    
    if [ -z "${extracted_world}" ] || [ ! -f "${extracted_world}" ]; then
        print_error "No world file found in backup"
        echo "Backup contents:"
        ls -la "${temp_extract}"
        rm -rf "${temp_extract}"
        return 1
    fi
    
    # Copy world files to world directory
    print_info "Restoring world files..."
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
    
    if [ ! -f "${restored_world}" ]; then
        print_error "Restore verification failed - world file not found"
        return 1
    fi
    
    print_success "World restored successfully!"
    echo ""
    echo "Restored World:"
    echo "  Name: ${restored_world_name}"
    echo "  File: ${restored_world}"
    echo "  Size: $(du -h "${restored_world}" | cut -f1)"
    echo ""
    
    # Ask about restarting
    if [ "$was_running" = true ]; then
        read -r -p "Server was running before restore. Start it now? (yes/no): " start_now
        if [ "$start_now" = "yes" ]; then
            print_info "Starting container..."
            sudo docker start "${CONTAINER_NAME}" >/dev/null
            print_success "Server started!"
        else
            print_info "Container stopped. Use '$0 start' to start the server."
        fi
    else
        read -r -p "Start the server now? (yes/no): " start_now
        if [ "$start_now" = "yes" ]; then
            cmd_start
        else
            print_info "Use '$0 start' to start the server."
        fi
    fi
}

#-------------------------------------------------------------------------------
# Command: backups (list backups)
#-------------------------------------------------------------------------------
cmd_backups() {
    print_header "Available Backups"
    
    if [ ! -d "${BACKUP_DIR}" ]; then
        print_warning "Backup directory does not exist"
        return 0
    fi
    
    local count=0
    local total_size=0
    
    printf "%-50s %-12s %-20s\n" "BACKUP FILE" "SIZE" "CREATED"
    printf "%s\n" "--------------------------------------------------------------------------------"
    
    for backup in $(ls -t "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null); do
        if [ -f "$backup" ]; then
            local name
            name=$(basename "$backup")
            local size
            size=$(du -h "$backup" 2>/dev/null | cut -f1)
            local created
            created=$(stat -c '%Y' "$backup" 2>/dev/null)
            local created_date
            created_date=$(date -d "@${created}" '+%Y-%m-%d %H:%M' 2>/dev/null || echo "Unknown")
            
            printf "%-50s %-12s %-20s\n" "$name" "$size" "$created_date"
            ((count++))
        fi
    done
    
    if [ ${count} -eq 0 ]; then
        echo "No backups found."
    else
        echo ""
        echo "Total: ${count} backup(s)"
    fi
    echo ""
}

#-------------------------------------------------------------------------------
# Command: backup-schedule (configure automatic backups)
#-------------------------------------------------------------------------------
cmd_backup_schedule() {
    print_header "Backup Schedule Configuration"
    
    # Check if .env file exists
    if [ ! -f "${ENV_FILE}" ]; then
        print_error "Configuration file not found: ${ENV_FILE}"
        print_info "Run '$0 setup' first to create the configuration file."
        return 1
    fi
    
    # Read current settings from .env
    local current_enabled
    local current_interval
    local current_retention
    local current_on_startup
    
    current_enabled=$(grep "^BACKUP_ENABLED=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "true")
    current_interval=$(grep "^BACKUP_INTERVAL=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "30")
    current_retention=$(grep "^BACKUP_RETENTION=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "48")
    current_on_startup=$(grep "^BACKUP_ON_STARTUP=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "false")
    
    # Display current settings
    echo -e "${BOLD}Current Settings:${NC}"
    echo "  Automatic backups: ${current_enabled}"
    echo "  Backup interval:   ${current_interval} minutes"
    echo "  Backups to keep:   ${current_retention}"
    echo "  Backup on startup: ${current_on_startup}"
    echo ""
    
    # Ask if user wants to change settings
    read -r -p "Would you like to change these settings? (y/n): " change_settings
    if [ "$change_settings" != "y" ] && [ "$change_settings" != "Y" ]; then
        print_info "No changes made."
        return 0
    fi
    
    echo ""
    echo -e "${BOLD}Configure Automatic Backups${NC}"
    echo ""
    
    # Question 1: Enable backups?
    echo "Enable automatic backups?"
    echo "  1) Yes - automatically backup worlds at regular intervals"
    echo "  2) No  - only create backups manually"
    echo ""
    read -r -p "Choose (1 or 2) [current: ${current_enabled}]: " backup_choice
    
    local new_enabled
    case "$backup_choice" in
        1|y|Y|yes|true)
            new_enabled="true"
            ;;
        2|n|N|no|false)
            new_enabled="false"
            ;;
        "")
            new_enabled="${current_enabled}"
            ;;
        *)
            print_warning "Invalid choice, keeping current setting: ${current_enabled}"
            new_enabled="${current_enabled}"
            ;;
    esac
    
    local new_interval="${current_interval}"
    local new_retention="${current_retention}"
    local new_on_startup="${current_on_startup}"
    
    # Only ask additional questions if backups are enabled
    if [ "$new_enabled" = "true" ]; then
        echo ""
        
        # Question 2: Backup interval
        echo "How often should backups be created?"
        echo "  Common intervals:"
        echo "    15  - Every 15 minutes (for active servers)"
        echo "    30  - Every 30 minutes (recommended)"
        echo "    60  - Every hour"
        echo "    120 - Every 2 hours"
        echo ""
        read -r -p "Backup interval in minutes [current: ${current_interval}]: " interval_input
        
        if [ -n "$interval_input" ]; then
            # Validate numeric input
            if [[ "$interval_input" =~ ^[0-9]+$ ]] && [ "$interval_input" -ge 1 ]; then
                new_interval="$interval_input"
            else
                print_warning "Invalid number, keeping current setting: ${current_interval} minutes"
            fi
        fi
        
        echo ""
        
        # Question 3: Backup retention
        echo "How many backups should be kept?"
        echo "  Examples:"
        echo "    12  - Keep last 12 backups (~6 hours at 30-min intervals)"
        echo "    24  - Keep last 24 backups (~12 hours)"
        echo "    48  - Keep last 48 backups (~24 hours, recommended)"
        echo "    96  - Keep last 96 backups (~2 days)"
        echo ""
        echo "  Tip: More backups = more disk space used"
        echo ""
        read -r -p "Number of backups to keep [current: ${current_retention}]: " retention_input
        
        if [ -n "$retention_input" ]; then
            # Validate numeric input
            if [[ "$retention_input" =~ ^[0-9]+$ ]] && [ "$retention_input" -ge 1 ]; then
                new_retention="$retention_input"
            else
                print_warning "Invalid number, keeping current setting: ${current_retention}"
            fi
        fi
        
        echo ""
        
        # Question 4: Backup on startup
        echo "Create a backup when the server starts?"
        echo "  1) Yes - good for safety before updates"
        echo "  2) No  - rely on scheduled backups only"
        echo ""
        read -r -p "Backup on startup? (1 or 2) [current: ${current_on_startup}]: " startup_choice
        
        case "$startup_choice" in
            1|y|Y|yes|true)
                new_on_startup="true"
                ;;
            2|n|N|no|false)
                new_on_startup="false"
                ;;
            "")
                new_on_startup="${current_on_startup}"
                ;;
            *)
                print_warning "Invalid choice, keeping current setting: ${current_on_startup}"
                ;;
        esac
    fi
    
    echo ""
    echo -e "${BOLD}New Settings:${NC}"
    echo "  Automatic backups: ${new_enabled}"
    if [ "$new_enabled" = "true" ]; then
        echo "  Backup interval:   ${new_interval} minutes"
        echo "  Backups to keep:   ${new_retention}"
        echo "  Backup on startup: ${new_on_startup}"
        
        # Calculate approximate storage info
        local hours_covered=$((new_interval * new_retention / 60))
        echo ""
        echo -e "  ${CYAN}This will keep approximately ${hours_covered} hours of backups.${NC}"
    fi
    echo ""
    
    read -r -p "Save these settings? (y/n): " confirm_save
    if [ "$confirm_save" != "y" ] && [ "$confirm_save" != "Y" ]; then
        print_info "Changes discarded."
        return 0
    fi
    
    # Update .env file
    print_info "Updating configuration..."
    
    # Use sed to update values in place
    sed -i "s/^BACKUP_ENABLED=.*/BACKUP_ENABLED=${new_enabled}/" "${ENV_FILE}"
    sed -i "s/^BACKUP_INTERVAL=.*/BACKUP_INTERVAL=${new_interval}/" "${ENV_FILE}"
    sed -i "s/^BACKUP_RETENTION=.*/BACKUP_RETENTION=${new_retention}/" "${ENV_FILE}"
    sed -i "s/^BACKUP_ON_STARTUP=.*/BACKUP_ON_STARTUP=${new_on_startup}/" "${ENV_FILE}"
    
    print_success "Configuration saved!"
    echo ""
    
    # If container is running, offer to restart
    if container_running; then
        print_warning "The server needs to be restarted for changes to take effect."
        echo ""
        read -r -p "Restart the server now? (y/n): " restart_now
        if [ "$restart_now" = "y" ] || [ "$restart_now" = "Y" ]; then
            echo ""
            cmd_restart
        else
            print_info "Restart the server later with: $0 restart"
        fi
    else
        print_info "Changes will apply when the server starts."
    fi
}
