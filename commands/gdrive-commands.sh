#!/bin/bash
#===============================================================================
# Google Drive Commands - gdrive-sync-setup, gdrive-sync, gdrive-auto
# Sourced by server.sh - do not run directly
#===============================================================================

#-------------------------------------------------------------------------------
# Command: gdrive-sync-setup
# Interactive setup for rclone/Google Drive integration
#-------------------------------------------------------------------------------
cmd_gdrive_sync_setup() {
    print_header "Google Drive Backup Setup (rclone)"

    # Check for rclone installation
    if ! command -v rclone &>/dev/null; then
        print_error "rclone is not installed or not in PATH."
        print_info "Please install rclone using your package manager (e.g., sudo pacman -S rclone)."
        print_info "For Steam Deck/Arch Linux, you may need to disable read-only mode or install to user space."
        print_info "Visit https://rclone.org/install/ for instructions."
        return 1
    fi

    print_info "This setup will configure rclone to sync your backups to Google Drive."
    echo ""

    # Check for .env
    if [ ! -f "${ENV_FILE}" ]; then
        print_error "Configuration file not found: ${ENV_FILE}"
        print_info "Run '$0 setup' first."
        return 1
    fi

    # Load current vars
    local current_remote
    local current_path
    current_remote=$(grep "^RCLONE_REMOTE=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 | tr -d '"')
    current_path=$(grep "^RCLONE_PATH=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 | tr -d '"')

    # Prompt for Remote Name
    local default_remote="${current_remote:-TerrariaServerBackup}"
    read -r -p "Enter rclone remote name [${default_remote}]: " remote_name
    remote_name="${remote_name:-$default_remote}"

    # Configure Remote
    if ! rclone listremotes | grep -q "^${remote_name}:$"; then
        print_info "Creating new rclone remote '${remote_name}'..."
        echo "Authentication requires a web browser."
        rclone config create "$remote_name" drive scope=drive
        
        if [ $? -ne 0 ]; then
            print_error "Failed to create rclone configuration."
            return 1
        fi
    else
        print_info "Remote '${remote_name}' already exists."
        read -r -p "Reconfigure authentication? (y/n): " reauth_choice
        if [[ "$reauth_choice" == [Yy]* ]]; then
           rclone config reconnect "${remote_name}:"
        fi
    fi

    # Prompt for Drive Folder Path
    local default_path="${current_path:-terraria-backups}"
    read -r -p "Enter Google Drive folder path to sync to [${default_path}]: " remote_path
    remote_path="${remote_path:-$default_path}"

    # Update .env
    print_info "Updating configuration..."
    
    # Remove old entries if they exist
    sed -i '/^RCLONE_REMOTE=/d' "${ENV_FILE}"
    sed -i '/^RCLONE_PATH=/d' "${ENV_FILE}"
    
    # Add new entries
    echo "RCLONE_REMOTE=\"${remote_name}\"" >> "${ENV_FILE}"
    echo "RCLONE_PATH=\"${remote_path}\"" >> "${ENV_FILE}"
    
    print_success "Google Drive configuration saved!"
    echo "  Remote: ${remote_name}"
    echo "  Path:   ${remote_path}"
    echo ""
    print_info "Test connection with: $0 gdrive-sync"
}

#-------------------------------------------------------------------------------
# Command: gdrive-sync
# Performs one-time sync of backup folder to Google Drive
#-------------------------------------------------------------------------------
cmd_gdrive_sync() {
    print_header "Google Drive Sync"

    if ! command -v rclone &>/dev/null; then
        print_error "rclone is not installed."
        return 1
    fi

    # Load config if .env exists
    if [ -f "${ENV_FILE}" ]; then
        source "${ENV_FILE}"
    fi

    if [ -z "$RCLONE_REMOTE" ] || [ -z "$RCLONE_PATH" ]; then
        print_error "Google Drive sync is not configured."
        print_info "Run '$0 gdrive-sync-setup' to configure."
        return 1
    fi

    if [ ! -d "${BACKUP_DIR}" ]; then
        print_warning "No backup directory found at ${BACKUP_DIR}"
        return 0
    fi

    print_info "Syncing backups to Google Drive..."
    print_info "  Source: ${BACKUP_DIR}"
    print_info "  Target: ${RCLONE_REMOTE}:${RCLONE_PATH}"
    echo ""

    # Run rclone sync
    if rclone sync -P --transfers=3 "${BACKUP_DIR}" "${RCLONE_REMOTE}:${RCLONE_PATH}"; then
        echo ""
        print_success "Sync completed successfully!"
    else
        echo ""
        print_error "Sync failed. Check your internet connection and rclone configuration."
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Command: gdrive-auto
# Manages background sync daemon
# Usage: ./server.sh gdrive-auto [start|stop|status]
#-------------------------------------------------------------------------------
cmd_gdrive_auto() {
    local action="${1:-status}"
    local PID_FILE="/tmp/terraria_gdrive_sync.pid"
    local LOG_FILE="/tmp/terraria_gdrive_sync.log"
    
    case "$action" in
        start)
            print_header "Starting Google Drive Sync Daemon"
            
            if [ -f "$PID_FILE" ]; then
                local pid
                pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    print_warning "Daemon is already running (PID $pid)"
                    return 0
                else
                    rm "$PID_FILE"
                fi
            fi

            # Check configuration first
            if [ -f "${ENV_FILE}" ]; then
                source "${ENV_FILE}"
            fi
            if [ -z "$RCLONE_REMOTE" ] || [ -z "$RCLONE_PATH" ]; then
                 print_error "Not configured. Run '$0 gdrive-sync-setup' first."
                 return 1
            fi

            print_info "Starting background sync (every 60 minutes)..."
            
            # Start background loop
            (
                while true; do
                    # Reload env to pick up changes
                    if [ -f "${PROJECT_ROOT}/docker/.env" ]; then
                        source "${PROJECT_ROOT}/docker/.env"
                    fi
                    
                    if [ -n "$RCLONE_REMOTE" ] && [ -n "$RCLONE_PATH" ] && [ -d "${PROJECT_ROOT}/data/backups" ]; then
                        echo "[$(date)] Starting sync..." >> "$LOG_FILE"
                        rclone sync --transfers=3 "${PROJECT_ROOT}/data/backups" "$RCLONE_REMOTE:$RCLONE_PATH" >> "$LOG_FILE" 2>&1
                        echo "[$(date)] Sync finished (Exit: $?)" >> "$LOG_FILE"
                    fi
                    
                    sleep 3600 # 1 hour
                done
            ) > /dev/null 2>&1 &
            
            echo $! > "$PID_FILE"
            print_success "Daemon started (PID $(cat "$PID_FILE"))"
            print_info "Logs: $LOG_FILE"
            ;;
            
        stop)
            print_header "Stopping Google Drive Sync Daemon"
            if [ -f "$PID_FILE" ]; then
                local pid
                pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    kill "$pid"
                    print_success "Daemon stopped"
                else
                    print_warning "Daemon process $pid not found"
                fi
                rm "$PID_FILE"
            else
                print_warning "Daemon is not running"
            fi
            ;;
            
        status)
            print_header "Google Drive Sync Daemon Status"
            if [ -f "$PID_FILE" ]; then
                local pid
                pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    print_success "Active (PID $pid)"
                    echo ""
                    echo -e "${BOLD}Recent Logs:${NC}"
                    tail -n 5 "$LOG_FILE" 2>/dev/null
                else
                     print_error "PID file exists but process is dead"
                     rm "$PID_FILE"
                fi
            else
                print_info "Stopped"
            fi
            ;;
            
        *)
            print_error "Unknown action: $action"
            echo "Usage: $0 gdrive-auto [start|stop|status]"
            return 1
            ;;
    esac
}
