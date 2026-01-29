# TerrariaSteamDeckServer Makefile
# Simplified commands for building, running, and managing the server

.PHONY: help build build-no-cache run start stop restart logs shell status health \
        backup restore worlds clean clean-all setup test validate-env

# Default target
.DEFAULT_GOAL := help

# Container name
CONTAINER_NAME := terraria-server
COMPOSE_FILE := docker/docker-compose.yml

#---------------------------------------------------------------
# Help
#---------------------------------------------------------------
help:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║       Terraria Steam Deck Server - Make Commands          ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "  Setup & Build:"
	@echo "    make setup           - First-time setup (create .env, directories)"
	@echo "    make build           - Build the Docker image"
	@echo "    make build-no-cache  - Build without cache (fresh build)"
	@echo ""
	@echo "  Running:"
	@echo "    make run             - Build and start the server"
	@echo "    make start           - Start the server (detached)"
	@echo "    make stop            - Stop the server"
	@echo "    make restart         - Restart the server"
	@echo ""
	@echo "  Monitoring:"
	@echo "    make logs            - Follow container logs"
	@echo "    make status          - Show server status"
	@echo "    make health          - Run health check"
	@echo "    make shell           - Open shell in container"
	@echo ""
	@echo "  Management:"
	@echo "    make backup          - Create manual backup"
	@echo "    make worlds          - List worlds"
	@echo "    make backups         - List backups"
	@echo ""
	@echo "  Testing:"
	@echo "    make test            - Run full integration test"
	@echo "    make validate-env    - Validate environment configuration"
	@echo ""
	@echo "  Cleanup:"
	@echo "    make clean           - Stop and remove container"
	@echo "    make clean-all       - Remove container, images, and volumes"
	@echo ""

#---------------------------------------------------------------
# Setup
#---------------------------------------------------------------
setup:
	@echo "Setting up TerrariaSteamDeckServer..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env file from template"; \
		echo ""; \
		echo "IMPORTANT: Edit .env and set API_PASSWORD before running!"; \
		echo "  Example: API_PASSWORD=your_secure_password_here"; \
		echo ""; \
	else \
		echo ".env file already exists"; \
	fi
	@mkdir -p data/worlds data/backups data/logs data/config
	@echo "Created data directories"
	@echo ""
	@echo "Setup complete! Next steps:"
	@echo "  1. Edit .env and set API_PASSWORD"
	@echo "  2. Run 'make build' to build the image"
	@echo "  3. Run 'make start' to start the server"
	@echo ""

validate-env:
	@echo "Validating environment configuration..."
	@if [ ! -f .env ]; then \
		echo "ERROR: .env file not found. Run 'make setup' first."; \
		exit 1; \
	fi
	@. ./.env && \
	if [ -z "$$API_PASSWORD" ]; then \
		echo "ERROR: API_PASSWORD is not set in .env"; \
		echo "Please edit .env and set a secure password."; \
		exit 1; \
	fi
	@echo "Environment configuration is valid."

#---------------------------------------------------------------
# Build
#---------------------------------------------------------------
build:
	@echo "Building Docker image..."
	docker compose -f $(COMPOSE_FILE) build

build-no-cache:
	@echo "Building Docker image (no cache)..."
	docker compose -f $(COMPOSE_FILE) build --no-cache

#---------------------------------------------------------------
# Running
#---------------------------------------------------------------
run: validate-env build
	@echo "Starting server..."
	docker compose -f $(COMPOSE_FILE) up

start: validate-env
	@echo "Starting server (detached)..."
	docker compose -f $(COMPOSE_FILE) up -d
	@echo ""
	@echo "Server starting! Access the web interface at:"
	@echo "  http://localhost:8080"
	@echo ""
	@echo "Run 'make logs' to follow the server logs."
	@echo "Run 'make status' to check the server status."

stop:
	@echo "Stopping server..."
	docker compose -f $(COMPOSE_FILE) down
	@echo "Server stopped."

restart: stop start

#---------------------------------------------------------------
# Monitoring
#---------------------------------------------------------------
logs:
	docker compose -f $(COMPOSE_FILE) logs -f

