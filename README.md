# Terraria Steam Deck Server

A Docker-containerized Terraria dedicated server optimized for Steam Deck devices. Features a modern web management interface, automated backups, and robust process management.

## Features

- **Terraria Dedicated Server** - Official Terraria server binary (v1449)
- **Web Management Interface** - Beautiful dark-themed UI accessible from any browser
- **Automated Backups** - Scheduled backups with configurable retention
- **Process Management** - Automatic crash recovery with Supervisor
- **Easy Configuration** - Environment variables for all settings
- **Steam Deck Optimized** - Resource limits suitable for Steam Deck hardware

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Ports 7777 (game) and 8080 (web UI) available

### Installation

1. **Clone or download this repository**

```bash
cd ~/code_projects
git clone <repository-url> TerrariaSteamDeckServer
cd TerrariaSteamDeckServer
```

2. **Run setup**

```bash
make setup
```

3. **Configure your password**

Edit the `.env` file and set a secure password:

```bash
# Required: Set this to a secure password
API_PASSWORD=your_secure_password_here
```

4. **Start the server**

```bash
make start
```

5. **Access the web interface**

Open your browser to: `http://localhost:8080`

Login with:
- Username: `admin` (or your configured username)
- Password: Your configured `API_PASSWORD`

### Connecting to the Game Server

Players can connect to your server at:
- **Local**: `localhost:7777` or `your-ip:7777`
- **Remote**: Requires port forwarding on your router (port 7777)

## Commands

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

### Web API Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `API_USERNAME` | `admin` | Web interface username |
| `API_PASSWORD` | *(required)* | Web interface password |
| `API_PORT` | `8080` | Web interface port |

See `.env.example` for all available options.

## Web Interface

The web interface provides:

- **Dashboard** - Server status, controls, quick info
- **Worlds** - Create, copy, delete worlds
- **Backups** - Manual backups, restore, cleanup
- **Configuration** - All server settings
- **Logs** - Real-time log viewer

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Container                      │
│  ┌─────────────────┐  ┌─────────────────────────────┐   │
│  │ Terraria Server │  │ Web Interface (Flask API)   │   │
│  │   (Port 7777)   │  │        (Port 8080)          │   │
│  └─────────────────┘  └─────────────────────────────┘   │
│  ┌─────────────────┐  ┌─────────────────────────────┐   │
│  │ Supervisor      │  │      Backup Scheduler       │   │
│  │ (Process Mgmt)  │  │    (Automated Backups)      │   │
│  └─────────────────┘  └─────────────────────────────┘   │
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
2. Optionally forward port **8080/TCP** for remote web management (not recommended for security)

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

1. Check logs: `make logs`
2. Verify configuration: `make status`
3. Ensure API_PASSWORD is set in `.env`

### Can't connect to game server

1. Check if server is running: `make health`
2. Verify port 7777 is not blocked by firewall
3. For remote players, ensure port 7777 is forwarded

### Web interface not accessible

1. Check if API is running: `curl http://localhost:8080/api/status`
2. Verify port 8080 is not in use by another application

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
├── web/
│   ├── backend/            # Flask REST API
│   └── frontend/           # Web UI (HTML/CSS/JS)
├── data/                   # Persistent data (volumes)
├── Makefile                # Build/run commands
└── .env.example            # Configuration template
```

### Building from source

```bash
make build-no-cache
```

### Running tests

```bash
make test
```

## License

This project is provided for personal use. Terraria is a registered trademark of Re-Logic.

## Version

Current version: **8.0.0** (Production Ready)

### Changelog

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
