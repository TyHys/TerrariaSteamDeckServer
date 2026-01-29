#!/bin/bash
#---------------------------------------------------------------
# Terraria Server Control Script
# Provides administrative commands for the Terraria server
# Run this script inside the container using docker exec
#---------------------------------------------------------------

SCRIPT_NAME=$(basename "$0")
SUPERVISOR_SOCK="/tmp/supervisor.sock"

#---------------------------------------------------------------
# Colors for output
#---------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#---------------------------------------------------------------
# Helper functions
#---------------------------------------------------------------
print_status() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

#---------------------------------------------------------------
# Check if Supervisor is running
#---------------------------------------------------------------
check_supervisor() {
    if [ ! -S "${SUPERVISOR_SOCK}" ]; then
        print_error "Supervisor is not running or socket not found."
        print_info "This script must be run inside the container."
        exit 1
    fi
}

#---------------------------------------------------------------
# Commands
#---------------------------------------------------------------

cmd_status() {
    check_supervisor
    echo "=== Terraria Server Status ==="
    supervisorctl status
    echo ""
    echo "=== Server Process ==="
    if pgrep -f "TerrariaServer" > /dev/null; then
        print_status "Terraria server is running"
        pgrep -af "TerrariaServer"
    else
        print_warning "Terraria server is NOT running"
    fi
}

cmd_start() {
    check_supervisor
    print_info "Starting Terraria server..."
    supervisorctl start terraria
}

cmd_stop() {
    check_supervisor
    print_info "Stopping Terraria server..."
    print_warning "Players will be disconnected. World will be saved."
    supervisorctl stop terraria
}

cmd_restart() {
    check_supervisor
    print_info "Restarting Terraria server..."
    print_warning "Players will be disconnected. World will be saved."
    supervisorctl restart terraria
}

cmd_logs() {
    local log_type="${1:-stdout}"
    local lines="${2:-50}"
    
    case "${log_type}" in
        stdout|server)
            print_info "Showing last ${lines} lines of server output..."
            tail -n "${lines}" /terraria/logs/terraria-stdout.log
            ;;
        stderr|error)
            print_info "Showing last ${lines} lines of error log..."
            tail -n "${lines}" /terraria/logs/terraria-stderr.log
            ;;
        crash)
            print_info "Showing crash log..."
            if [ -f /terraria/logs/crashes.log ]; then
                cat /terraria/logs/crashes.log
            else
                print_info "No crashes recorded."
            fi
            ;;
        supervisor)
            print_info "Showing last ${lines} lines of supervisor log..."
            tail -n "${lines}" /terraria/logs/supervisord.log
            ;;
        api|web)
            print_info "Showing last ${lines} lines of Web API log..."
            tail -n "${lines}" /terraria/logs/web-api-stdout.log
            ;;
        follow|tail)
            print_info "Following server output (Ctrl+C to stop)..."
            tail -f /terraria/logs/terraria-stdout.log
            ;;
        *)
            print_error "Unknown log type: ${log_type}"
            echo "Available types: stdout, stderr, crash, supervisor, follow"
            exit 1
            ;;
    esac
}

