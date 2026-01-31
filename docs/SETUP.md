# Terraria Steam Deck Server - Setup Guide

This guide provides detailed instructions for installing and configuring the Terraria Steam Deck Server.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installing Docker on Steam Deck](#installing-docker-on-steam-deck)
- [Downloading the Server](#downloading-the-server)
- [First-Time Configuration](#first-time-configuration)
- [Starting the Server](#starting-the-server)
- [Verifying Installation](#verifying-installation)
- [Updating the Server](#updating-the-server)
- [Uninstalling](#uninstalling)

---

## Prerequisites

Before installing, ensure you have:

| Requirement | Description |
|-------------|-------------|
| Steam Deck | Running SteamOS 3.0+ in Desktop Mode |
| Storage | At least 500MB free (more for larger worlds) |
| Network | Internet connection for Docker image download |
| Ports | Port 7777 available on localhost |

---

## Installing Docker on Steam Deck

Steam Deck uses an immutable filesystem, so Docker must be installed using a specific method.

### Option 1: Using the Install Script (Recommended)

The install script will automatically detect and install Docker:

```bash
./install.sh
```

### Option 2: Manual Installation

1. **Set a sudo password** (if not already set):

```bash
passwd
```

2. **Disable read-only filesystem temporarily:**

```bash
sudo steamos-readonly disable
```

3. **Initialize pacman keys:**

```bash
sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman-key --populate holo
```

4. **Install Docker:**

```bash
sudo pacman -S docker docker-compose --noconfirm
```

5. **Enable and start Docker:**

```bash
sudo systemctl enable docker
sudo systemctl start docker
```

6. **Add yourself to the docker group:**

```bash
sudo usermod -aG docker deck
```

7. **Re-enable read-only filesystem:**

```bash
sudo steamos-readonly enable
```

8. **Log out and back in** for group changes to take effect.

### Verifying Docker Installation

Run:

```bash
docker --version
docker-compose --version
docker run hello-world
```

If all commands succeed, Docker is properly installed.

---

## Downloading the Server

### Option A: Clone from Git (if using version control)

```bash
cd ~/code_projects
git clone <repository-url> TerrariaSteamDeckServer
cd TerrariaSteamDeckServer
```

### Option B: Download and Extract

```bash
cd ~/code_projects
# Download the release archive
unzip terraria-steam-deck-server.zip
cd TerrariaSteamDeckServer
```

### Directory Structure

After downloading, you should have:

```
TerrariaSteamDeckServer/
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── server/
│   ├── config/
│   └── scripts/
├── data/           (created after setup)
├── server.sh       # Main management script
├── install.sh
├── Makefile
├── .env.example
└── README.md
```

---

## First-Time Configuration

### Step 1: Run Setup

The setup command creates necessary directories and configuration files:

```bash
make setup
```

Or use the install script:

```bash
./install.sh
```

This creates:
- `.env` file from `.env.example`
- `data/worlds/` directory
- `data/backups/` directory
- `data/logs/` directory
- `data/config/` directory

### Step 2: Customize Settings (Optional)

Edit the `.env` file to customize your server:

```bash
nano .env
```

Common settings to customize:

```bash
# World name
WORLD_NAME=MyWorld

# World size: 1=Small, 2=Medium, 3=Large
WORLD_SIZE=2

# Difficulty: 0=Classic, 1=Expert, 2=Master, 3=Journey
DIFFICULTY=0

# Maximum players
MAX_PLAYERS=8

# Server password (leave empty for no password)
SERVER_PASSWORD=
```

### Step 3: Save and Close

In nano: Press `Ctrl+O` to save, then `Ctrl+X` to exit.

---

## Starting the Server

### Using the Management Script (Recommended)

```bash
./server.sh start
```

### Using Make Commands

```bash
# Build the Docker image (first time or after updates)
make build

# Start the server
make start
```

### Using Docker Compose Directly

```bash
# Build the Docker image
docker compose -f docker/docker-compose.yml build

# Start the server
docker compose -f docker/docker-compose.yml up -d
```

### View Startup Logs

```bash
./server.sh logs
# or
make logs
```

Press `Ctrl+C` to stop following logs (server continues running).

---

## Verifying Installation

### Check Server Status

```bash
./server.sh status
```

You should see:
- Container: Running
- Terraria server: Running
- Backup scheduler: Running

### Run Health Check

```bash
make health
```

All services should report as healthy.

### Test Game Connection

1. Open Terraria on any device on the same network
2. Go to Multiplayer → Join via IP
3. Enter: `<steam-deck-ip>:7777`
4. If you set a server password, enter it when prompted

To find your Steam Deck's IP address:

```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
```

---

## Steam Deck-Specific Considerations

### Running in Game Mode

The server can run while you're in Game Mode:

1. Start the server in Desktop Mode using `./server.sh start`
2. Switch to Game Mode
3. The server continues running in the background

### Resource Usage

The container is configured with Steam Deck-friendly limits:

| Resource | Limit | Reserved |
|----------|-------|----------|
| Memory | 1536 MB | 768 MB |
| CPU | Unlimited | - |

These limits ensure the server doesn't impact game performance if you're also playing on the Steam Deck.

### Battery Considerations

When running on battery:
- Server uses approximately 5-10W additional power
- Consider connecting to power for extended hosting sessions
- Use Desktop Mode power settings to prevent sleep

### Heat Management

The Terraria server is CPU-efficient, but for extended sessions:
- Ensure the Steam Deck has adequate ventilation
- Consider using a stand for airflow
- The fan will run as needed automatically

---

## Updating the Server

### Update Configuration Only

Edit `.env` then restart:

```bash
nano .env
./server.sh restart
```

### Update Server Software

When a new version is released:

```bash
# Stop the server
./server.sh stop

# Pull latest changes (if using git)
git pull

# Rebuild the image
./server.sh update

# Start with new image
./server.sh start
```

### Check Current Version

```bash
./server.sh status
```

Version is displayed in the status output.

---

## Uninstalling

### Stop and Remove Container

```bash
make clean
```

### Remove All Data (Destructive!)

```bash
make clean-all
```

This removes:
- Docker container
- Docker volumes
- Docker image
- All worlds, backups, and logs

### Manual Cleanup

To remove just the project folder:

```bash
cd ~/code_projects
rm -rf TerrariaSteamDeckServer
```

---

## Next Steps

After installation:

1. **[Configure the server](CONFIGURATION.md)** - Customize all settings
2. **[Set up networking](NETWORKING.md)** - Allow external connections
3. **[Learn troubleshooting](TROUBLESHOOTING.md)** - Handle common issues

---

*For more information, see the main [README.md](../README.md)*
