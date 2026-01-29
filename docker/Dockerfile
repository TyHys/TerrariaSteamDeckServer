# TerrariaSteamDeckServer Dockerfile
# Multi-stage build optimized for size and performance
# Runs Terraria Dedicated Server with web management interface

#===============================================================
# Stage 1: Download and extract Terraria server
#===============================================================
FROM debian:bookworm-slim AS terraria-download

ARG TERRARIA_VERSION=1449

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN wget -q "https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip" -O terraria-server.zip \
    && unzip -q terraria-server.zip \
    && mv ${TERRARIA_VERSION}/Linux /terraria-server \
    && chmod +x /terraria-server/TerrariaServer* \
    && rm -rf /tmp/*

#===============================================================
# Stage 2: Build Python virtual environment
#===============================================================
FROM debian:bookworm-slim AS python-build

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY web/backend/requirements.txt .
RUN python3 -m venv /venv && \
    /venv/bin/pip install --no-cache-dir -r requirements.txt

#===============================================================
# Stage 3: Final runtime image
#===============================================================
FROM debian:bookworm-slim

LABEL maintainer="TerrariaSteamDeckServer"
LABEL description="Terraria Dedicated Server optimized for Steam Deck"
LABEL version="8.0.0"

# Environment variables for game configuration
ENV TERRARIA_VERSION=1449
ENV WORLD_NAME="world"
ENV WORLD_SIZE="2"
ENV MAX_PLAYERS="8"
ENV SERVER_PORT="7777"
ENV SERVER_PASSWORD=""
ENV MOTD="Welcome to the Terraria Server!"
ENV DIFFICULTY="0"
ENV AUTOCREATE="2"
ENV SECURE="1"
ENV LANGUAGE="en-US"
ENV WORLD_SEED=""

# Environment variables for process management
ENV RESTART_DELAY="5"
ENV RESTART_DELAY_MAX="60"
ENV RESTART_DELAY_MULTIPLIER="2"

# Environment variables for backup management
ENV BACKUP_ENABLED="true"
ENV BACKUP_INTERVAL="30"
ENV BACKUP_RETENTION="48"
ENV BACKUP_ON_STARTUP="false"
ENV BACKUP_COMPRESSION="gzip"
ENV BACKUP_DIR="/terraria/backups"
ENV WORLD_DIR="/terraria/worlds"

# Environment variables for web API
ENV API_HOST="0.0.0.0"
ENV API_PORT="8080"
ENV API_USERNAME="admin"
ENV API_PASSWORD=""
ENV API_TOKEN_EXPIRY="86400"
ENV API_DEBUG="false"
ENV CORS_ORIGINS="*"

# Install minimal runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    procps \
    libsdl2-2.0-0 \
    supervisor \
    logrotate \
    cron \
    python3 \
    python3-venv \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*

# Create directory structure
RUN mkdir -p \
    /terraria/server \
    /terraria/worlds \
    /terraria/config \
    /terraria/logs \
    /terraria/scripts \
    /terraria/backups \
    /terraria/web/frontend

# Copy Terraria server from download stage
COPY --from=terraria-download /terraria-server/ /terraria/server/

# Copy Python virtual environment from build stage
COPY --from=python-build /venv /terraria/web/venv

# Set working directory
WORKDIR /terraria

# Copy configuration files
COPY server/config/serverconfig.txt /terraria/config/serverconfig.txt
COPY server/config/supervisord.conf /terraria/config/supervisord.conf
COPY server/config/logrotate.conf /terraria/config/logrotate.conf

# Copy scripts
COPY server/scripts/ /terraria/scripts/

# Make all scripts executable
RUN chmod +x /terraria/scripts/*.sh

# Copy web backend and frontend
COPY web/backend/ /terraria/web/
COPY web/frontend/ /terraria/web/frontend/

# Create non-root user for the Terraria server process
RUN useradd -m -d /terraria -s /bin/bash terraria \
    && chown -R terraria:terraria /terraria/worlds /terraria/logs /terraria/backups /terraria/config

# Set up logrotate cron job
RUN echo "0 * * * * /usr/sbin/logrotate /etc/logrotate.d/terraria" >> /etc/crontab

# Expose ports
EXPOSE 7777/tcp
EXPOSE 8080/tcp

# Define volumes for persistence
VOLUME ["/terraria/worlds", "/terraria/config", "/terraria/logs", "/terraria/backups"]

# Enhanced health check - verifies Terraria server, API, and supervisor
HEALTHCHECK --interval=30s --timeout=15s --start-period=90s --retries=3 \
    CMD /terraria/scripts/healthcheck.sh || exit 1

# Start with entrypoint script (runs Supervisor)
ENTRYPOINT ["/terraria/scripts/entrypoint.sh"]
