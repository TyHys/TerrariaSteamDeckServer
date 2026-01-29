# Terraria Steam Deck Server - Configuration Guide

Complete reference for all configuration options in the Terraria Steam Deck Server.

## Table of Contents

- [Configuration File](#configuration-file)
- [Required Settings](#required-settings)
- [World Settings](#world-settings)
- [Server Settings](#server-settings)
- [Process Management](#process-management)
- [Backup Settings](#backup-settings)
- [Web Interface Settings](#web-interface-settings)
- [Advanced Settings](#advanced-settings)
- [Applying Changes](#applying-changes)
- [Web Interface Configuration](#web-interface-configuration)

---

## Configuration File

All configuration is done through the `.env` file in the project root.

### Creating the Configuration File

If you haven't already, create the configuration file:

```bash
make setup
```

Or manually:

```bash
cp .env.example .env
```

### Editing the Configuration

```bash
# Using nano
nano .env

# Using vim
vim .env

# Using VS Code (if installed)
code .env
```

---

## Required Settings

These settings MUST be configured before starting the server.

### API_PASSWORD

```bash
# API password for web interface (REQUIRED - minimum 8 characters)
API_PASSWORD=YourSecurePasswordHere
```

| Property | Value |
|----------|-------|
| Required | Yes |
| Minimum Length | 8 characters |
| Recommended | 16+ characters with mixed case, numbers, symbols |

This password is used to:
- Login to the web management interface
- Authenticate API requests
- Protect server configuration changes

**Security Note:** Choose a strong password. Anyone with this password has full control over your Terraria server.

---

## World Settings

Configure the world that will be loaded or created.

### WORLD_NAME

```bash
WORLD_NAME=world
```

The name of your world file (without the `.wld` extension).

| Property | Value |
|----------|-------|
| Default | `world` |
| Valid Characters | Letters, numbers, underscores |
| File Location | `data/worlds/<name>.wld` |

### WORLD_SIZE

```bash
WORLD_SIZE=2
```

Size of auto-created worlds.

| Value | Size | File Size (approx) | Description |
|-------|------|-------------------|-------------|
| 1 | Small | ~40 MB | 4200 x 1200 blocks |
| 2 | Medium | ~80 MB | 6400 x 1800 blocks |
| 3 | Large | ~160 MB | 8400 x 2400 blocks |

### DIFFICULTY

```bash
DIFFICULTY=0
```

Difficulty mode for auto-created worlds.

| Value | Difficulty | Description |
|-------|------------|-------------|
| 0 | Classic | Normal gameplay experience |
| 1 | Expert | Harder enemies, exclusive items |
| 2 | Master | Maximum challenge, exclusive items |
| 3 | Journey | Creative mode with adjustable settings |

### AUTOCREATE

```bash
AUTOCREATE=2
```

Whether to automatically create a world if none exists.

| Value | Behavior |
|-------|----------|
| 0 | Disabled - server won't start without existing world |
| 1 | Create Small world if missing |
| 2 | Create Medium world if missing |
| 3 | Create Large world if missing |

Set to `0` if you want to create worlds exclusively through the web interface.

### WORLD_SEED

```bash
WORLD_SEED=
```

Seed for world generation. Leave empty for random.

| Property | Value |
|----------|-------|
| Default | Empty (random) |
| Type | Text or numeric string |

Use a specific seed to generate identical world terrain. Useful for:
- Recreating a favorite world
- Sharing worlds with friends
- Challenge runs with known terrain

---

## Server Settings

Control how players connect and interact with the server.

### MAX_PLAYERS

```bash
MAX_PLAYERS=8
```

Maximum number of concurrent players.

| Property | Value |
|----------|-------|
| Default | 8 |
| Minimum | 1 |
| Maximum | 255 |
| Recommended | 8-16 for Steam Deck |

**Performance Note:** Higher player counts require more CPU and RAM. For Steam Deck, 8-16 players is recommended for smooth gameplay.

### SERVER_PORT

```bash
SERVER_PORT=7777
```

TCP port for Terraria game connections.

| Property | Value |
|----------|-------|
| Default | 7777 |
| Standard Terraria Port | 7777 |

Only change this if port 7777 is already in use. If changed:
- Update your firewall rules
- Update port forwarding on your router
- Players must use the new port to connect

### SERVER_PASSWORD

```bash
SERVER_PASSWORD=
```

Password required to join the game server.

| Property | Value |
|----------|-------|
| Default | Empty (no password) |
| Maximum Length | No official limit |

When set:
- Players must enter this password when connecting
- Protects your server from unwanted guests
- Different from API_PASSWORD (web interface)

### MOTD

```bash
MOTD=Welcome to the Terraria Server!
```

Message of the Day shown to players when they join.

| Property | Value |
|----------|-------|
| Default | `Welcome to the Terraria Server!` |
| Maximum Length | ~256 characters |

Supports basic text. Use it to:
- Welcome players
- Display server rules
- Announce events or updates

### SECURE

```bash
SECURE=1
```

Enable anti-cheat protection.

| Value | State | Description |
|-------|-------|-------------|
| 0 | Disabled | No cheat detection |
| 1 | Enabled | Kicks players using cheat clients |

**Recommendation:** Keep enabled (1) for public servers.

### LANGUAGE

```bash
LANGUAGE=en-US
```

Server language for in-game messages.

| Value | Language |
|-------|----------|
| en-US | English (US) |
| de-DE | German |
| it-IT | Italian |
| fr-FR | French |
| es-ES | Spanish |
| ru-RU | Russian |
| zh-CN | Chinese (Simplified) |
| pt-BR | Portuguese (Brazil) |
| pl-PL | Polish |

---

## Process Management

Control crash recovery behavior.

### RESTART_DELAY

```bash
RESTART_DELAY=5
```

Initial delay (seconds) before restarting after a crash.

| Property | Value |
|----------|-------|
| Default | 5 |
| Recommended | 5-10 |

### RESTART_DELAY_MAX

```bash
RESTART_DELAY_MAX=60
```

Maximum delay (seconds) between restart attempts.

| Property | Value |
|----------|-------|
| Default | 60 |
| Recommended | 60-120 |

Used when the server crashes repeatedly (exponential backoff).

### RESTART_DELAY_MULTIPLIER

```bash
RESTART_DELAY_MULTIPLIER=2
```

Multiplier for exponential backoff on repeated crashes.

| Property | Value |
|----------|-------|
| Default | 2 |
| Recommended | 2 |

Example with defaults:
1. First crash: Wait 5 seconds
2. Second crash: Wait 10 seconds
3. Third crash: Wait 20 seconds
4. Fourth crash: Wait 40 seconds
5. Fifth+ crash: Wait 60 seconds (max)

---

## Backup Settings

Configure automatic world backup behavior.

### BACKUP_ENABLED

```bash
BACKUP_ENABLED=true
```

Enable or disable automatic backups.

| Value | State |
|-------|-------|
| true | Backups run on schedule |
| false | No automatic backups |

**Recommendation:** Keep enabled. Backups protect against corruption, crashes, or accidental world damage.

### BACKUP_INTERVAL

```bash
BACKUP_INTERVAL=30
```

Minutes between automatic backups.

| Property | Value |
|----------|-------|
| Default | 30 |
| Minimum | 5 |
| Recommended | 15-60 |

Lower values = more protection, more disk usage.
Higher values = less disk usage, potential data loss.

### BACKUP_RETENTION

```bash
BACKUP_RETENTION=48
```

Number of backups to keep per world.

| Property | Value |
|----------|-------|
| Default | 48 |
| Recommended | 24-96 |

With 30-minute intervals:
- 48 backups = ~24 hours of history
- 96 backups = ~48 hours of history
- 288 backups = ~1 week of history

Older backups are automatically deleted.

### BACKUP_ON_STARTUP

```bash
BACKUP_ON_STARTUP=false
```

Create a backup when the container starts.

| Value | Behavior |
|-------|----------|
| true | Backup immediately on startup |
| false | Wait for first scheduled interval |

Useful if you want a backup before any gameplay after restart.

### BACKUP_COMPRESSION

```bash
BACKUP_COMPRESSION=gzip
```

Compression method for backups.

| Value | Description | Size | Speed |
|-------|-------------|------|-------|
| gzip | Compressed archive | ~60% smaller | Slower |
| none | Uncompressed tar | Full size | Faster |

**Recommendation:** Use `gzip` unless you have slow CPU or need faster backups.

---

## Web Interface Settings

Configure the management web interface.

### API_PORT

```bash
API_PORT=8080
```

HTTP port for the web interface.

| Property | Value |
|----------|-------|
| Default | 8080 |
| Standard Alternative | 80 (requires root) |

Access the web interface at `http://localhost:<port>`

### API_USERNAME

```bash
API_USERNAME=admin
```

Username for web interface login.

| Property | Value |
|----------|-------|
| Default | admin |

### API_PASSWORD

See [Required Settings](#api_password) above.

### API_TOKEN_EXPIRY

```bash
API_TOKEN_EXPIRY=86400
```

How long (seconds) until login session expires.

| Property | Value |
|----------|-------|
| Default | 86400 (24 hours) |
| Minimum | 3600 (1 hour) |
| Maximum | 604800 (7 days) |

After expiry, you must log in again.

### API_DEBUG

```bash
API_DEBUG=false
```

Enable debug mode for the API.

| Value | State |
|-------|-------|
| false | Production mode (recommended) |
| true | Debug mode (development only) |

**Warning:** Never enable in production. Debug mode exposes detailed error messages.

### CORS_ORIGINS

```bash
CORS_ORIGINS=*
```

Allowed origins for cross-origin requests.

| Value | Behavior |
|-------|----------|
| * | Allow all origins |
| URL | Allow specific origin |
| URLs | Comma-separated list of allowed origins |

Example for specific origins:

```bash
CORS_ORIGINS=http://localhost:3000,https://mysite.com
```

Only change if you're accessing the API from a different domain.

---

## Advanced Settings

These settings are in `server/config/serverconfig.txt` and typically don't need modification.

### priority

```bash
priority=1
```

Server process priority (0=realtime, 5=idle).

| Value | Priority |
|-------|----------|
| 0 | Realtime (highest) |
| 1 | High (default) |
| 2 | Above Normal |
| 3 | Normal |
| 4 | Below Normal |
| 5 | Idle (lowest) |

### npcstream

```bash
npcstream=60
```

NPC spawn reduction when players are away. Default (60) is recommended.

### Journey Mode Permissions

For Journey mode worlds, control player power access:

```bash
journeypermission_time_setfrozen=2
journeypermission_godmode=2
journeypermission_setdifficulty=2
# ... and more
```

| Value | Permission |
|-------|------------|
| 0 | Locked (host only) |
| 1 | Can change (per-player) |
| 2 | Unlocked (all players) |

---

## Applying Changes

After modifying `.env`:

### Restart Required

Most settings require a restart:

```bash
make restart
```

### No Restart Required

These can be changed in the web interface without restart:
- Server password (in-game)
- MOTD
- Max players

### Rebuild Required

If you modify the Dockerfile:

```bash
make build
make restart
```

---

## Web Interface Configuration

Some settings can also be changed through the web interface.

### Accessing Configuration

1. Open `http://localhost:8080`
2. Log in with your credentials
3. Click **Configuration** in the sidebar

### Available Settings

The web interface allows changing:

| Section | Settings |
|---------|----------|
| Server | Max Players, Password, MOTD, Anti-cheat |
| World | (Create new worlds with size/difficulty) |
| Backup | Enable/Disable, Interval, Retention |

**Note:** Changes through the web interface update the running server but may not persist to `.env`. For permanent changes, edit `.env` directly.

---

## Example Configurations

### Small Private Server

```bash
WORLD_NAME=FriendsWorld
WORLD_SIZE=1
DIFFICULTY=0
MAX_PLAYERS=4
SERVER_PASSWORD=OurSecretPassword
MOTD=Welcome friends! No griefing please.
BACKUP_INTERVAL=60
BACKUP_RETENTION=24
```

### Large Public Server

```bash
WORLD_NAME=PublicAdventure
WORLD_SIZE=3
DIFFICULTY=1
MAX_PLAYERS=16
SERVER_PASSWORD=
MOTD=Welcome! Server rules: Be nice, have fun!
SECURE=1
BACKUP_INTERVAL=15
BACKUP_RETENTION=96
```

### Expert Challenge Server

```bash
WORLD_NAME=ExpertChallenge
WORLD_SIZE=2
DIFFICULTY=2
MAX_PLAYERS=8
SERVER_PASSWORD=ProPlayersOnly
WORLD_SEED=challenge2024
MOTD=Master difficulty - Good luck!
```

---

*For setup instructions, see [SETUP.md](SETUP.md)*
*For networking configuration, see [NETWORKING.md](NETWORKING.md)*
