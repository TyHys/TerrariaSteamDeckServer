#!/bin/bash
#===============================================================================
# Terraria Server Management Script
# External script for managing the Docker container
#
# Usage: ./server.sh <command> [options]
#
# This script is modular - add new commands by creating functions following
# the cmd_* naming convention.
#===============================================================================

set -e

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER_NAME="terraria-server"
COMPOSE_FILE="${SCRIPT_DIR}/docker/docker-compose.yml"
ENV_FILE="${SCRIPT_DIR}/docker/.env"
BACKUP_DIR="${SCRIPT_DIR}/data/backups"
DATA_DIR="${SCRIPT_DIR}/data"
COMMAND_FIFO="/tmp/terraria-command.fifo"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------

# Print colored message
print_msg() {
    local color="$1"
    local msg="$2"
    echo -e "${color}${msg}${NC}"
}

print_info()    { print_msg "${BLUE}" "$1"; }
print_success() { print_msg "${GREEN}" "✓ $1"; }
print_warning() { print_msg "${YELLOW}" "⚠ $1"; }
print_error()   { print_msg "${RED}" "✗ $1"; }
print_header()  { echo -e "\n${BOLD}${CYAN}$1${NC}\n"; }

# Check if container exists
container_exists() {
    sudo docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Check if container is running
container_running() {
    sudo docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

# Execute command in container
docker_exec() {
    sudo docker exec -i "${CONTAINER_NAME}" "$@"
}

# Execute interactive command in container
docker_exec_it() {
    sudo docker exec -it "${CONTAINER_NAME}" "$@"
}

# Get container uptime
get_container_uptime() {
    if container_running; then
        sudo docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Status}}' | sed 's/Up //'
    fi
}