status:
	@echo "Container Status:"
	@docker compose -f $(COMPOSE_FILE) ps
	@echo ""
	@if docker ps -q -f name=$(CONTAINER_NAME) | grep -q .; then \
		echo "Service Status:"; \
		docker exec $(CONTAINER_NAME) supervisorctl status 2>/dev/null || echo "  Supervisor not responding"; \
		echo ""; \
		echo "Quick Info:"; \
		docker exec $(CONTAINER_NAME) /terraria/scripts/server-control.sh status 2>/dev/null | head -20 || true; \
	else \
		echo "Container is not running."; \
	fi

health:
	@if docker ps -q -f name=$(CONTAINER_NAME) | grep -q .; then \
		docker exec $(CONTAINER_NAME) /terraria/scripts/healthcheck.sh; \
	else \
		echo "Container is not running."; \
		exit 1; \
	fi

shell:
	@if docker ps -q -f name=$(CONTAINER_NAME) | grep -q .; then \
		docker exec -it $(CONTAINER_NAME) /bin/bash; \
	else \
		echo "Container is not running. Start with 'make start' first."; \
	fi

#---------------------------------------------------------------
# Management
#---------------------------------------------------------------
backup:
	@if docker ps -q -f name=$(CONTAINER_NAME) | grep -q .; then \
		docker exec $(CONTAINER_NAME) /terraria/scripts/backup.sh create; \
	else \
		echo "Container is not running."; \
	fi

backups:
	@if docker ps -q -f name=$(CONTAINER_NAME) | grep -q .; then \
		docker exec $(CONTAINER_NAME) /terraria/scripts/backup.sh list; \
	else \
		echo "Container is not running."; \
	fi

worlds:
	@if docker ps -q -f name=$(CONTAINER_NAME) | grep -q .; then \
		docker exec $(CONTAINER_NAME) /terraria/scripts/world-manager.sh list; \
	else \
		echo "Container is not running."; \
	fi

#---------------------------------------------------------------
# Testing
#---------------------------------------------------------------
test: validate-env
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║           Running Integration Tests                       ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "1. Building Docker image..."
	@docker compose -f $(COMPOSE_FILE) build --quiet
	@echo "   ✓ Build successful"
	@echo ""
	@echo "2. Starting container..."
	@docker compose -f $(COMPOSE_FILE) up -d
	@echo "   ✓ Container started"
	@echo ""
	@echo "3. Waiting for services to initialize (30s)..."
	@sleep 30
	@echo ""
	@echo "4. Checking service health..."
	@if docker exec $(CONTAINER_NAME) /terraria/scripts/healthcheck.sh; then \
		echo "   ✓ All services healthy"; \
	else \
		echo "   ✗ Health check failed"; \
		docker compose -f $(COMPOSE_FILE) logs --tail=50; \
		docker compose -f $(COMPOSE_FILE) down; \
		exit 1; \
	fi
	@echo ""
	@echo "5. Testing API endpoints..."
	@API_STATUS=$$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/status); \
	if [ "$$API_STATUS" = "200" ]; then \
		echo "   ✓ API is responding"; \
	else \
		echo "   ✗ API returned status $$API_STATUS"; \
		docker compose -f $(COMPOSE_FILE) down; \
		exit 1; \
	fi
	@echo ""
	@echo "6. Testing web interface..."
	@WEB_STATUS=$$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/); \
	if [ "$$WEB_STATUS" = "200" ]; then \
		echo "   ✓ Web interface is serving"; \
	else \
		echo "   ✗ Web interface returned status $$WEB_STATUS"; \
		docker compose -f $(COMPOSE_FILE) down; \
		exit 1; \
	fi
	@echo ""
	@echo "7. Stopping container..."
	@docker compose -f $(COMPOSE_FILE) down --quiet 2>/dev/null || docker compose -f $(COMPOSE_FILE) down
	@echo "   ✓ Container stopped"
	@echo ""
	@echo "╔═══════════════════════════════════════════════════════════╗"
	@echo "║           All Tests Passed!                               ║"
	@echo "╚═══════════════════════════════════════════════════════════╝"
	@echo ""

#---------------------------------------------------------------
# Cleanup
#---------------------------------------------------------------
clean:
	@echo "Stopping and removing container..."
	docker compose -f $(COMPOSE_FILE) down
	@echo "Done."

clean-all:
	@echo "WARNING: This will remove the container, images, and ALL DATA volumes."
	@echo "Press Ctrl+C within 5 seconds to cancel..."
	@sleep 5
	@echo "Removing container and volumes..."
	docker compose -f $(COMPOSE_FILE) down -v --rmi local
	@echo "Done."
