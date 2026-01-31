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
ENV_FILE="${SCRIPT_DIR}/.env"
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
# Command: backup-schedule (configure automatic backups)
#-------------------------------------------------------------------------------
cmd_backup_schedule() {
    print_header "Backup Schedule Configuration"
    
    # Check if .env file exists
    if [ ! -f "${ENV_FILE}" ]; then
        print_error "Configuration file not found: ${ENV_FILE}"
        print_info "Run 'make setup' first to create the configuration file."
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

#-------------------------------------------------------------------------------
# Command: update
# Updates the Terraria server to a new version
# Usage: ./server.sh update [version]
#   version: Optional 4-digit version number (e.g., 1453 for Terraria 1.4.5.3)
#            If not provided, just rebuilds with the current version
#-------------------------------------------------------------------------------
cmd_update() {
    local new_version="$1"
    local dockerfile="${SCRIPT_DIR}/docker/Dockerfile"
    
    print_header "Terraria Server Update"
    
    # Check if Dockerfile exists
    if [ ! -f "$dockerfile" ]; then
        print_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    # Get current version from Dockerfile
    local current_version
    current_version=$(grep "^ARG TERRARIA_VERSION=" "$dockerfile" | cut -d'=' -f2)
    
    if [ -z "$current_version" ]; then
        print_error "Could not determine current Terraria version from Dockerfile"
        return 1
    fi
    
    echo -e "${BOLD}Current Version:${NC} ${current_version}"
    
    # If no version specified, just rebuild with current version
    if [ -z "$new_version" ]; then
        echo ""
        print_info "No version specified. Rebuilding with current version (${current_version})..."
        echo ""
        _do_update_rebuild
        return $?
    fi
    
    # Validate version format (should be 4 digits)
    if ! [[ "$new_version" =~ ^[0-9]{4}$ ]]; then
        print_error "Invalid version format: ${new_version}"
        echo ""
        echo "Version should be a 4-digit number, for example:"
        echo "  1449 (for Terraria 1.4.4.9)"
        echo "  1450 (for Terraria 1.4.5.0)"
        echo "  1451 (for Terraria 1.4.5.1)"
        echo "  1453 (for Terraria 1.4.5.3)"
        echo ""
        echo "Pattern: Remove dots and trailing zeros from game version"
        echo "  Example: 1.4.5.3 → 1453"
        return 1
    fi
    
    # Check if same version
    if [ "$new_version" = "$current_version" ]; then
        print_warning "Already on version ${new_version}"
        echo ""
        read -r -p "Rebuild anyway? (y/n): " rebuild_anyway
        if [ "$rebuild_anyway" != "y" ] && [ "$rebuild_anyway" != "Y" ]; then
            print_info "Update cancelled."
            return 0
        fi
        _do_update_rebuild
        return $?
    fi
    
    echo -e "${BOLD}New Version:${NC}     ${new_version}"
    echo ""
    
    # Verify the version exists on terraria.org
    print_info "Verifying version ${new_version} exists on terraria.org..."
    local download_url="https://terraria.org/api/download/pc-dedicated-server/terraria-server-${new_version}.zip"
    
    if curl --output /dev/null --silent --head --fail "$download_url"; then
        print_success "Version ${new_version} is available for download"
    else
        print_error "Version ${new_version} not found on terraria.org"
        echo ""
        echo "The download URL was:"
        echo "  ${download_url}"
        echo ""
        echo "Check the official wiki for valid versions:"
        echo "  https://terraria.wiki.gg/wiki/Server#Downloads"
        echo ""
        read -r -p "Continue anyway? (y/n): " continue_anyway
        if [ "$continue_anyway" != "y" ] && [ "$continue_anyway" != "Y" ]; then
            print_info "Update cancelled."
            return 0
        fi
    fi
    
    echo ""
    
    # Determine if this is a major version change
    local current_major="${current_version:0:3}"
    local new_major="${new_version:0:3}"
    local is_major_update=false
    
    if [ "$current_major" != "$new_major" ]; then
        is_major_update=true
        print_warning "This is a MAJOR version update (${current_major}x → ${new_major}x)"
        echo ""
    fi
    
    # Show update summary
    echo -e "${BOLD}Update Summary:${NC}"
    echo "  From:  ${current_version}"
    echo "  To:    ${new_version}"
    echo ""
    echo -e "${CYAN}Note: Players must be on the same version as the server to connect.${NC}"
    echo ""
    
    # Offer to create backup before updating
    if container_running; then
        if [ "$is_major_update" = true ]; then
            print_warning "Recommended: Create a backup before major updates"
        fi
        read -r -p "Create a backup before updating? (y/n): " create_backup
        if [ "$create_backup" = "y" ] || [ "$create_backup" = "Y" ]; then
            echo ""
            cmd_backup
            echo ""
        fi
    fi
    
    # Confirm the update
    read -r -p "Proceed with update to version ${new_version}? (y/n): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        print_info "Update cancelled."
        return 0
    fi
    
    echo ""
    
    # Update the Dockerfile
    print_info "Updating Dockerfile..."
    
    # Update ARG TERRARIA_VERSION
    if ! sed -i "s/^ARG TERRARIA_VERSION=.*/ARG TERRARIA_VERSION=${new_version}/" "$dockerfile"; then
        print_error "Failed to update ARG TERRARIA_VERSION in Dockerfile"
        return 1
    fi
    
    # Update ENV TERRARIA_VERSION
    if ! sed -i "s/^ENV TERRARIA_VERSION=.*/ENV TERRARIA_VERSION=${new_version}/" "$dockerfile"; then
        print_error "Failed to update ENV TERRARIA_VERSION in Dockerfile"
        return 1
    fi
    
    # Verify the changes
    local verify_arg
    local verify_env
    verify_arg=$(grep "^ARG TERRARIA_VERSION=" "$dockerfile" | cut -d'=' -f2)
    verify_env=$(grep "^ENV TERRARIA_VERSION=" "$dockerfile" | cut -d'=' -f2)
    
    if [ "$verify_arg" != "$new_version" ] || [ "$verify_env" != "$new_version" ]; then
        print_error "Dockerfile update verification failed"
        echo "  ARG TERRARIA_VERSION=${verify_arg} (expected ${new_version})"
        echo "  ENV TERRARIA_VERSION=${verify_env} (expected ${new_version})"
        return 1
    fi
    
    print_success "Dockerfile updated to version ${new_version}"
    echo ""
    
    # Rebuild the container
    _do_update_rebuild
    local result=$?
    
    if [ $result -eq 0 ]; then
        echo ""
        print_success "Server updated to Terraria version ${new_version}!"
        echo ""
        echo -e "${CYAN}Reminder: Players must update their game to version ${new_version} to connect.${NC}"
    fi
    
    return $result
}

# Helper function to handle the rebuild process
_do_update_rebuild() {
    local was_running=false
    
    if container_running; then
        was_running=true
        print_info "Stopping current container..."
        cmd_stop
        sleep 2
    fi
    
    print_info "Rebuilding container image (this may take a few minutes)..."
    if ! docker_compose build --no-cache; then
        print_error "Failed to build container image"
        return 1
    fi
    
    print_success "Container image rebuilt successfully!"
    
    if [ "$was_running" = true ]; then
        echo ""
        print_info "Restarting container..."
        cmd_start
        
        # Verify the server is running with new version
        echo ""
        print_info "Verifying update..."
        sleep 5
        
        if container_running; then
            # Check version in container environment
            local running_version
            running_version=$(sudo docker exec "${CONTAINER_NAME}" printenv TERRARIA_VERSION 2>/dev/null)
            if [ -n "$running_version" ]; then
                echo "  Running version: ${running_version}"
            fi
            print_success "Server is running!"
        else
            print_warning "Server may not have started correctly. Check logs with: $0 logs"
        fi
    else
        print_info "Container was not running. Start with: $0 start"
    fi
    
    return 0
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
    echo -e "  ${GREEN}backup-schedule${NC}          Configure automatic backup schedule"
    echo ""
    echo -e "  ${GREEN}logs${NC} [lines]             Show container logs (default: 100 lines)"
    echo -e "  ${GREEN}livelogs${NC}                 Follow container logs in real-time"
    echo ""
    echo -e "  ${GREEN}console${NC}                  Attach to Terraria server console"
    echo -e "  ${GREEN}shell${NC}                    Open a bash shell in the container"
    echo -e "  ${GREEN}exec${NC} <cmd>               Execute a shell command in container"
    echo ""
    echo -e "  ${GREEN}update${NC} [version]         Update Terraria to a new version (e.g., 1453)"
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
    echo "  $0 backup-schedule                # Configure automatic backups"
    echo "  $0 logs 50                        # Show last 50 log lines"
    echo "  $0 update                         # Rebuild with current version"
    echo "  $0 update 1453                    # Update to Terraria 1.4.5.3"
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
        backup-schedule|schedule|schedule-backup)
            cmd_backup_schedule "$@"
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
