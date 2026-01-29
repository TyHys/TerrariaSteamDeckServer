#!/bin/bash
#---------------------------------------------------------------
# Backup Scheduler Daemon
# Runs automated backups at configured intervals
# Managed by Supervisor
#---------------------------------------------------------------

BACKUP_SCRIPT="/terraria/scripts/backup.sh"
LOG_FILE="/terraria/logs/backup-scheduler.log"

# Configuration from environment (with defaults)
BACKUP_ENABLED="${BACKUP_ENABLED:-true}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-30}"           # Minutes between backups
BACKUP_RETENTION="${BACKUP_RETENTION:-48}"         # Number of backups to keep
BACKUP_ON_STARTUP="${BACKUP_ON_STARTUP:-false}"    # Create backup immediately on start

# Export backup settings for backup.sh
export BACKUP_RETENTION

#---------------------------------------------------------------
# Logging helpers
#---------------------------------------------------------------
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] $1"
    echo "$msg"
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

log_error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] [SCHEDULER] [ERROR] $1"
    echo "$msg" >&2
    echo "$msg" >> "${LOG_FILE}" 2>/dev/null
}

#---------------------------------------------------------------
# Signal handlers
#---------------------------------------------------------------
shutdown=false

shutdown_handler() {
    log "Received shutdown signal, stopping scheduler..."
    shutdown=true
}

trap shutdown_handler SIGTERM SIGINT SIGQUIT

#---------------------------------------------------------------
# Check if server is running and has a world loaded
#---------------------------------------------------------------
is_server_active() {
    # Check if TerrariaServer process exists
    if pgrep -f "TerrariaServer" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

#---------------------------------------------------------------
# Check if there are worlds to backup
#---------------------------------------------------------------
has_worlds() {
    local world_count
    world_count=$(ls "${WORLD_DIR:-/terraria/worlds}"/*.wld 2>/dev/null | wc -l)
    [ "${world_count}" -gt 0 ]
}

#---------------------------------------------------------------
# Run backup
#---------------------------------------------------------------
run_backup() {
    if [ ! -x "${BACKUP_SCRIPT}" ]; then
        log_error "Backup script not found or not executable: ${BACKUP_SCRIPT}"
        return 1
    fi
    
    log "Starting scheduled backup..."
    
    # Run the backup script
    "${BACKUP_SCRIPT}" create 2>&1 | while read -r line; do
        log "  ${line}"
    done
    
    local result=${PIPESTATUS[0]}
    
    if [ ${result} -eq 0 ]; then
        log "Scheduled backup completed successfully"
    else
        log_error "Scheduled backup failed with exit code: ${result}"
    fi
    
    return ${result}
}

#---------------------------------------------------------------
# Calculate next backup time
#---------------------------------------------------------------
get_next_backup_time() {
    local interval_seconds=$((BACKUP_INTERVAL * 60))
    local next_time=$(($(date +%s) + interval_seconds))
    date -d "@${next_time}" '+%Y-%m-%d %H:%M:%S'
}

#---------------------------------------------------------------
# Display scheduler status
#---------------------------------------------------------------
display_status() {
    log "========================================"
    log "Backup Scheduler Configuration"
    log "========================================"
    log "Enabled:       ${BACKUP_ENABLED}"
    log "Interval:      ${BACKUP_INTERVAL} minutes"
    log "Retention:     ${BACKUP_RETENTION} backups"
    log "On Startup:    ${BACKUP_ON_STARTUP}"
    log "Backup Script: ${BACKUP_SCRIPT}"
    log "========================================"
}

#---------------------------------------------------------------
# Main scheduler loop
#---------------------------------------------------------------
main() {
    log "Backup scheduler starting..."
    
    # Display configuration
    display_status
    
    # Check if backups are enabled
    if [ "${BACKUP_ENABLED}" != "true" ]; then
        log "Backups are disabled (BACKUP_ENABLED=${BACKUP_ENABLED})"
        log "Scheduler will sleep indefinitely. Set BACKUP_ENABLED=true to enable."
        
        # Sleep forever (but still respond to signals)
        while [ "${shutdown}" != true ]; do
            sleep 60
        done
        
        log "Scheduler stopped."
        exit 0
    fi
    
    # Create backup on startup if configured
    if [ "${BACKUP_ON_STARTUP}" = "true" ]; then
        log "Backup on startup is enabled, checking for worlds..."
        
        # Wait a bit for server to potentially start and create/load worlds
        sleep 10
        
        if has_worlds; then
            run_backup
        else
            log "No worlds found, skipping startup backup"
        fi
    fi
    
    # Calculate interval in seconds
    local interval_seconds=$((BACKUP_INTERVAL * 60))
    log "Scheduling backups every ${BACKUP_INTERVAL} minutes (${interval_seconds} seconds)"
    log "Next backup at: $(get_next_backup_time)"
    
    # Main loop
    local sleep_counter=0
    local check_interval=60  # Check every minute for shutdown signal
    
    while [ "${shutdown}" != true ]; do
        # Sleep in small increments to respond to signals
        sleep ${check_interval}
        
        if [ "${shutdown}" = true ]; then
            break
        fi
        
        # Increment counter
        ((sleep_counter += check_interval))
        
        # Check if it's time for a backup
        if [ ${sleep_counter} -ge ${interval_seconds} ]; then
            sleep_counter=0
            
            log "Backup interval reached"
            
            # Check if there are worlds to backup
            if has_worlds; then
                # Check if server is running (optional - we can backup even if server is stopped)
                if is_server_active; then
                    log "Server is running, proceeding with backup"
                else
                    log "Server is not running, still backing up world files"
                fi
                
                run_backup
            else
                log "No worlds found, skipping backup"
            fi
            
            log "Next backup at: $(get_next_backup_time)"
        fi
    done
    
    log "Scheduler stopped."
    exit 0
}

#---------------------------------------------------------------
# Handle command-line arguments
#---------------------------------------------------------------
case "${1:-}" in
    status)
        display_status
        exit 0
        ;;
    now|backup)
        log "Manual backup requested"
        run_backup
        exit $?
        ;;
    help|-h|--help)
        echo "Terraria Backup Scheduler"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  (no args)    Run the scheduler daemon"
        echo "  status       Display scheduler configuration"
        echo "  now          Run a backup immediately"
        echo "  help         Show this help"
        echo ""
        echo "Environment Variables:"
        echo "  BACKUP_ENABLED     Enable/disable scheduler (default: true)"
        echo "  BACKUP_INTERVAL    Minutes between backups (default: 30)"
        echo "  BACKUP_RETENTION   Number of backups to keep (default: 48)"
        echo "  BACKUP_ON_STARTUP  Create backup on scheduler start (default: false)"
        echo ""
        exit 0
        ;;
    *)
        main
        ;;
esac
