#!/bin/bash
#---------------------------------------------------------------
# Container Entrypoint Script
# Initializes the container and starts Supervisor
#---------------------------------------------------------------

set -e

LOG_DIR="/terraria/logs"
WORLD_DIR="/terraria/worlds"
CONFIG_DIR="/terraria/config"

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
    mkdir -p "${LOG_DIR}" "${WORLD_DIR}" "${CONFIG_DIR}"
    
    # Set proper ownership (we start as root, supervisor switches to terraria)
    chown -R terraria:terraria "${LOG_DIR}" "${WORLD_DIR}" "${CONFIG_DIR}"
    
    # Ensure scripts are executable
    chmod +x /terraria/scripts/*.sh
    
    log "Directories initialized."
}

#---------------------------------------------------------------
# Set up log rotation cron job
#---------------------------------------------------------------
setup_logrotate() {
    log "Setting up log rotation..."
    
    # Copy logrotate config if it exists
    if [ -f /terraria/config/logrotate.conf ]; then
        cp /terraria/config/logrotate.conf /etc/logrotate.d/terraria
        log "Log rotation configured."
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
    echo "║                                                           ║"
    echo "║  Process Manager: Supervisor                              ║"
    echo "║  Auto-restart:    Enabled                                 ║"
    echo "║  Log Rotation:    Enabled                                 ║"
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
    log "WORLD_NAME:     ${WORLD_NAME:-world}"
    log "MAX_PLAYERS:    ${MAX_PLAYERS:-8}"
    log "SERVER_PORT:    ${SERVER_PORT:-7777}"
    log "DIFFICULTY:     ${DIFFICULTY:-0}"
    log "AUTOCREATE:     ${AUTOCREATE:-2}"
    log "SECURE:         ${SECURE:-1}"
    log "RESTART_DELAY:  ${RESTART_DELAY:-5}s"
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
    
    # Set up log rotation
    setup_logrotate
    
    # Display configuration
    display_config
    
    # Start supervisor (runs in foreground)
    log "Starting Supervisor process manager..."
    exec /usr/bin/supervisord -c /terraria/config/supervisord.conf
}

# Execute main function
main "$@"
