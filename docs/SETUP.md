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
| Ports | 7777 and 8080 available on localhost |

---

## Installing Docker on Steam Deck

Steam Deck uses an immutable filesystem, so Docker must be installed using a specific method.

### Option 1: Using Distrobox (Recommended)

Distrobox is available on Steam Deck without modifying the read-only filesystem.

1. **Open Konsole** (the terminal application in Desktop Mode)

2. **Install Docker in a container:**

```bash
distrobox create --name docker-box --image docker.io/library/ubuntu:22.04
distrobox enter docker-box
sudo apt update && sudo apt install -y docker.io docker-compose
```

### Option 2: Enabling Developer Mode

For native Docker installation:

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
```

4. **Install Docker:**

```bash
sudo pacman -S docker docker-compose
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
├── web/
│   ├── backend/
│   └── frontend/
├── data/           (created after setup)
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

This creates:
- `.env` file from `.env.example`
- `data/worlds/` directory
- `data/backups/` directory
- `data/logs/` directory
- `data/config/` directory

### Step 2: Configure Required Settings

Edit the `.env` file:

```bash
nano .env
# Or use your preferred editor
```

**Required: Set the API password**

```bash
# REQUIRED: Set a secure password (minimum 8 characters)
API_PASSWORD=YourSecurePassword123
```

### Step 3: Customize World Settings (Optional)

```bash
# World name
WORLD_NAME=MyWorld

# World size: 1=Small, 2=Medium, 3=Large
WORLD_SIZE=2

# Difficulty: 0=Classic, 1=Expert, 2=Master, 3=Journey
DIFFICULTY=0
```

### Step 4: Customize Server Settings (Optional)

```bash
# Maximum players (1-255)
MAX_PLAYERS=8

# Server password (leave empty for no password)
SERVER_PASSWORD=

# Message of the day
MOTD=Welcome to my Terraria server!
```

### Step 5: Save and Close

In nano: Press `Ctrl+O` to save, then `Ctrl+X` to exit.

---

## Starting the Server

### Build the Docker Image

First-time or after updates:

```bash
make build
```

This process:
- Downloads the Debian base image
- Downloads Terraria server binary from terraria.org
- Installs Python and web interface dependencies
- Creates the final optimized container image

Build time: approximately 5-10 minutes depending on network speed.

### Start the Server

```bash
make start
```

The server starts in detached mode (runs in background).

### View Startup Logs

To watch the server start up:

```bash
make logs
```

Press `Ctrl+C` to stop following logs (server continues running).

---

## Verifying Installation

### Check Server Status

```bash
make status
```

You should see:
- Supervisor: RUNNING
- terraria-server: RUNNING (or STARTING)
- web-api: RUNNING
- backup-scheduler: RUNNING

### Run Health Check

```bash
make health
```

All services should report as healthy.

### Access Web Interface

Open a web browser and navigate to:

```
http://localhost:8080
```

Login with:
- **Username:** admin (or your configured API_USERNAME)
- **Password:** Your configured API_PASSWORD

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

1. Start the server in Desktop Mode using `make start`
2. Switch to Game Mode
3. The server continues running in the background
4. Access the web interface from another device

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
make restart
```

### Update Server Software

When a new version is released:

```bash
# Stop the server
make stop

# Pull latest changes (if using git)
git pull

# Rebuild the image
make build

# Start with new image
make start
```

### Check Current Version

```bash
make status
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
