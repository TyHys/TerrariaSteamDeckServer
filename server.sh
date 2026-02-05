#!/bin/bash
#===============================================================================
# Terraria Server Management Script
# External script for managing the Docker container
#
# Usage: ./server.sh <command> [options]
#
# This script is modular - commands are defined in the commands/ directory.
# Shared functions are in the lib/ directory.
#===============================================================================

set -e

#-------------------------------------------------------------------------------
# Source shared libraries
#-------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common library (colors, logging, paths)
source "${SCRIPT_DIR}/lib/common.sh"

# Source docker library (container operations)
source "${SCRIPT_DIR}/lib/docker.sh"

#-------------------------------------------------------------------------------
# Source command modules
#-------------------------------------------------------------------------------
for cmd_file in "${SCRIPT_DIR}/commands/"*.sh; do
    if [ -f "$cmd_file" ]; then
        source "$cmd_file"
    fi
done

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
    echo -e "  ${GREEN}docker-logs${NC} [lines]      Show container logs (default: 100 lines)"
    echo -e "  ${GREEN}game-logs${NC} [lines]        Show Terraria server stdout logs"
    echo ""
    echo -e "  ${GREEN}console${NC}                  Attach to Terraria server console"
    echo -e "  ${GREEN}shell${NC}                    Open a bash shell in the container"
    echo -e "  ${GREEN}exec${NC} <cmd>               Execute a shell command in container"
    echo ""
    echo -e "  ${GREEN}setup${NC}                    First-time setup (create .env, directories)"
    echo -e "  ${GREEN}build${NC} [--no-cache]       Build the Docker image"
    echo -e "  ${GREEN}update${NC} [version]         Update Terraria to a new version (e.g., 1453)"

    echo -e "  ${GREEN}clean${NC}                    Stop and remove container"
    echo -e "  ${GREEN}clean-all${NC}                Remove container, images, and volumes"
    echo ""
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
    echo "  $0 docker-logs 50                 # Show last 50 container log lines
  $0 game-logs                      # Show server stdout logs"
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
        # Server commands
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
        
        # Game commands
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
        
        # Backup commands
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
        
        # Interact commands
        docker-logs)
            cmd_docker_logs "$@"
            ;;
        game-logs)
            cmd_game_logs "$@"
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
        
        # Admin commands
        update)
            cmd_update "$@"
            ;;
        build)
            cmd_build "$@"
            ;;
        setup|init)
            cmd_setup "$@"
            ;;

        clean)
            cmd_clean "$@"
            ;;
        clean-all|cleanall|purge)
            cmd_clean_all "$@"
            ;;
        
        # Help
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
