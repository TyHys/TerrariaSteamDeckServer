#!/bin/bash
#---------------------------------------------------------------
# Terraria Server Wrapper Script
# Managed by Supervisor for process monitoring and crash recovery
#---------------------------------------------------------------

# Configuration paths
CONFIG_FILE="/terraria/config/serverconfig-runtime.txt"
SERVER_BIN="/terraria/server/TerrariaServer.bin.x86_64"
LOG_DIR="/terraria/logs"
WORLD_DIR="/terraria/worlds"
PID_FILE="/tmp/terraria-server.pid"
COMMAND_FIFO="/tmp/terraria-command.fifo"

# Restart backoff settings (from environment or defaults)
RESTART_DELAY="${RESTART_DELAY:-5}"
RESTART_DELAY_MAX="${RESTART_DELAY_MAX:-60}"
RESTART_DELAY_MULTIPLIER="${RESTART_DELAY_MULTIPLIER:-2}"

# Current backoff delay (reset on successful startup)
current_delay=${RESTART_DELAY}

#---------------------------------------------------------------
# Logging helper
#---------------------------------------------------------------
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WRAPPER] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WRAPPER] [ERROR] $1" >&2
}

#---------------------------------------------------------------
# Generate runtime configuration from environment
#---------------------------------------------------------------
generate_config() {
    log "Generating server configuration..."
    
    # Environment defaults
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
    
    log "Configuration written to ${CONFIG_FILE}"
}

#---------------------------------------------------------------
# Display startup information
#---------------------------------------------------------------
display_startup_info() {
    log "========================================"
    log "Terraria Server Starting"
    log "========================================"
    log "World Name:    ${WORLD_NAME:-world}"
    log "Max Players:   ${MAX_PLAYERS:-8}"
    log "Port:          ${SERVER_PORT:-7777}"
    log "Difficulty:    ${DIFFICULTY:-0}"
    log "Auto-create:   ${AUTOCREATE:-2}"
    log "Password:      $([ -n "${SERVER_PASSWORD}" ] && echo "Set" || echo "Not set")"
    log "Restart Delay: ${RESTART_DELAY}s (max: ${RESTART_DELAY_MAX}s)"
    log "========================================"
}

#---------------------------------------------------------------
# Graceful shutdown handler
#---------------------------------------------------------------
server_pid=""

shutdown_handler() {
    local signal=$1
    log "Received ${signal} signal, initiating graceful shutdown..."
    
    if [ -n "${server_pid}" ] && kill -0 "${server_pid}" 2>/dev/null; then
        log "Sending save-and-exit command to server..."
        
        # Try to send exit command via FIFO first (triggers proper save)
        if [ -p "${COMMAND_FIFO}" ]; then
            log "Sending 'exit' command via FIFO..."
            echo "exit" > "${COMMAND_FIFO}" 2>/dev/null || true
            sleep 2
        fi
        
        # If still running, send SIGTERM
        if kill -0 "${server_pid}" 2>/dev/null; then
            log "Sending SIGTERM to server (PID: ${server_pid})..."
            kill -TERM "${server_pid}" 2>/dev/null
        fi
        
        # Wait for server to exit gracefully
        local wait_time=0
        local max_wait=25
        while kill -0 "${server_pid}" 2>/dev/null && [ ${wait_time} -lt ${max_wait} ]; do
            log "Waiting for server to save and exit... (${wait_time}/${max_wait}s)"
            sleep 1
            ((wait_time++))
        done
        
        if kill -0 "${server_pid}" 2>/dev/null; then
            log "Server did not exit gracefully, sending SIGKILL..."
            kill -KILL "${server_pid}" 2>/dev/null
            sleep 1
        fi
        
        log "Server process terminated."
    fi
    
    rm -f "${PID_FILE}" "${COMMAND_FIFO}"
    log "Shutdown complete."
    exit 0
}

# Set up signal handlers
trap 'shutdown_handler SIGTERM' SIGTERM
trap 'shutdown_handler SIGINT' SIGINT
trap 'shutdown_handler SIGQUIT' SIGQUIT

