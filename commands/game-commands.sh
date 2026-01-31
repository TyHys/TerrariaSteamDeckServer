#!/bin/bash
#===============================================================================
# Game Commands - save, say, command, players
# Sourced by server.sh - do not run directly
#===============================================================================

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
    
    if ! container_running; then
        print_error "Container is not running"
        return 1
    fi
    
    local log_file="/terraria/logs/terraria-stdout.log"
    
    # Get max players from .env file (default to 8 if not set)
    local max_players
    max_players=$(grep "^MAX_PLAYERS=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "8")
    [ -z "$max_players" ] && max_players="8"
    
    # Use awk to parse player joins/leaves and determine who's online
    # Let awk handle all output formatting to avoid shell processing issues
    sudo docker exec "${CONTAINER_NAME}" tail -1000 "$log_file" 2>/dev/null | awk -v prefix="  - " -v max_players="$max_players" '
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
                count++
            }
        }
        if (count == 0) {
            print "  No players detected in recent logs"
            print ""
            print "\033[33mNote:\033[0m This is based on log parsing. For accurate count,"
            print "      check the server console or use: ./server.sh console"
        } else {
            print "  " count "/" max_players " Players"
            print ""
            for (p in players) {
                if (players[p] == 1) {
                    print prefix p
                }
            }
        }
    }
    '
    
}
