#!/bin/bash
#---------------------------------------------------------------
# Container Health Check Script
# Verifies all services are running: Supervisor, Terraria
# Returns 0 (healthy) or 1 (unhealthy)
#---------------------------------------------------------------

# Track health status
HEALTHY=true
ISSUES=""

#---------------------------------------------------------------
# Check Supervisor
#---------------------------------------------------------------
check_supervisor() {
    if [ -S /tmp/supervisor.sock ]; then
        if supervisorctl status >/dev/null 2>&1; then
            return 0
        fi
    fi
    return 1
}

#---------------------------------------------------------------
# Check Terraria Server Process
#---------------------------------------------------------------
check_terraria() {
    if pgrep -f "TerrariaServer" > /dev/null 2>&1; then
        return 0
    fi
    return 1
}

#---------------------------------------------------------------
# Check Backup Scheduler (optional - not critical)
#---------------------------------------------------------------
check_backup_scheduler() {
    if [ "${BACKUP_ENABLED:-true}" = "true" ]; then
        if pgrep -f "backup-scheduler.sh" > /dev/null 2>&1; then
            return 0
        fi
        return 1
    fi
    # If backups are disabled, this check passes
    return 0
}

#---------------------------------------------------------------
# Main health check
#---------------------------------------------------------------
main() {
    # Check Supervisor (critical)
    if ! check_supervisor; then
        HEALTHY=false
        ISSUES="${ISSUES}Supervisor not running. "
    fi
    
    # Check Terraria Server (critical)
    if ! check_terraria; then
        HEALTHY=false
        ISSUES="${ISSUES}Terraria server not running. "
    fi
    
    # Check Backup Scheduler (non-critical, just log warning)
    if ! check_backup_scheduler; then
        echo "[HEALTH] Warning: Backup scheduler not running"
    fi
    
    # Report results
    if [ "$HEALTHY" = "true" ]; then
        echo "[HEALTH] OK - All services running"
        exit 0
    else
        echo "[HEALTH] UNHEALTHY - ${ISSUES}"
        exit 1
    fi
}

main "$@"
