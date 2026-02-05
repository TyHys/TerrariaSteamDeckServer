#!/bin/bash
#===============================================================================
# Admin Commands - build, update, setup, test, clean, clean-all
# Sourced by server.sh - do not run directly
#===============================================================================

#-------------------------------------------------------------------------------
# Command: build
# Builds the Docker image
# Usage: ./server.sh build [--no-cache]
#-------------------------------------------------------------------------------
cmd_build() {
    local no_cache=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-cache)
                no_cache=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Usage: $0 build [--no-cache]"
                return 1
                ;;
        esac
    done
    
    print_header "Building Docker Image"
    
    if [ "$no_cache" = true ]; then
        print_info "Building without cache (fresh build)..."
        docker_compose build --no-cache
    else
        print_info "Building with cache..."
        docker_compose build
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Docker image built successfully!"
    else
        print_error "Failed to build Docker image"
        return 1
    fi
}

#-------------------------------------------------------------------------------
# Command: update
# Updates the Terraria server to a new version
# Usage: ./server.sh update [version]
#   version: Optional version number (positive integer, e.g., 1453 for Terraria 1.4.5.3)
#            If not provided, just rebuilds with the current version
#-------------------------------------------------------------------------------
cmd_update() {
    local new_version="$1"
    local dockerfile="${PROJECT_ROOT}/docker/Dockerfile"
    
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
    
    # If no version specified, print error and exit
    if [ -z "$new_version" ]; then
        print_error "Version argument required."
        echo ""
        echo "Usage: $0 update <version>"
        echo "Example: $0 update 1453"
        echo ""
        echo "Current version: ${current_version}"
        echo ""
        return 1
    fi
    
    # Validate version format (should be a positive integer)
    if ! [[ "$new_version" =~ ^[0-9]+$ ]] || [ "$new_version" -le 0 ]; then
        print_error "Invalid version format: ${new_version}"
        echo "Version argument must be a positive integer."
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
# Command: setup
# First-time setup - creates .env and directories
#-------------------------------------------------------------------------------
cmd_setup() {
    print_header "First-Time Setup"
    
    # Create .env file
    if [ ! -f "${ENV_FILE}" ]; then
        if [ -f "${PROJECT_ROOT}/.env.example" ]; then
            cp "${PROJECT_ROOT}/.env.example" "${ENV_FILE}"
            print_success "Created .env file from template"
        else
            print_error ".env.example not found"
            return 1
        fi
    else
        print_info ".env file already exists"
    fi
    
    # Create data directories
    print_info "Creating data directories..."
    mkdir -p "${DATA_DIR}/worlds" "${DATA_DIR}/backups" "${DATA_DIR}/logs" "${DATA_DIR}/config"
    print_success "Data directories created"
    
    echo ""
    echo -e "${BOLD}Setup complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. (Optional) Edit .env to customize settings"
    echo "  2. Run '$0 build' to build the Docker image"
    echo "  3. Run '$0 start' to start the server"
    echo ""
}



#-------------------------------------------------------------------------------
# Command: clean
# Stop and remove container
#-------------------------------------------------------------------------------
cmd_clean() {
    print_header "Cleaning Up Container"
    
    print_info "Stopping and removing container..."
    docker_compose down
    
    print_success "Container removed"
}

#-------------------------------------------------------------------------------
# Command: clean-all
# Remove container, images, and volumes (destructive!)
#-------------------------------------------------------------------------------
cmd_clean_all() {
    print_header "Full Cleanup"
    
    print_warning "This will remove the container, images, and ALL DATA volumes!"
    print_warning "Your world files in data/worlds will be preserved (bind mount)."
    echo ""
    read -r -p "Are you sure? Type 'yes' to confirm: " confirm
    
    if [ "$confirm" != "yes" ]; then
        print_info "Cleanup cancelled."
        return 0
    fi
    
    echo ""
    print_info "Removing container and volumes..."
    docker_compose down -v --rmi local
    
    print_success "Full cleanup complete"
    echo ""
    print_info "Note: World files in data/worlds/ are preserved."
    print_info "Run '$0 build' to rebuild the image."
}
