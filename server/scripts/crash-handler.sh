#!/bin/bash
#---------------------------------------------------------------
# Crash Handler Script
# Called by Supervisor when the Terraria process exits unexpectedly
#---------------------------------------------------------------

LOG_FILE="/terraria/logs/crash-handler.log"
CRASH_LOG="/terraria/logs/crashes.log"

#---------------------------------------------------------------
# Logging helper
#---------------------------------------------------------------
log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [CRASH-HANDLER] $1" | tee -a "${LOG_FILE}"
}

#---------------------------------------------------------------
# Parse Supervisor event data
#---------------------------------------------------------------
parse_event() {
    # Read the event header from stdin
    read -r header
    
    # Parse header for event info
    # Format: ver:3 server:supervisor serial:21 pool:crashmail poolserial:10 eventname:PROCESS_STATE_EXITED len:84
    local event_name
    event_name=$(echo "${header}" | grep -oP 'eventname:\K\S+')
    
    local data_len
    data_len=$(echo "${header}" | grep -oP 'len:\K\d+')
    
    # Read the event data
    local event_data=""
    if [ -n "${data_len}" ] && [ "${data_len}" -gt 0 ]; then
        read -r -n "${data_len}" event_data
    fi
    
    echo "${event_name}" "${event_data}"
}

#---------------------------------------------------------------
# Handle process state events
#---------------------------------------------------------------
handle_event() {
    local event_name="$1"
    local event_data="$2"
    
    log "Received event: ${event_name}"
    
    case "${event_name}" in
        PROCESS_STATE_EXITED)
            # Process exited - check if it was expected
            local process_name
            process_name=$(echo "${event_data}" | grep -oP 'processname:\K\S+')
            local exit_status
            exit_status=$(echo "${event_data}" | grep -oP 'exitcode:\K\d+' || echo "unknown")
            local expected
            expected=$(echo "${event_data}" | grep -oP 'expected:\K\d+' || echo "1")
            
            if [ "${expected}" = "0" ]; then
                log "CRASH DETECTED: Process '${process_name}' exited unexpectedly with code ${exit_status}"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] CRASH: ${process_name} exited with code ${exit_status}" >> "${CRASH_LOG}"
                
                # Could add notification logic here (webhook, email, etc.)
                # For now, we just log it
            else
                log "Process '${process_name}' exited normally with code ${exit_status}"
            fi
            ;;
        
        PROCESS_STATE_FATAL)
            # Process failed to start
            local process_name
            process_name=$(echo "${event_data}" | grep -oP 'processname:\K\S+')
            
            log "FATAL: Process '${process_name}' failed to start"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] FATAL: ${process_name} failed to start" >> "${CRASH_LOG}"
            ;;
        
        *)
            log "Unhandled event type: ${event_name}"
            ;;
    esac
}

#---------------------------------------------------------------
# Main event loop
#---------------------------------------------------------------
main() {
    log "Crash handler started"
    
    # Create log directory if needed
    mkdir -p "$(dirname "${LOG_FILE}")"
    mkdir -p "$(dirname "${CRASH_LOG}")"
    
    while true; do
        # Tell supervisor we're ready
        echo "READY"
        
        # Parse and handle the event
        read -r event_info
        event_name=$(echo "${event_info}" | awk '{print $1}')
        event_data=$(echo "${event_info}" | cut -d' ' -f2-)
        
        handle_event "${event_name}" "${event_data}"
        
        # Tell supervisor we're done with this event
        echo "RESULT 2"
        echo "OK"
    done
}

# Run main function
main
