#!/bin/bash
#===============================================================================
# Interact Commands - docker-logs, game-logs, console, shell, exec
# Sourced by server.sh - do not run directly
#===============================================================================

#-------------------------------------------------------------------------------
# Command: docker-logs (formerly logs)
#-------------------------------------------------------------------------------
cmd_docker_logs() {
    local lines="${1:-100}"
    
    print_header "Container Logs (last ${lines} lines)"
    
    if ! container_exists; then
        print_error "Container does not exist"
        return 1
    fi
    
    sudo docker logs --tail "${lines}" "${CONTAINER_NAME}"
}

#-------------------------------------------------------------------------------
# Command: game-logs
#-------------------------------------------------------------------------------
cmd_game_logs() {
    local lines="${1:-100}"
    local log_file="${DATA_DIR}/logs/terraria-stdout.log"
    
    print_header "Game Logs (last ${lines} lines)"
    
    if [ ! -f "${log_file}" ]; then
        print_error "Log file not found: ${log_file}"
        print_info "The server may not have started yet or logs are not being written."
        return 1
    fi
    
    tail -n "${lines}" "${log_file}"
}



#-------------------------------------------------------------------------------
# Command: console
#-------------------------------------------------------------------------------
cmd_console() {
    print_header "Terraria Server Console"
    print_info "Attaching to server console. Press Ctrl+P, Ctrl+Q to detach."
    echo ""
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    sudo docker attach "${CONTAINER_NAME}"
}

#-------------------------------------------------------------------------------
# Command: exec
#-------------------------------------------------------------------------------
cmd_exec() {
    if [ $# -eq 0 ]; then
        print_error "Command required"
        echo "Usage: $0 exec <command>"
        return 1
    fi
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    docker_exec "$@"
}

#-------------------------------------------------------------------------------
# Command: shell
#-------------------------------------------------------------------------------
cmd_shell() {
    print_header "Container Shell"
    print_info "Starting bash shell in container. Type 'exit' to leave."
    echo ""
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    docker_exec_it /bin/bash
}
