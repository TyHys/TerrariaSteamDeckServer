#!/bin/bash
#
# Terraria Steam Deck Server - Quick Install Script
# Checks dependencies, installs if needed, and launches the server
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

#---------------------------------------------------------------
# Helper Functions
#---------------------------------------------------------------

print_banner() {
    echo ""
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       Terraria Steam Deck Server - Quick Install          ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    
    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    
    read -r -p "$prompt" response
    response="${response:-$default}"
    
    [[ "$response" =~ ^[Yy]$ ]]
}

check_steam_deck() {
    if [[ -f /etc/os-release ]] && grep -q "SteamOS" /etc/os-release; then
        return 0
    fi
    return 1
}

#---------------------------------------------------------------
# Dependency Checks
#---------------------------------------------------------------

check_docker() {
    if command -v docker &> /dev/null; then
        local version=$(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')
        log_success "Docker installed (v$version)"
        return 0
    else
        log_warn "Docker not found"
        return 1
    fi
}

check_docker_compose() {
    if docker compose version &> /dev/null; then
        local version=$(docker compose version 2>/dev/null | cut -d' ' -f4 | tr -d 'v')
        log_success "Docker Compose installed (v$version)"
        return 0
    elif command -v docker-compose &> /dev/null; then
        local version=$(docker-compose --version 2>/dev/null | cut -d' ' -f4 | tr -d ',')
        log_success "Docker Compose installed (v$version)"
        return 0
    else
        log_warn "Docker Compose not found"
        return 1
    fi
}

check_docker_running() {
    if docker info &> /dev/null; then
        log_success "Docker daemon is running"
        return 0
    else
        log_warn "Docker daemon not running"
        return 1
    fi
}

check_docker_permissions() {
    if docker ps &> /dev/null; then
        log_success "Docker permissions OK"
        return 0
    else
        log_warn "Cannot access Docker (may need to log out/in after install)"
        return 1
    fi
}

#---------------------------------------------------------------
# Installation Functions
#---------------------------------------------------------------

install_docker_steam_deck() {
    log_info "Installing Docker on Steam Deck..."
    echo ""
    log_warn "This requires sudo access and will temporarily disable the read-only filesystem."
    echo ""
    
    if ! prompt_yes_no "Continue with Docker installation?"; then
        log_error "Docker installation cancelled."
        exit 1
    fi
    
    echo ""
    log_info "Disabling read-only filesystem..."
    sudo steamos-readonly disable
    
    log_info "Initializing pacman keyring..."
    sudo pacman-key --init
    sudo pacman-key --populate archlinux
    sudo pacman-key --populate holo
    
    log_info "Refreshing package database..."
    sudo pacman -Syy
    
    log_info "Installing Docker and Docker Compose..."
    sudo pacman -S docker docker-compose --noconfirm
    
    log_info "Enabling Docker service..."
    sudo systemctl enable docker
    sudo systemctl start docker
    
    log_info "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
    
    log_info "Re-enabling read-only filesystem..."
    sudo steamos-readonly enable
    
    log_success "Docker installed successfully!"
    echo ""
    log_warn "You need to log out and back in for docker group permissions to take effect."
    log_warn "After logging back in, run this script again to continue setup."
    echo ""
    
    if prompt_yes_no "Would you like to try using 'newgrp docker' to continue without logging out?" "n"; then
        echo ""
        log_info "Attempting to activate docker group..."
        log_info "A new shell will open. Run './install.sh' again in the new shell."
        exec newgrp docker
    else
        exit 0
    fi
}

install_docker_generic() {
    log_error "Docker is not installed."
    echo ""
    echo "Please install Docker for your system:"
    echo "  - Ubuntu/Debian: sudo apt install docker.io docker-compose-plugin"
    echo "  - Fedora: sudo dnf install docker docker-compose-plugin"
    echo "  - Arch: sudo pacman -S docker docker-compose"
    echo "  - Or visit: https://docs.docker.com/get-docker/"
    echo ""
    exit 1
}

start_docker_service() {
    log_info "Starting Docker daemon..."
    
    if check_steam_deck; then
        sudo steamos-readonly disable
        sudo systemctl start docker
        sudo steamos-readonly enable
    else
        sudo systemctl start docker
    fi
    
    sleep 2
    
    if check_docker_running; then
        return 0
    else
        log_error "Failed to start Docker daemon"
        return 1
    fi
}

#---------------------------------------------------------------
# Setup Functions
#---------------------------------------------------------------

setup_env() {
    if [[ -f .env ]]; then
        log_success ".env file exists"
    else
        log_info "Creating .env from template..."
        cp .env.example .env
        log_success ".env file created"
    fi
}

setup_directories() {
    log_info "Creating data directories..."
    mkdir -p data/worlds data/backups data/logs data/config
    log_success "Data directories ready"
}

build_image() {
    log_info "Building Docker image (this may take a few minutes)..."
    echo ""
    
    if docker compose -f docker/docker-compose.yml --env-file .env build; then
        echo ""
        log_success "Docker image built successfully"
        return 0
    else
        echo ""
        log_error "Failed to build Docker image"
        return 1
    fi
}

start_server() {
    log_info "Starting Terraria server..."
    
    if docker compose -f docker/docker-compose.yml --env-file .env up -d; then
        log_success "Server started!"
        return 0
    else
        log_error "Failed to start server"
        return 1
    fi
}

wait_for_server() {
    log_info "Waiting for server to initialize..."
    
    local max_wait=60
    local waited=0
    
    while [[ $waited -lt $max_wait ]]; do
        # Check if container is running and healthy
        if docker ps --filter "name=terraria-server" --filter "health=healthy" --format '{{.Names}}' | grep -q "terraria-server"; then
            log_success "Server is healthy!"
            return 0
        fi
        
        # Check if at least the container is running
        if docker ps --filter "name=terraria-server" --format '{{.Names}}' | grep -q "terraria-server"; then
            # Container is running, just not healthy yet
            :
        fi
        
        sleep 2
        waited=$((waited + 2))
        echo -n "."
    done
    
    echo ""
    log_warn "Server may still be starting. Check logs with: ./server.sh logs"
    return 1
}

print_success() {
    local ip_addr=$(hostname -I 2>/dev/null | awk '{print $1}')
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Setup Complete!                              ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}Game Server:${NC}"
    echo "  Local:  localhost:7777"
    if [[ -n "$ip_addr" ]]; then
        echo "  LAN:    ${ip_addr}:7777"
    fi
    echo ""
    echo -e "${CYAN}Management:${NC}"
    echo "  ./server.sh status    - Check server status"
    echo "  ./server.sh logs      - View server logs"
    echo "  ./server.sh stop      - Stop the server"
    echo "  ./server.sh help      - See all commands"
    echo ""
}