cmd_config() {
    print_info "Current server configuration:"
    echo ""
    echo "=== Game Settings ==="
    echo "World Name:       ${WORLD_NAME:-world}"
    echo "Max Players:      ${MAX_PLAYERS:-8}"
    echo "Port:             ${SERVER_PORT:-7777}"
    echo "Difficulty:       ${DIFFICULTY:-0}"
    echo "Auto-create:      ${AUTOCREATE:-2}"
    echo "Secure:           ${SECURE:-1}"
    echo "Password:         $([ -n "${SERVER_PASSWORD}" ] && echo "[SET]" || echo "[NOT SET]")"
    echo ""
    echo "=== Process Management ==="
    echo "Restart Delay:    ${RESTART_DELAY:-5}s"
    echo "Max Delay:        ${RESTART_DELAY_MAX:-60}s"
    echo ""
    echo "=== Backup Settings ==="
    echo "Enabled:          ${BACKUP_ENABLED:-true}"
    echo "Interval:         ${BACKUP_INTERVAL:-30} minutes"
    echo "Retention:        ${BACKUP_RETENTION:-48} backups"
    echo "On Startup:       ${BACKUP_ON_STARTUP:-false}"
    echo "Compression:      ${BACKUP_COMPRESSION:-gzip}"
    echo ""
    echo "=== Web API Settings ==="
    echo "Host:             ${API_HOST:-0.0.0.0}"
    echo "Port:             ${API_PORT:-8080}"
    echo "Username:         ${API_USERNAME:-admin}"
    echo "Password:         $([ -n "${API_PASSWORD}" ] && echo "[SET]" || echo "[NOT SET]")"
    echo ""
    print_info "Runtime configuration file:"
    if [ -f /terraria/config/serverconfig-runtime.txt ]; then
        cat /terraria/config/serverconfig-runtime.txt
    else
        print_warning "Runtime config not yet generated."
    fi
}

