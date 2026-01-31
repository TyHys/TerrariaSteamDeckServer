#!/bin/bash
#===============================================================================
# Docker Library - Container and Docker Compose operations
# Source this file from other scripts for Docker-related functions
# Requires: lib/common.sh to be sourced first
#===============================================================================

# Prevent double-sourcing
[[ -n "${_LIB_DOCKER_LOADED:-}" ]] && return
_LIB_DOCKER_LOADED=1

#-------------------------------------------------------------------------------
# Container Status Functions
#-------------------------------------------------------------------------------

# Check if container exists
container_exists() {
    sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Check if container is running
container_running() {
    sudo docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Get container uptime
get_container_uptime() {
    if container_running; then
        sudo docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Status}}' | sed 's/Up //'
    fi
}

#-------------------------------------------------------------------------------
# Docker Execution Functions
#-------------------------------------------------------------------------------

# Execute command in container
docker_exec() {
    sudo docker exec -i "${CONTAINER_NAME}" "$@"
}

# Execute interactive command in container
docker_exec_it() {
    sudo docker exec -it "${CONTAINER_NAME}" "$@"
}

#-------------------------------------------------------------------------------
# Docker Compose Functions
#-------------------------------------------------------------------------------

# Docker compose command with proper env file
docker_compose() {
    sudo docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

#-------------------------------------------------------------------------------
# Server Command Functions
#-------------------------------------------------------------------------------

# Send command to Terraria server via FIFO
send_server_command() {
    local cmd="$1"
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    # Check if FIFO exists in container (run as root to ensure access)
    if ! sudo docker exec -u 0 "${CONTAINER_NAME}" test -p "${COMMAND_FIFO}" 2>/dev/null; then
        print_error "Command FIFO not available. Server may need to be restarted."
        print_info "The FIFO is created when the server starts."
        return 1
    fi
    
    # Send command to FIFO (run as root to ensure write access)
    sudo docker exec -u 0 "${CONTAINER_NAME}" bash -c "echo '${cmd}' > ${COMMAND_FIFO}"
    return $?
}