# Docker compose command
docker_compose() {
    sudo docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

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

#-------------------------------------------------------------------------------
# Command: save
#-------------------------------------------------------------------------------
cmd_save() {
    print_header "Saving World"
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    print_info "Sending save command to server..."
    
    if send_server_command "save"; then
        print_success "Save command sent!"
        print_info "The world is being saved. Check logs for confirmation."
        
        # Also create a backup for extra safety
        echo ""
        read -r -p "Would you also like to create a backup? (y/n): " create_backup
        if [ "$create_backup" = "y" ] || [ "$create_backup" = "Y" ]; then
            echo ""
            cmd_backup
        fi
    else
        print_warning "Could not send save command via FIFO"
        print_info "Creating a backup instead (this is equally safe)..."
        echo ""
        cmd_backup
    fi
}

#-------------------------------------------------------------------------------
# Command: say
#-------------------------------------------------------------------------------
cmd_say() {
    local message="$*"
    
    if [ -z "$message" ]; then
        print_error "Message is required"
        echo ""
        echo "Usage: $0 say <message>"
        echo ""
        echo "Examples:"
        echo "  $0 say Hello everyone!"
        echo "  $0 say \"Server will restart in 5 minutes\""
        return 1
    fi
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    print_info "Sending message to players..."
    
    if send_server_command "say ${message}"; then
        print_success "Message sent: ${message}"
    else
        print_error "Failed to send message"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Command: command (send arbitrary server command)
#-------------------------------------------------------------------------------
cmd_command() {
    local command="$*"
    
    if [ -z "$command" ]; then
        print_error "Command is required"
        echo ""
        echo "Usage: $0 command <server-command>"
        echo ""
        echo "Available Terraria server commands:"
        echo "  help                    Show server command help"
        echo "  playing                 Show connected players"
        echo "  save                    Save the world"
        echo "  exit                    Save and shutdown server"
        echo "  kick <player>           Kick a player"
        echo "  ban <player>            Ban a player"
        echo "  password <pass>         Change server password"
        echo "  motd <message>          Change message of the day"
        echo "  say <message>           Broadcast a message"
        echo "  time                    Show current time"
        echo "  dawn/noon/dusk/midnight Set time of day"
        echo "  settle                  Settle liquids"
        echo ""
        return 1
    fi
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    print_info "Sending command: ${command}"
    
    if send_server_command "${command}"; then
        print_success "Command sent!"
        print_info "Check logs for output: $0 logs 20"
    else
        print_error "Failed to send command"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Command: players
#-------------------------------------------------------------------------------
cmd_players() {
    print_header "Online Players"
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    echo -e "${BOLD}Currently Online:${NC}"
    
    local log_file="/terraria/logs/terraria-stdout.log"
    
    # Use awk to parse player joins/leaves and determine who's online
    # Let awk handle all output formatting to avoid shell processing issues
    sudo docker exec "${CONTAINER_NAME}" tail -1000 "$log_file" 2>/dev/null | awk -v prefix="  - " '
    / has joined\.$/ {
        line = $0
        sub(/ has joined\.$/, "", line)
        players[line] = 1
    }
    / has left\.$/ {
        line = $0
        sub(/ has left\.$/, "", line)
        players[line] = 0
    }
    END {
        count = 0
        for (p in players) {
            if (players[p] == 1) {
                print prefix p
                count++
            }
        }
        if (count == 0) {
            print "  No players detected in recent logs"
            print ""
            print "\033[33mNote:\033[0m This is based on log parsing. For accurate count,"
            print "      check the server console or use: ./server.sh console"
        } else {
            print ""
            print "  Total: " count " player(s) detected"
        }
    }
    '
    
}

#-------------------------------------------------------------------------------
# Command: start
#-------------------------------------------------------------------------------
cmd_start() {
    print_header "Starting Terraria Server"
    
    if container_running; then
        print_warning "Container is already running"
        return 0
    fi
    
    print_info "Starting container..."
    docker_compose up -d
    
    # Wait for container to be healthy
    print_info "Waiting for server to initialize..."
    local wait_time=0
    local max_wait=60
    
    while [ $wait_time -lt $max_wait ]; do
        if container_running; then
            local health
            health=$(sudo docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "none")
            
            if [ "$health" = "healthy" ]; then
                print_success "Server started and healthy!"
                return 0
            elif [ "$health" = "unhealthy" ]; then
                print_warning "Server started but health check failed"
                return 0
            fi
        fi
        
        sleep 2
        ((wait_time += 2))
        echo -n "."
    done
    
    echo ""
    if container_running; then
        print_success "Server started (health check pending)"
    else
        print_error "Failed to start server"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Command: stop
#-------------------------------------------------------------------------------
cmd_stop() {
    print_header "Stopping Terraria Server"
    
    if ! container_running; then
        print_warning "Container is not running"
        return 0
    fi
    
    print_info "Stopping container (this may take up to 45 seconds to save the world)..."
    docker_compose down
    
    print_success "Server stopped"
}

#-------------------------------------------------------------------------------
# Command: restart
#-------------------------------------------------------------------------------
cmd_restart() {
    print_header "Restarting Terraria Server"
    
    cmd_stop
    sleep 2
    cmd_start
}

#-------------------------------------------------------------------------------
# Command: status
#-------------------------------------------------------------------------------
cmd_status() {
    print_header "Terraria Server Status"
    
    # Container status
    echo -e "${BOLD}Container:${NC}"
    if container_running; then
        local uptime
        uptime=$(get_container_uptime)
        print_success "Running (${uptime})"
    else
        print_error "Not running"
        return 0
    fi
    
    echo ""
    
    # Server process status
    echo -e "${BOLD}Server Process:${NC}"
    if docker_exec pgrep -f "TerrariaServer" > /dev/null 2>&1; then
        print_success "Terraria server is running"
    else
        print_warning "Terraria server process not found"
    fi
    
    # Supervisor status
    echo ""
    echo -e "${BOLD}Services:${NC}"
    docker_exec supervisorctl status 2>/dev/null | while read -r line; do
        echo "  $line"
    done
    
    # Player information (parse from recent logs using awk for Unicode support)
    echo ""
    echo -e "${BOLD}Players:${NC}"
    local log_file="/terraria/logs/terraria-stdout.log"
    
    # Let awk handle all output to avoid shell processing issues
    sudo docker exec "${CONTAINER_NAME}" tail -1000 "$log_file" 2>/dev/null | awk '
    / has joined\.$/ { line = $0; sub(/ has joined\.$/, "", line); players[line] = 1 }
    / has left\.$/ { line = $0; sub(/ has left\.$/, "", line); players[line] = 0 }
    END {
        count = 0
        list = ""
        for (p in players) {
            if (players[p] == 1) {
                if (list != "") list = list ", "
                list = list p
                count++
            }
        }
        if (count > 0) {
            print "  Online (" count "): " list
        } else {
            print "  No players detected (use ./server.sh players for details)"
        }
    }
    '
    
    # World information
    echo ""
    echo -e "${BOLD}Worlds:${NC}"
    local world_count=0
    if ls "${DATA_DIR}"/worlds/*.wld 1>/dev/null 2>&1; then
        for world in "${DATA_DIR}"/worlds/*.wld; do
            if [ -f "$world" ]; then
                local name
                name=$(basename "$world" .wld)
                local size
                size=$(du -h "$world" 2>/dev/null | cut -f1)
                echo "  - ${name} (${size})"
                ((world_count++))
            fi
        done
    fi
    if [ ${world_count} -eq 0 ]; then
        echo "  No worlds found"
    fi
    
    # Backup information
    echo ""
    echo -e "${BOLD}Backups:${NC}"
    local backup_count
    backup_count=$(ls "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null | wc -l)
    local backup_size
    backup_size=$(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)
    echo "  Count: ${backup_count} backup(s)"
    echo "  Size:  ${backup_size:-0}"
    
    # Network information
    echo ""
    echo -e "${BOLD}Network:${NC}"
    local local_ip
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    echo "  Local:  localhost:7777"
    if [ -n "$local_ip" ]; then
        echo "  LAN:    ${local_ip}:7777"
    fi
    
    echo ""
}

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
# Command: logs
#-------------------------------------------------------------------------------
cmd_logs() {
    local lines="${1:-100}"
    
    print_header "Container Logs (last ${lines} lines)"
    
    if ! container_exists; then
        print_error "Container does not exist"
        return 1
    fi
    
    sudo docker logs --tail "${lines}" "${CONTAINER_NAME}"
}

#-------------------------------------------------------------------------------
# Command: livelogs
#-------------------------------------------------------------------------------
cmd_livelogs() {
    print_header "Live Container Logs (Ctrl+C to exit)"
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    sudo docker logs -f "${CONTAINER_NAME}"
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
# Command: update
#-------------------------------------------------------------------------------
cmd_update() {
    print_header "Updating Container Image"
    
    local was_running=false
    if container_running; then
        was_running=true
        print_info "Stopping current container..."
        cmd_stop
    fi
    
    print_info "Rebuilding image..."
    docker_compose build --no-cache
    
    if [ "$was_running" = true ]; then
        print_info "Restarting container..."
        cmd_start
    fi
    
    print_success "Update complete!"
}

#-------------------------------------------------------------------------------
# Command: help
#-------------------------------------------------------------------------------
cmd_help() {
    echo ""
    echo -e "${BOLD}${CYAN}Terraria Server Management${NC}"
    echo ""
    echo -e "${BOLD}Usage:${NC} $0 <command> [options]"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo ""
    echo -e "  ${GREEN}start${NC}                    Start the server container"
    echo -e "  ${GREEN}stop${NC}                     Stop the server container"
    echo -e "  ${GREEN}restart${NC}                  Restart the server container"
    echo -e "  ${GREEN}status${NC}                   Show server status and info"
    echo -e "  ${GREEN}players${NC}                  Show online players"
    echo ""
    echo -e "  ${GREEN}save${NC}                     Save the world (crash protection)"
    echo -e "  ${GREEN}say${NC} <message>            Broadcast a message to all players"
    echo -e "  ${GREEN}command${NC} <cmd>            Send any server command"
    echo ""
    echo -e "  ${GREEN}backup${NC} [world]           Create a backup (all worlds or specific)"
    echo -e "  ${GREEN}restore${NC} <backup-file>    Restore from a backup file"
    echo -e "  ${GREEN}backups${NC}                  List all available backups"
    echo ""
    echo -e "  ${GREEN}logs${NC} [lines]             Show container logs (default: 100 lines)"
    echo -e "  ${GREEN}livelogs${NC}                 Follow container logs in real-time"
    echo ""
    echo -e "  ${GREEN}console${NC}                  Attach to Terraria server console"
    echo -e "  ${GREEN}shell${NC}                    Open a bash shell in the container"
    echo -e "  ${GREEN}exec${NC} <cmd>               Execute a shell command in container"
    echo ""
    echo -e "  ${GREEN}update${NC}                   Rebuild the container image"
    echo -e "  ${GREEN}help${NC}                     Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo ""
    echo "  $0 start                          # Start the server"
    echo "  $0 status                         # Check server status"
    echo "  $0 players                        # Show online players"
    echo "  $0 save                           # Save the world immediately"
    echo "  $0 say Server restarting in 5 min # Broadcast to players"
    echo "  $0 backup                         # Backup all worlds"
    echo "  $0 backup florida                 # Backup specific world"
    echo "  $0 restore backup_florida_20260128_120000.tar.gz"
    echo "  $0 logs 50                        # Show last 50 log lines"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Entry Point
#-------------------------------------------------------------------------------
main() {
    local command="${1:-help}"
    shift 2>/dev/null || true
    
    # Map command to function
    case "${command}" in
        start)
            cmd_start "$@"
            ;;
        stop)
            cmd_stop "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        players|who)
            cmd_players "$@"
            ;;
        save)
            cmd_save "$@"
            ;;
        say)
            cmd_say "$@"
            ;;
        command|cmd)
            cmd_command "$@"
            ;;
        backup)
            cmd_backup "$@"
            ;;
        restore)
            cmd_restore "$@"
            ;;
        backups|list-backups)
            cmd_backups "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        livelogs|live|follow)
            cmd_livelogs "$@"
            ;;
        console|attach)
            cmd_console "$@"
            ;;
        shell|bash)
            cmd_shell "$@"
            ;;
        exec)
            cmd_exec "$@"
            ;;
        update|rebuild)
            cmd_update "$@"
            ;;
        help|-h|--help)
            cmd_help
            ;;
        *)
            print_error "Unknown command: ${command}"
            echo "Run '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
