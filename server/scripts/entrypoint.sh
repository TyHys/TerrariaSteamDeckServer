#!/bin/bash
#---------------------------------------------------------------
# Container Entrypoint Script
# Initializes the container and starts Supervisor
#---------------------------------------------------------------

set -e

LOG_DIR="/terraria/logs"
WORLD_DIR="/terraria/worlds"
CONFIG_DIR="/terraria/config"
BACKUP_DIR="${BACKUP_DIR:-/terraria/backups}"

#---------------------------------------------------------------
# Logging helper
#---------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ENTRYPOINT] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ENTRYPOINT] [ERROR] $1" >&2
}

#---------------------------------------------------------------
# Initialize directories and permissions
#---------------------------------------------------------------
init_directories() {
    log "Initializing directories..."
    
    # Create directories if they don't exist
    mkdir -p "${LOG_DIR}" "${WORLD_DIR}" "${CONFIG_DIR}" "${BACKUP_DIR}"
    
    # Copy default config files to config volume if they don't exist
    if [ -d /terraria/defaults ]; then
        for file in /terraria/defaults/*; do
            filename=$(basename "$file")
            if [ ! -f "${CONFIG_DIR}/${filename}" ]; then
                cp "$file" "${CONFIG_DIR}/${filename}"
                log "Copied default config: ${filename}"
            fi
        done
    fi
    
    # Set proper ownership (we start as root, supervisor switches to terraria)
    chown -R terraria:terraria "${LOG_DIR}" "${WORLD_DIR}" "${CONFIG_DIR}" "${BACKUP_DIR}"
    
    # Ensure scripts are executable
    chmod +x /terraria/scripts/*.sh
    
    log "Directories initialized."
}

#---------------------------------------------------------------
# Initialize command FIFO for server commands
#---------------------------------------------------------------
init_command_fifo() {
    local COMMAND_FIFO="/tmp/terraria-command.fifo"
    
    log "Initializing command FIFO..."
    
    # Remove any stale FIFO from previous runs (we're root, so we can always remove it)
    rm -f "${COMMAND_FIFO}"
    
    # Create fresh FIFO with world-writable permissions
    mkfifo -m 0666 "${COMMAND_FIFO}"
    
    # Set ownership to terraria user so the wrapper can manage it
    chown terraria:terraria "${COMMAND_FIFO}"
    
    log "Command FIFO initialized at ${COMMAND_FIFO}"
}

#---------------------------------------------------------------
# Set up log rotation cron job
#---------------------------------------------------------------
setup_logrotate() {
    log "Setting up log rotation..."
    
    # Copy logrotate config if it exists (check both locations)
    if [ -f /terraria/config/logrotate.conf ]; then
        cp /terraria/config/logrotate.conf /etc/logrotate.d/terraria
        log "Log rotation configured."
    elif [ -f /terraria/defaults/logrotate.conf ]; then
        cp /terraria/defaults/logrotate.conf /etc/logrotate.d/terraria
        log "Log rotation configured from defaults."
    else
        log "No logrotate config found, skipping."
    fi
}

#---------------------------------------------------------------
# Display startup banner
#---------------------------------------------------------------
display_banner() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║       Terraria Dedicated Server for Steam Deck            ║"
    echo "║                     v10.0.0                               ║"
    echo "╠═══════════════════════════════════════════════════════════╣"
    echo "║  Process Manager:   Supervisor                            ║"
    echo "║  Auto-restart:      Enabled                               ║"
    echo "║  Log Rotation:      Enabled                               ║"
    echo "║  Backup Scheduler:  ${BACKUP_ENABLED:-true}                               ║"
    echo "╠═══════════════════════════════════════════════════════════╣"
    echo "║  Game Server:       Port ${SERVER_PORT:-7777}                                ║"
    echo "║  Management:        ./server.sh                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
}

#---------------------------------------------------------------
# Display configuration summary
#---------------------------------------------------------------
display_config() {
    log "========================================"
    log "Configuration Summary"
    log "========================================"
    log "WORLD_NAME:       ${WORLD_NAME:-world}"
    log "MAX_PLAYERS:      ${MAX_PLAYERS:-8}"
    log "SERVER_PORT:      ${SERVER_PORT:-7777}"
    log "DIFFICULTY:       ${DIFFICULTY:-0}"
    log "AUTOCREATE:       ${AUTOCREATE:-2}"
    log "SECURE:           ${SECURE:-1}"
    log "RESTART_DELAY:    ${RESTART_DELAY:-5}s"
    log "----------------------------------------"
    log "BACKUP_ENABLED:   ${BACKUP_ENABLED:-true}"
    log "BACKUP_INTERVAL:  ${BACKUP_INTERVAL:-30} minutes"
    log "BACKUP_RETENTION: ${BACKUP_RETENTION:-48} backups"
    log "========================================"
}

#---------------------------------------------------------------
# Graceful shutdown handler
#---------------------------------------------------------------
shutdown_handler() {
    log "Container shutdown signal received..."
    
    # Stop supervisor gracefully - this will stop all managed processes
    if [ -f /tmp/supervisord.pid ]; then
        log "Stopping Supervisor and all managed processes..."
        supervisorctl shutdown
        
        # Wait for supervisor to terminate
        local wait_time=0
        while [ -f /tmp/supervisord.pid ] && [ ${wait_time} -lt 30 ]; do
            sleep 1
            ((wait_time++))
        done
        
        log "All processes stopped."
    fi
    
    exit 0
}

trap shutdown_handler SIGTERM SIGINT SIGQUIT

#---------------------------------------------------------------
# Main entry point
#---------------------------------------------------------------
main() {
    display_banner
    
    log "Starting container initialization..."
    
    # Initialize directories and permissions
    init_directories
    
    # Initialize command FIFO (must be done as root before supervisor starts)
    init_command_fifo
    
    # Set up log rotation
    setup_logrotate
    
    # Display configuration
    display_config
    
    # Start supervisor (runs in foreground)
    log "Starting Supervisor process manager..."
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/terraria.conf
}

# Execute main function
main "$@"
