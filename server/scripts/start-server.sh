#!/bin/bash
#---------------------------------------------------------------
# Terraria Server Start Script
# Handles environment variable substitution and server startup
#---------------------------------------------------------------

set -e

# Configuration paths
CONFIG_TEMPLATE="/terraria/config/serverconfig.txt"
CONFIG_FILE="/terraria/config/serverconfig-runtime.txt"
SERVER_BIN="/terraria/server/TerrariaServer.bin.x86_64"
LOG_DIR="/terraria/logs"
WORLD_DIR="/terraria/worlds"

#---------------------------------------------------------------
# Logging helper
#---------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

#---------------------------------------------------------------
# Environment defaults
#---------------------------------------------------------------
WORLD_NAME="${WORLD_NAME:-world}"
WORLD_SIZE="${WORLD_SIZE:-2}"
MAX_PLAYERS="${MAX_PLAYERS:-8}"
SERVER_PORT="${SERVER_PORT:-7777}"
SERVER_PASSWORD="${SERVER_PASSWORD:-}"
MOTD="${MOTD:-Welcome to the Terraria Server!}"
DIFFICULTY="${DIFFICULTY:-0}"
AUTOCREATE="${AUTOCREATE:-2}"
SECURE="${SECURE:-1}"
LANGUAGE="${LANGUAGE:-en-US}"

#---------------------------------------------------------------
# Setup directories
#---------------------------------------------------------------
log "Setting up directories..."
mkdir -p "${LOG_DIR}" "${WORLD_DIR}"

#---------------------------------------------------------------
# Generate runtime configuration
#---------------------------------------------------------------
log "Generating server configuration..."

cat > "${CONFIG_FILE}" << EOF
# Terraria Server Configuration (Auto-generated)
# Generated at: $(date)

# World Settings
world=${WORLD_DIR}/${WORLD_NAME}.wld
autocreate=${AUTOCREATE}
worldname=${WORLD_NAME}
difficulty=${DIFFICULTY}

# Server Settings
maxplayers=${MAX_PLAYERS}
port=${SERVER_PORT}
password=${SERVER_PASSWORD}
motd=${MOTD}
worldpath=${WORLD_DIR}/

# Security Settings
secure=${SECURE}
language=${LANGUAGE}

# Advanced Settings
priority=1
npcstream=60
EOF

log "Configuration generated: ${CONFIG_FILE}"

#---------------------------------------------------------------
# Display startup information
#---------------------------------------------------------------
log "========================================"
log "Terraria Server Starting"
log "========================================"
log "World Name:    ${WORLD_NAME}"
log "Max Players:   ${MAX_PLAYERS}"
log "Port:          ${SERVER_PORT}"
log "Difficulty:    ${DIFFICULTY}"
log "Auto-create:   ${AUTOCREATE}"
log "Password:      $([ -n "${SERVER_PASSWORD}" ] && echo "Set" || echo "Not set")"
log "========================================"

#---------------------------------------------------------------
# Handle graceful shutdown
#---------------------------------------------------------------
shutdown_server() {
    log "Received shutdown signal..."
    log "Saving world and shutting down..."
    # Send "exit" command to server if it's running in tmux
    if tmux has-session -t terraria 2>/dev/null; then
        tmux send-keys -t terraria "exit" Enter
        sleep 5
    fi
    log "Server shutdown complete."
    exit 0
}

trap shutdown_server SIGTERM SIGINT SIGQUIT

#---------------------------------------------------------------
# Start the server
#---------------------------------------------------------------
log "Starting Terraria server..."

# Check if server binary exists
if [ ! -f "${SERVER_BIN}" ]; then
    log "ERROR: Server binary not found at ${SERVER_BIN}"
    log "Available files in /terraria/server/:"
    ls -la /terraria/server/
    exit 1
fi

# Start server with configuration file
exec "${SERVER_BIN}" -config "${CONFIG_FILE}" 2>&1 | tee -a "${LOG_DIR}/server.log"
