# Terraria Steam Deck Server

A Docker-containerized Terraria dedicated server optimized for Steam Deck devices. Features automated backups, robust process management, and easy CLI-based management.

## Features

- **Terraria Dedicated Server** - Official Terraria server binary (v1.4.5.3)
- **CLI Management** - Simple command-line management via `./server.sh`
- **Automated Backups** - Scheduled backups with configurable retention and compression
- **Process Management** - Automatic crash recovery with Supervisor and exponential backoff
- **Easy Configuration** - Environment variables for all settings via `.env` file
- **Steam Deck Optimized** - Resource limits (1.5GB RAM) suitable for Steam Deck hardware
- **Health Monitoring** - Built-in health checks for all services
- **Graceful Shutdown** - Proper world saving on container stop (45 second grace period)
- **Log Management** - Automatic log rotation to prevent disk space issues

## Quick Start

### One-Command Install (Recommended)

The install script checks all dependencies, installs Docker if needed, and launches the server:

```bash
./install.sh
```

The script will:
- Detect if you're on Steam Deck
- Install Docker if not present (with your permission)
- Create configuration files
- Build and start the server

### Manual Installation

If you prefer to install manually, follow these steps:

#### Prerequisites

- **Docker and Docker Compose** - See [Installing Docker on Steam Deck](#installing-docker-on-steam-deck) below
- Port 7777 available for the game server

#### Steps

1. **Clone or download this repository**

```bash
cd ~/code_projects
git clone <repository-url> TerrariaSteamDeckServer
cd TerrariaSteamDeckServer
```

2. **Run setup**

```bash
# Create .env from template
cp .env.example .env

# Create data directories
mkdir -p data/worlds data/backups data/logs data/config
```

3. **(Optional) Configure settings**

Edit the `.env` file to customize server settings:

```bash
nano .env
```

4. **Build and start the server**

```bash
# Build the Docker image
docker compose -f docker/docker-compose.yml build

# Start the server
docker compose -f docker/docker-compose.yml up -d
```

Or use the management script:

```bash
./server.sh start
```

### Connecting to the Game Server

Players can connect to your server at:
- **Local**: `localhost:7777` or `your-ip:7777`
- **Remote**: Requires port forwarding on your router (port 7777)

## Management Script

The `./server.sh` script provides all management functionality:

```bash
./server.sh help      # Show all commands
./server.sh status    # Check server status
./server.sh start     # Start the server
./server.sh stop      # Stop the server
./server.sh restart   # Restart the server
./server.sh docker-logs # View container logs
./server.sh game-logs   # View game logs
./server.sh backup    # Create a backup
./server.sh backups   # List all backups
./server.sh restore <backup-file>  # Restore from backup
./server.sh save      # Save the world
./server.sh say "message"  # Broadcast to players
```

### Full Command Reference

#### Server Control

| Command | Description |
|---------|-------------|
| `./server.sh start` | Start the server container |
| `./server.sh stop` | Stop the server container (saves world, up to 45s) |
| `./server.sh restart` | Restart the server container |
| `./server.sh status` | Show server status, players, worlds, backups, and network info |
| `./server.sh players` | Show currently online players |

#### In-Game Commands

| Command | Description |
|---------|-------------|
| `./server.sh save` | Save the world immediately (with optional backup prompt) |
| `./server.sh say <message>` | Broadcast a message to all players |
| `./server.sh command <cmd>` | Send any Terraria server command (help, playing, kick, ban, etc.) |

#### Backup Management

| Command | Description |
|---------|-------------|
| `./server.sh backup [world]` | Create a backup (all or specific world) |
| `./server.sh restore <file>` | Restore from a backup file (host-based, no container needed) |
| `./server.sh backups` | List all available backups with size and date |
| `./server.sh backup-schedule` | Interactive configuration for automatic backups |

#### Logs and Debugging

| Command | Description |
|---------|-------------|
| `./server.sh docker-logs [lines]` | Show container logs (system/service logs) (default: 100 lines) |
| `./server.sh game-logs [lines]` | Show Terraria server stdout logs (default: 100 lines) |
| `./server.sh console` | Attach to Terraria server console (Ctrl+P, Ctrl+Q to detach) |
| `./server.sh shell` | Open a bash shell in the container |
| `./server.sh exec <cmd>` | Execute a command in the container |

#### Updates and Maintenance

| Command | Description |
|---------|-------------|
| `./server.sh update <version>` | Update Terraria to a new version (e.g., 1453 for v1.4.5.3) |
| `./server.sh help` | Show all available commands with examples |

## Configuration

All configuration is done via environment variables in the `.env` file. Run `./install.sh` or `cp .env.example .env` to create the file from the template.

### Game Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `WORLD_NAME` | `world` | World name (without .wld extension) |
| `WORLD_SIZE` | `2` | 1=Small (~40MB), 2=Medium (~80MB), 3=Large (~160MB) |
| `DIFFICULTY` | `0` | 0=Classic, 1=Expert, 2=Master, 3=Journey |
| `MAX_PLAYERS` | `8` | Maximum concurrent players (1-255, 8-16 recommended for Steam Deck) |
| `SERVER_PORT` | `7777` | TCP port for game connections |
| `SERVER_PASSWORD` | *(empty)* | Server password (leave empty for no password) |
| `MOTD` | `Welcome to the Terraria Server!` | Message shown to players on join |
| `AUTOCREATE` | `2` | Auto-create world if missing: 0=disabled, 1=small, 2=medium, 3=large |
| `WORLD_SEED` | *(empty)* | Seed for world generation (leave empty for random) |
| `SECURE` | `1` | Anti-cheat: 0=disabled, 1=enabled |
| `LANGUAGE` | `en-US` | Server language |

### Backup Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_ENABLED` | `true` | Enable automatic backups |
| `BACKUP_INTERVAL` | `30` | Minutes between backups (recommended: 15-60) |
| `BACKUP_RETENTION` | `48` | Number of backups to keep (~24 hours at 30-min intervals) |
| `BACKUP_ON_STARTUP` | `false` | Create backup when container starts |
| `BACKUP_COMPRESSION` | `gzip` | Compression type: `gzip` (smaller) or `none` (faster) |

### Process Management

| Variable | Default | Description |
|----------|---------|-------------|
| `RESTART_DELAY` | `5` | Initial delay (seconds) before restarting after crash |
| `RESTART_DELAY_MAX` | `60` | Maximum delay between restart attempts |
| `RESTART_DELAY_MULTIPLIER` | `2` | Multiplier for exponential backoff |

See `.env.example` for the complete template with comments, or [CONFIGURATION.md](docs/CONFIGURATION.md) for detailed explanations.

## Updating Terraria Version

To update the server to a new Terraria version:

```bash
./server.sh update 1453    # Update to version 1.4.5.3
```

### Finding Version Numbers

Terraria uses a condensed 4-digit version format:

| Game Version | Server Version |
|--------------|----------------|
| 1.4.4.9      | 1449           |
| 1.4.5.0      | 1450           |
| 1.4.5.1      | 1451           |
| 1.4.5.3      | 1453           |

**Pattern:** Remove dots and trailing zeros (e.g., `1.4.5.3` → `1453`)

**Official Resources:**
- [Terraria Wiki - Server Downloads](https://terraria.wiki.gg/wiki/Server#Downloads) - List of all available server versions
- Direct download URL pattern: `https://terraria.org/api/download/pc-dedicated-server/terraria-server-{VERSION}.zip`

> **Note:** Players must be on the same version as the server to connect. Coordinate updates with your players.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                      Docker Container                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │                  Supervisor (Process Manager)              │  │
│  │                    - Auto-restart on crash                 │  │
│  │                    - Exponential backoff                   │  │
│  │                    - Graceful shutdown handling            │  │
│  └────────────────────────────────────────────────────────────┘  │
│                │                              │                  │
│                ▼                              ▼                  │
│  ┌─────────────────────────┐    ┌─────────────────────────────┐  │
│  │   Terraria Server       │    │     Backup Scheduler        │  │
│  │   (Port 7777/TCP)       │    │   - Scheduled backups       │  │
│  │   - World management    │    │   - Retention policy        │  │
│  │   - Player connections  │    │   - Compression support     │  │
│  │   - Command FIFO input  │    │   - Per-world management    │  │
│  └─────────────────────────┘    └─────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              Health Check & Log Rotation                   │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
                    │            │            │
                    ▼            ▼            ▼
            ┌───────────┐ ┌───────────┐ ┌───────────┐
            │  Worlds   │ │  Backups  │ │   Logs    │
            │ data/     │ │ data/     │ │ data/     │
            │ worlds/   │ │ backups/  │ │ logs/     │
            └───────────┘ └───────────┘ └───────────┘
```

### Resource Limits (Steam Deck Optimized)

| Resource | Limit | Reserved |
|----------|-------|----------|
| Memory | 1536 MB | 768 MB |
| Shutdown Grace Period | 45 seconds | - |

## Data Persistence

All data is stored in the `data/` directory and persists across container restarts:

| Directory | Contents |
|-----------|----------|
| `data/worlds/` | World files (.wld) and automatic backups (.wld.bak) |
| `data/backups/` | Compressed backup archives with timestamps |
| `data/logs/` | Server, Supervisor, and backup scheduler logs |
| `data/config/` | Runtime configuration files |

## Port Forwarding (for Public Hosting)

To allow players from outside your network:

1. Forward port **7777/TCP** on your router to your Steam Deck's IP

Consult your router's documentation for specific port forwarding instructions.

## Documentation

Comprehensive documentation is available in the `docs/` folder:

| Document | Description |
|----------|-------------|
| [SETUP.md](docs/SETUP.md) | Detailed installation guide, Steam Deck-specific setup |
| [CONFIGURATION.md](docs/CONFIGURATION.md) | All configuration options explained |
| [NETWORKING.md](docs/NETWORKING.md) | Port forwarding, firewall, remote access |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |

## Terraria Server Commands

You can send any Terraria server command using `./server.sh command <cmd>`:

| Command | Description |
|---------|-------------|
| `help` | Show server command help |
| `playing` | Show connected players |
| `save` | Save the world |
| `exit` | Save and shutdown server |
| `kick <player>` | Kick a player |
| `ban <player>` | Ban a player |
| `password <pass>` | Change server password |
| `motd <message>` | Change message of the day |
| `say <message>` | Broadcast a message |
| `time` | Show current in-game time |
| `dawn/noon/dusk/midnight` | Set time of day |
| `settle` | Settle all liquids |

## Troubleshooting

Quick fixes for common issues. For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOULING.md).

| Problem | Quick Fix |
|---------|-----------|
| Server won't start | `./server.sh stop && ./server.sh start` |
| Check server status | `./server.sh status` |
| View recent game logs | `./server.sh game-logs 50` |
| View container logs | `./server.sh docker-logs 50` |
| Terraria crash | Check `data/logs/terraria-stderr.log` |
| No backups running | Verify `BACKUP_ENABLED=true` in `.env` |
| Out of memory | Increase limits in `docker/docker-compose.yml` |
| World corrupt | Restore from backup: `./server.sh restore <backup-file>` |
| Connection refused | Check firewall, port forwarding |
| Container missing | `./server.sh start` |

### Diagnostic Commands

```bash
./server.sh status                    # Full status overview
./server.sh docker-logs 100           # View recent container logs
./server.sh game-logs 100             # View recent game logs
./server.sh exec /terraria/scripts/healthcheck.sh  # Run health check
docker stats terraria-server          # Resource usage
```

## Development

### Project Structure

```
TerrariaSteamDeckServer/
├── docker/
│   ├── Dockerfile              # Multi-stage build for Terraria server
│   └── docker-compose.yml      # Container orchestration with resource limits
├── server/
│   ├── config/
│   │   ├── serverconfig.txt    # Server configuration template
│   │   ├── supervisord.conf    # Process manager configuration
│   │   └── logrotate.conf      # Log rotation settings
│   └── scripts/
│       ├── entrypoint.sh       # Container initialization
│       ├── terraria-wrapper.sh # Server wrapper with crash recovery
│       ├── backup.sh           # Backup creation and management
│       ├── backup-scheduler.sh # Automated backup scheduling
│       ├── healthcheck.sh      # Container health verification
│       ├── crash-handler.sh    # Crash event notification
│       ├── server-control.sh   # Internal server control
│       ├── world-manager.sh    # World file management
│       └── restore.sh          # Backup restoration
├── data/                       # Persistent data (bind-mounted volumes)
│   ├── worlds/                 # World files
│   ├── backups/                # Backup archives
│   ├── logs/                   # Server logs
│   └── config/                 # Runtime configuration
├── docs/                       # Documentation
├── scripts/
├── server.sh                   # Main CLI management script
├── install.sh                  # Quick install script (Steam Deck)
├── .env.example                # Configuration template
└── README.md                   # This file
```

### Building from Source

```bash
# Using server.sh (recommended)
./server.sh build               # Build with cache
./server.sh build --no-cache    # Fresh build without cache
./server.sh update 1453             # Rebuild with specific version (uses --no-cache)

# Using docker compose directly
sudo docker compose -f docker/docker-compose.yml --env-file .env build
sudo docker compose -f docker/docker-compose.yml --env-file .env build --no-cache
```



## Steam Deck Notes

### Installing Docker on Steam Deck

Steam Deck requires Docker to be installed manually. Run these commands in Konsole (Desktop Mode):

```bash
# 1. Disable read-only filesystem
sudo steamos-readonly disable

# 2. Initialize pacman keyring (first time only)
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman-key --populate holo

# 3. Refresh package database and install Docker
sudo pacman -Syy
sudo pacman -S docker docker-compose --noconfirm

# 4. Enable and start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# 5. Add your user to the docker group (avoids needing sudo for docker commands)
sudo usermod -aG docker $USER

# 6. Re-enable read-only filesystem (recommended)
sudo steamos-readonly enable

# 7. Log out and back in (or reboot) for group changes to take effect
```

After logging back in, verify Docker works:

```bash
docker --version
docker run hello-world
```


### Running in Desktop Mode

This server is designed to run in Steam Deck's Desktop Mode. You can:

1. Switch to Desktop Mode (hold power button → Switch to Desktop)
2. Open Konsole (terminal)
3. Navigate to the project and run the commands above

### Gaming While Hosting

The server can run in the background while you play Terraria (or other games). The Docker container is configured with resource limits to prevent impacting game performance:

| Setting | Value | Purpose |
|---------|-------|---------|
| Memory Limit | 1536 MB | Prevents server from consuming too much RAM |
| Memory Reserved | 768 MB | Guarantees minimum memory for server |
| Shutdown Grace | 45 seconds | Ensures world saves before stopping |

**Tips for best performance:**

- Start the server in Desktop Mode before launching your game
- Switch to Game Mode after server is running
- Monitor resource usage: `docker stats terraria-server --no-stream`
- For extended hosting, connect to power (server uses ~5-10W additional)
- Ensure adequate ventilation for thermal management

### After SteamOS Updates

SteamOS updates may remove packages installed via `pacman`. If Docker stops working after an update:

```bash
# Re-install Docker
sudo steamos-readonly disable
sudo pacman -S docker docker-compose --noconfirm
sudo systemctl enable docker
sudo systemctl start docker
sudo steamos-readonly enable
```

Your world data in `data/` is preserved and will work immediately after reinstalling.

## License

This project is provided for personal use. Terraria is a registered trademark of Re-Logic.

## Version

**Current version: 10.0.0** (CLI Management)

Terraria Server Version: **1.4.5.3** (1453) - can be updated via `./server.sh update`

### Changelog

| Version | Release | Description |
|---------|---------|-------------|
| **10.0.0** | Current | CLI-only management via `./server.sh`, host-based restore, backup scheduling |
| 9.0.0 | - | Pure HTML dashboard, authentication removed, simplified deployment |
| 8.0.0 | - | Testing & Polish phase complete, production-ready release |
| 7.0.0 | - | Complete documentation suite |
| 6.0.0 | - | Multi-stage Docker build, Makefile, health checks |
| 5.0.0 | - | Web frontend interface |
| 4.0.0 | - | REST API backend |
| 3.0.0 | - | World management and automated backups |
| 2.0.0 | - | Process management with Supervisor |
| 1.0.0 | - | Initial Docker infrastructure |

---

*Built for Steam Deck gaming enthusiasts* | [Setup Guide](docs/SETUP.md) | [Configuration](docs/CONFIGURATION.md) | [Troubleshooting](docs/TROUBLESHOOTING.md)
