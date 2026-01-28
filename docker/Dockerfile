# TerrariaSteamDeckServer Dockerfile
# Runs a Terraria Dedicated Server using the official server binary
# Managed by Supervisor for process monitoring and automatic restart

FROM debian:bookworm-slim

LABEL maintainer="TerrariaSteamDeckServer"
LABEL description="Terraria Dedicated Server optimized for Steam Deck"
LABEL version="2.0.0"

# Environment variables for game configuration
ENV TERRARIA_VERSION=1449
ENV TERRARIA_SERVER_URL="https://terraria.org/api/download/pc-dedicated-server/terraria-server-${TERRARIA_VERSION}.zip"
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

# Environment variables for process management
ENV RESTART_DELAY="5"
ENV RESTART_DELAY_MAX="60"
ENV RESTART_DELAY_MULTIPLIER="2"

# Install dependencies including Supervisor for process management
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip \
    ca-certificates \
    procps \
    libsdl2-2.0-0 \
    supervisor \
    logrotate \
    cron \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create directories
RUN mkdir -p /terraria/server /terraria/worlds /terraria/config /terraria/logs /terraria/scripts

# Download and extract Terraria server
WORKDIR /tmp
RUN wget -q "${TERRARIA_SERVER_URL}" -O terraria-server.zip \
    && unzip -q terraria-server.zip \
    && mv ${TERRARIA_VERSION}/Linux/* /terraria/server/ \
    && chmod +x /terraria/server/TerrariaServer* \
    && rm -rf /tmp/*

# Set working directory
WORKDIR /terraria

# Copy configuration files
COPY server/config/serverconfig.txt /terraria/config/serverconfig.txt
COPY server/config/supervisord.conf /terraria/config/supervisord.conf
COPY server/config/logrotate.conf /terraria/config/logrotate.conf

# Copy scripts
COPY server/scripts/entrypoint.sh /terraria/scripts/entrypoint.sh
COPY server/scripts/terraria-wrapper.sh /terraria/scripts/terraria-wrapper.sh
COPY server/scripts/crash-handler.sh /terraria/scripts/crash-handler.sh
COPY server/scripts/start-server.sh /terraria/scripts/start-server.sh

# Make scripts executable
RUN chmod +x /terraria/scripts/*.sh

# Create non-root user for the Terraria server process
# Note: Supervisor runs as root to manage the terraria user process
RUN useradd -m -d /terraria -s /bin/bash terraria \
    && chown -R terraria:terraria /terraria/worlds /terraria/logs

# Set up logrotate cron job
RUN echo "0 * * * * /usr/sbin/logrotate /etc/logrotate.d/terraria" >> /etc/crontab

# Expose Terraria server port
EXPOSE 7777/tcp

# Define volumes for persistence
VOLUME ["/terraria/worlds", "/terraria/config", "/terraria/logs"]

# Health check - verify server process is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f "TerrariaServer" > /dev/null || exit 1

# Start with entrypoint script (runs Supervisor)
ENTRYPOINT ["/terraria/scripts/entrypoint.sh"]