#---------------------------------------------------------------
# Main
#---------------------------------------------------------------

main() {
    print_banner
    
    # Check if running on Steam Deck
    if check_steam_deck; then
        log_info "Steam Deck detected"
    else
        log_info "Running on standard Linux"
    fi
    echo ""
    
    #-----------------------------------------------------------
    # Step 1: Check Docker
    #-----------------------------------------------------------
    log_info "Checking dependencies..."
    echo ""
    
    local docker_installed=false
    local docker_running=false
    local docker_perms=false
    
    if check_docker; then
        docker_installed=true
    fi
    
    if [[ "$docker_installed" == "true" ]]; then
        if check_docker_compose; then
            :
        fi
        
        if check_docker_running; then
            docker_running=true
        fi
        
        if [[ "$docker_running" == "true" ]]; then
            if check_docker_permissions; then
                docker_perms=true
            fi
        fi
    fi
    
    echo ""
    
    #-----------------------------------------------------------
    # Step 2: Install/Fix Docker if needed
    #-----------------------------------------------------------
    
    if [[ "$docker_installed" == "false" ]]; then
        echo ""
        if check_steam_deck; then
            install_docker_steam_deck
        else
            install_docker_generic
        fi
    fi
    
    if [[ "$docker_running" == "false" ]] && [[ "$docker_installed" == "true" ]]; then
        if prompt_yes_no "Would you like to start the Docker service?"; then
            start_docker_service
            docker_running=true
            
            # Re-check permissions after starting
            if check_docker_permissions; then
                docker_perms=true
            fi
        else
            log_error "Docker daemon must be running to continue."
            exit 1
        fi
    fi
    
    if [[ "$docker_perms" == "false" ]] && [[ "$docker_running" == "true" ]]; then
        log_error "Cannot access Docker. This usually means you need to log out and back in"
        log_error "after being added to the docker group."
        echo ""
        log_info "Try running: newgrp docker"
        log_info "Then run this script again."
        exit 1
    fi
    
    #-----------------------------------------------------------
    # Step 3: Setup project
    #-----------------------------------------------------------
    echo ""
    log_info "Setting up project..."
    echo ""
    
    setup_directories
    setup_env
    
    #-----------------------------------------------------------
    # Step 4: Build and start
    #-----------------------------------------------------------
    echo ""
    
    if prompt_yes_no "Build and start the server now?"; then
        echo ""
        build_image
        echo ""
        start_server
        echo ""
        wait_for_server
        print_success
    else
        echo ""
        log_info "Setup complete. To start the server later, run:"
        echo "  ./server.sh start"
        echo ""
    fi
}

# Run main
main "$@"