cmd_worlds() {
    # Use the world manager script if available
    if [ -x /terraria/scripts/world-manager.sh ]; then
        /terraria/scripts/world-manager.sh list
    else
        print_info "Available worlds:"
        echo ""
        if ls /terraria/worlds/*.wld 1> /dev/null 2>&1; then
            for world in /terraria/worlds/*.wld; do
                local name=$(basename "$world" .wld)
                local size=$(du -h "$world" | cut -f1)
                local modified=$(stat -c %y "$world" 2>/dev/null | cut -d' ' -f1)
                echo "  - ${name} (${size}, modified: ${modified})"
            done
        else
            print_warning "No worlds found."
        fi
    fi
}

cmd_backups() {
    local action="${1:-list}"
    shift 2>/dev/null || true
    
    if [ ! -x /terraria/scripts/backup.sh ]; then
        print_error "Backup script not found."
        exit 1
    fi
    
    case "${action}" in
        list)
            /terraria/scripts/backup.sh list
            ;;
        create|now)
            print_info "Creating backup..."
            /terraria/scripts/backup.sh create "$@"
            ;;
        info)
            /terraria/scripts/backup.sh info "$@"
            ;;
        cleanup)
            /terraria/scripts/backup.sh cleanup
            ;;
        *)
            print_error "Unknown backup action: ${action}"
            echo "Usage: ${SCRIPT_NAME} backups [list|create|info <file>|cleanup]"
            exit 1
            ;;
    esac
}

cmd_restore() {
    if [ ! -x /terraria/scripts/restore.sh ]; then
        print_error "Restore script not found."
        exit 1
    fi
    
    /terraria/scripts/restore.sh "$@"
}

cmd_world() {
    local action="${1:-help}"
    shift 2>/dev/null || true
    
    if [ ! -x /terraria/scripts/world-manager.sh ]; then
        print_error "World manager script not found."
        exit 1
    fi
    
    /terraria/scripts/world-manager.sh "${action}" "$@"
}

cmd_health() {
    echo "=== Health Check ==="
    
    # Check Supervisor
    if [ -S "${SUPERVISOR_SOCK}" ]; then
        print_status "Supervisor: Running"
    else
        print_error "Supervisor: Not running"
    fi
    
    # Check Terraria process
    if pgrep -f "TerrariaServer" > /dev/null; then
        print_status "Terraria server: Running"
    else
        print_error "Terraria server: Not running"
    fi
    
    # Check backup scheduler
    if pgrep -f "backup-scheduler" > /dev/null; then
        print_status "Backup scheduler: Running"
    else
        if [ "${BACKUP_ENABLED:-true}" = "true" ]; then
            print_warning "Backup scheduler: Not running"
        else
            print_info "Backup scheduler: Disabled"
        fi
    fi
    
    # Check Web API
    if pgrep -f "gunicorn" > /dev/null; then
        print_status "Web API: Running on port ${API_PORT:-8080}"
    else
        print_warning "Web API: Not running"
    fi
    
    # Check disk space
    local free_mb=$(df -m /terraria/worlds | awk 'NR==2 {print $4}')
    if [ "${free_mb}" -gt 500 ]; then
        print_status "Disk space: ${free_mb}MB free"
    elif [ "${free_mb}" -gt 100 ]; then
        print_warning "Disk space: ${free_mb}MB free (getting low)"
    else
        print_error "Disk space: ${free_mb}MB free (CRITICAL)"
    fi
    
    # Check log sizes
    local log_size=$(du -sm /terraria/logs 2>/dev/null | cut -f1)
    print_info "Log directory size: ${log_size:-0}MB"
    
    # Check backup sizes
    local backup_count=$(ls /terraria/backups/backup_*.tar* 2>/dev/null | wc -l)
    local backup_size=$(du -sm /terraria/backups 2>/dev/null | cut -f1)
    print_info "Backups: ${backup_count} files, ${backup_size:-0}MB total"
    
    # Show uptime
    if [ -f /terraria/logs/terraria-stdout.log ]; then
        local first_line=$(head -1 /terraria/logs/terraria-stdout.log 2>/dev/null)
        print_info "Log started: ${first_line:0:19}"
    fi
}

cmd_help() {
    echo "Terraria Server Control Script"
    echo ""
    echo "Usage: ${SCRIPT_NAME} <command> [options]"
    echo ""
    echo "Server Commands:"
    echo "  status              Show server status"
    echo "  start               Start the server"
    echo "  stop                Stop the server"
    echo "  restart             Restart the server"
    echo "  logs [type] [n]     Show logs (stdout|stderr|crash|supervisor|api|follow)"
    echo "  config              Show current configuration"
    echo "  health              Run health checks"
    echo ""
    echo "World Commands:"
    echo "  worlds              List available worlds"
    echo "  world list          List available worlds"
    echo "  world info <name>   Show world details"
    echo "  world create        Create a new world (interactive)"
    echo "  world delete <name> Delete a world"
    echo "  world copy <s> <d>  Copy a world"
    echo ""
    echo "Backup Commands:"
    echo "  backups             List all backups"
    echo "  backups create      Create a backup now"
    echo "  backups info <file> Show backup details"
    echo "  backups cleanup     Remove old backups"
    echo "  restore <file>      Restore a backup"
    echo "  restore-latest <w>  Restore latest backup for world"
    echo ""
    echo "Web API:"
    echo "  API is accessible at http://localhost:${API_PORT:-8080}"
    echo "  Use /api/auth/login to get an authentication token"
    echo ""
    echo "Examples:"
    echo "  ${SCRIPT_NAME} status"
    echo "  ${SCRIPT_NAME} logs follow"
    echo "  ${SCRIPT_NAME} backups create"
    echo "  ${SCRIPT_NAME} world create"
    echo ""
    echo "Run this script inside the container:"
    echo "  docker exec -it terraria-server /terraria/scripts/server-control.sh status"
}

#---------------------------------------------------------------
# Main
#---------------------------------------------------------------
case "${1}" in
    status)
        cmd_status
        ;;
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    logs)
        cmd_logs "${2}" "${3}"
        ;;
    config)
        cmd_config
        ;;
    worlds)
        cmd_worlds
        ;;
    world)
        shift
        cmd_world "$@"
        ;;
    backups|backup)
        shift
        cmd_backups "$@"
        ;;
    restore)
        shift
        cmd_restore "$@"
        ;;
    restore-latest)
        shift
        cmd_restore restore-latest "$@"
        ;;
    health)
        cmd_health
        ;;
    help|--help|-h|"")
        cmd_help
        ;;
    *)
        print_error "Unknown command: ${1}"
        echo ""
        cmd_help
        exit 1
        ;;
esac