#---------------------------------------------------------------
# Pre-flight checks
#---------------------------------------------------------------
preflight_checks() {
    log "Running pre-flight checks..."
    
    # Check server binary
    if [ ! -f "${SERVER_BIN}" ]; then
        log_error "Server binary not found at ${SERVER_BIN}"
        log "Available files in /terraria/server/:"
        ls -la /terraria/server/ >&2
        return 1
    fi
    
    # Check binary is executable
    if [ ! -x "${SERVER_BIN}" ]; then
        log_error "Server binary is not executable"
        return 1
    fi
    
    # Create necessary directories
    mkdir -p "${LOG_DIR}" "${WORLD_DIR}"
    
    # Check disk space (warn if less than 100MB free)
    local free_space
    free_space=$(df -m /terraria/worlds | awk 'NR==2 {print $4}')
    if [ "${free_space}" -lt 100 ]; then
        log "WARNING: Low disk space (${free_space}MB free)"
    fi
    
    log "Pre-flight checks passed."
    return 0
}

#---------------------------------------------------------------
# Set up command FIFO for external command injection
#---------------------------------------------------------------
setup_command_fifo() {
    log "Setting up command FIFO at ${COMMAND_FIFO}..."
    
    # Check if FIFO already exists and is valid (created by entrypoint)
    if [ -p "${COMMAND_FIFO}" ]; then
        log "Command FIFO already exists, verifying permissions..."
        chmod 0666 "${COMMAND_FIFO}" 2>/dev/null || true
    else
        # Create new FIFO if it doesn't exist (fallback)
        log "Creating new command FIFO..."
        rm -f "${COMMAND_FIFO}"
        mkfifo -m 0666 "${COMMAND_FIFO}"
        chown terraria:terraria "${COMMAND_FIFO}" 2>/dev/null || true
    fi
    
    log "Command FIFO ready. Send commands with: echo 'command' > ${COMMAND_FIFO}"
}

#---------------------------------------------------------------
# Command reader process - reads from FIFO and writes to server stdin
#---------------------------------------------------------------
command_reader() {
    local server_stdin_fd=$1
    
    log "Command reader started, listening on ${COMMAND_FIFO}..."
    
    # Keep reading from FIFO in a loop
    # Opening FIFO for reading blocks until a writer opens it
    # We use a loop with read-write to keep the FIFO open
    exec 3<>"${COMMAND_FIFO}"
    
    while true; do
        if read -r cmd <&3; then
            if [ -n "$cmd" ]; then
                log "Received command: ${cmd}"
                echo "$cmd" >&${server_stdin_fd}
            fi
        fi
        # Small sleep to prevent busy loop
        sleep 0.1
    done
}

#---------------------------------------------------------------
# Main server execution
#---------------------------------------------------------------
run_server() {
    # Generate config from environment
    generate_config
    
    # Display startup info
    display_startup_info
    
    # Set up command FIFO
    setup_command_fifo
    
    log "Launching Terraria server process..."
    
    # Create a pipe for server stdin
    # We'll use a named pipe approach with stdin redirection
    
    # Start the server with stdin from a file descriptor we control
    # Using process substitution and stdin redirection
    exec 4>&1  # Save stdout
    
    # Start the server reading from a pipe
    "${SERVER_BIN}" -config "${CONFIG_FILE}" < <(
        # This subshell feeds the server stdin
        # It reads from the command FIFO and passes to the server
        exec 3<>"${COMMAND_FIFO}"
        while true; do
            if read -r -t 1 cmd <&3; then
                if [ -n "$cmd" ]; then
                    log "Executing command: ${cmd}"
                    echo "$cmd"
                fi
            fi
            # Check if parent process is still alive
            if ! kill -0 $$ 2>/dev/null; then
                break
            fi
        done
    ) &
    
    server_pid=$!
    echo "${server_pid}" > "${PID_FILE}"
    
    log "Server started with PID: ${server_pid}"
    log "Send commands via: echo 'command' > ${COMMAND_FIFO}"
    
    # Wait for server process
    wait "${server_pid}"
    exit_code=$?
    
    log "Server exited with code: ${exit_code}"
    rm -f "${PID_FILE}" "${COMMAND_FIFO}"
    
    return ${exit_code}
}

#---------------------------------------------------------------
# Main entry point
#---------------------------------------------------------------
main() {
    log "Terraria wrapper script starting..."
    
    # Run pre-flight checks
    if ! preflight_checks; then
        log_error "Pre-flight checks failed, aborting startup"
        exit 1
    fi
    
    # Run the server
    run_server
    exit_code=$?
    
    # If we get here, the server exited
    # Supervisor will handle the restart based on exit code
    exit ${exit_code}
}

# Execute main function
main "$@"
