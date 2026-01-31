#!/bin/bash
#===============================================================================
# Server Commands - start, stop, restart, status
# Sourced by server.sh - do not run directly
#===============================================================================

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
                ((world_count++)) || true
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
    backup_count=$( (ls "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null || true) | wc -l)
    local backup_size
    backup_size=$(du -sh "${BACKUP_DIR}" 2>/dev/null | cut -f1)
    echo "  Count: ${backup_count} backup(s)"
    echo "  Size:  ${backup_size:-0}"
    
    # Backup schedule information
    local backup_enabled
    backup_enabled=$(grep "^BACKUP_ENABLED=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "true")
    [ -z "$backup_enabled" ] && backup_enabled="true"
    
    local backup_interval
    backup_interval=$(grep "^BACKUP_INTERVAL=" "${ENV_FILE}" 2>/dev/null | cut -d'=' -f2 || echo "30")
    [ -z "$backup_interval" ] && backup_interval="30"
    
    echo ""
    echo -e "${BOLD}Backup Schedule:${NC}"
    if [ "$backup_enabled" = "true" ]; then
        echo "  Status:   Enabled (every ${backup_interval} min)"
        
        # Find most recent backup and calculate time until next
        local latest_backup
        latest_backup=$( (ls -t "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null || true) | head -1)
        
        if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
            local backup_time
            backup_time=$(stat -c %Y "$latest_backup" 2>/dev/null)
            local current_time
            current_time=$(date +%s)
            local interval_seconds=$((backup_interval * 60))
            local next_backup_time=$((backup_time + interval_seconds))
            local time_remaining=$((next_backup_time - current_time))
            
            if [ $time_remaining -gt 0 ]; then
                local mins=$((time_remaining / 60))
                local secs=$((time_remaining % 60))
                if [ $mins -gt 0 ]; then
                    echo "  Next in:  ${mins}m ${secs}s"
                else
                    echo "  Next in:  ${secs}s"
                fi
            else
                echo "  Next in:  Imminent"
            fi
            
            # Show last backup time
            local last_backup_date
            last_backup_date=$(date -d "@${backup_time}" '+%H:%M:%S' 2>/dev/null)
            echo "  Last:     ${last_backup_date}"
        else
            echo "  Next in:  Pending (no backups yet)"
        fi
    else
        echo "  Status:   Disabled"
    fi
    
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
