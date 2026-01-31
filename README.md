# Terraria Steam Deck Server

A Docker-containerized Terraria dedicated server optimized for Steam Deck devices. Features automated backups, robust process management, and easy CLI-based management.

## Features

- **Terraria Dedicated Server** - Official Terraria server binary (v1.4.5.3)
- **CLI Management** - Simple command-line management via `./server.sh`
- **Automated Backups** - Scheduled backups with configurable retention
- **Process Management** - Automatic crash recovery with Supervisor
- **Easy Configuration** - Environment variables for all settings
- **Steam Deck Optimized** - Resource limits suitable for Steam Deck hardware

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
./server.sh logs      # View server logs
./server.sh backup    # Create a backup
./server.sh backups   # List all backups
./server.sh restore <backup-file>  # Restore from backup
./server.sh save      # Save the world
./server.sh say "message"  # Broadcast to players
```

### Full Command Reference

| Command | Description |
|---------|-------------|
| `./server.sh start` | Start the server container |
| `./server.sh stop` | Stop the server container |
| `./server.sh restart` | Restart the server container |
| `./server.sh status` | Show server status, worlds, and info |
| `./server.sh save` | Save the world (crash protection) |
| `./server.sh say <message>` | Broadcast a message to all players |
| `./server.sh command <cmd>` | Send any Terraria server command |
| `./server.sh backup [world]` | Create a backup (all or specific world) |
| `./server.sh restore <file>` | Restore from a backup file |
| `./server.sh backups` | List all available backups |
| `./server.sh logs [lines]` | Show container logs (default: 100) |
| `./server.sh livelogs` | Follow container logs in real-time |
| `./server.sh console` | Attach to Terraria server console |
| `./server.sh shell` | Open a bash shell in the container |
| `./server.sh exec <cmd>` | Execute a command in the container |
| `./server.sh update` | Rebuild the container image |
| `./server.sh help` | Show all available commands |

### Make Commands (if installed)

If you have `make` installed, you can use these shortcuts:

| Command | Description |
|---------|-------------|
| `make setup` | First-time setup (creates .env and directories) |
| `make build` | Build the Docker image |
| `make start` | Start the server (detached) |
| `make stop` | Stop the server |
| `make restart` | Restart the server |
| `make logs` | Follow server logs |
| `make status` | Show server and service status |
| `make health` | Run health check |
| `make shell` | Open shell inside container |
| `make backup` | Create manual backup |
| `make worlds` | List worlds |
| `make backups` | List backups |
| `make test` | Run integration tests |
| `make clean` | Stop and remove container |

## Configuration

All configuration is done via environment variables in the `.env` file.

### Game Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `WORLD_NAME` | `world` | World name |
| `WORLD_SIZE` | `2` | 1=Small, 2=Medium, 3=Large |
| `DIFFICULTY` | `0` | 0=Normal, 1=Expert, 2=Master, 3=Journey |
| `MAX_PLAYERS` | `8` | Maximum concurrent players |
| `SERVER_PASSWORD` | *(empty)* | Server password |
| `MOTD` | `Welcome...` | Message of the day |

### Backup Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_ENABLED` | `true` | Enable automatic backups |
| `BACKUP_INTERVAL` | `30` | Minutes between backups |
| `BACKUP_RETENTION` | `48` | Number of backups to keep |

See `.env.example` for all available options.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Container                      │
│  ┌─────────────────┐  ┌─────────────────────────────┐   │
│  │ Terraria Server │  │      Backup Scheduler       │   │
│  │   (Port 7777)   │  │    (Automated Backups)      │   │
│  └─────────────────┘  └─────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐    │
│  │              Supervisor (Process Mgmt)          │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌─────────────────────────────┐
│  Volume: Worlds │    │  Volume: Backups & Logs     │
└─────────────────┘    └─────────────────────────────┘
```

## Data Persistence

All data is stored in the `data/` directory:

- `data/worlds/` - World files (.wld)
- `data/backups/` - Compressed backup archives
- `data/logs/` - Server and application logs
- `data/config/` - Runtime configuration

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

## Troubleshooting

Quick fixes for common issues. For detailed troubleshooting, see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

### Server won't start

1. Check logs: `./server.sh logs`
2. Verify configuration: `./server.sh status`
3. Check container health: `docker exec terraria-server /terraria/scripts/healthcheck.sh`

### Can't connect to game server

1. Check if server is running: `./server.sh status`
2. Verify port 7777 is not blocked by firewall
3. For remote players, ensure port 7777 is forwarded

## Development

### Project Structure

```
TerrariaSteamDeckServer/
├── docker/
│   ├── Dockerfile          # Multi-stage build
│   └── docker-compose.yml  # Container orchestration
├── server/
│   ├── config/             # Server configurations
│   └── scripts/            # Management scripts
├── data/                   # Persistent data (volumes)
├── server.sh               # CLI management script
├── install.sh              # Quick install script (Steam Deck)
├── Makefile                # Build/run commands
└── .env.example            # Configuration template
```

### Building from source

```bash
docker compose -f docker/docker-compose.yml build --no-cache
```

### Running tests

```bash
./tests/validate.sh
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

> **Warning:** Packages installed via `pacman` may be removed during SteamOS updates. You may need to reinstall Docker after major updates. Your data in `data/` will be preserved.

### Installing Make (Optional)

If you prefer using `make` commands, you can install it on Steam Deck:

```bash
# Disable read-only filesystem
sudo steamos-readonly disable

# Install make
sudo pacman -S make --noconfirm

# Re-enable read-only filesystem (recommended)
sudo steamos-readonly enable
```

> **Warning:** Packages installed via `pacman` may be removed during SteamOS updates. You may need to reinstall after major updates.

### Running in Desktop Mode

This server is designed to run in Steam Deck's Desktop Mode. You can:

1. Switch to Desktop Mode (hold power button → Switch to Desktop)
2. Open Konsole (terminal)
3. Navigate to the project and run the commands above

### Gaming While Hosting

The server can run in the background while you play Terraria (or other games). The Docker container is configured with resource limits to prevent impacting game performance. For best results:

- Start the server before launching your game
- Monitor resource usage with `docker stats` if you experience issues

## License

This project is provided for personal use. Terraria is a registered trademark of Re-Logic.

## Version

Current version: **10.0.0** (CLI Management)

### Changelog

- **10.0.0** - Removed web interface, CLI-only management via ./server.sh
- **9.0.0** - Pure HTML dashboard, authentication removed, simplified deployment
- **8.0.0** - Testing & Polish phase complete, production-ready release
- **7.0.0** - Complete documentation suite
- **6.0.0** - Multi-stage Docker build, Makefile, health checks
- **5.0.0** - Web frontend interface
- **4.0.0** - REST API backend
- **3.0.0** - World management and automated backups
- **2.0.0** - Process management with Supervisor
- **1.0.0** - Initial Docker infrastructure

---

*Built for Steam Deck gaming enthusiasts*
