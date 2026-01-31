# Terraria Steam Deck Server - Troubleshooting Guide

This guide helps you diagnose and resolve common issues with the Terraria Steam Deck Server.

## Table of Contents

- [Diagnostic Commands](#diagnostic-commands)
- [Server Issues](#server-issues)
- [Connection Issues](#connection-issues)
- [Backup and Restore Issues](#backup-and-restore-issues)
- [World Issues](#world-issues)
- [Docker Issues](#docker-issues)
- [Steam Deck-Specific Issues](#steam-deck-specific-issues)
- [Log Locations](#log-locations)
- [Getting Help](#getting-help)

---

## Diagnostic Commands

Use these commands to gather information about your server:

### Quick Health Check

```bash
make health
```

Shows the status of all services.

### Detailed Status

```bash
./server.sh status
```

Shows container status, service states, and system information.

### View Recent Logs

```bash
# All logs
./server.sh logs 50

# Follow logs in real-time
./server.sh livelogs
```

### Check Running Processes

```bash
docker exec terraria-server ps aux
```

### Check Disk Space

```bash
df -h
docker exec terraria-server df -h /terraria
```

### Check Memory Usage

```bash
docker stats terraria-server --no-stream
```

---

## Server Issues

### Server Won't Start

**Symptoms:**
- `./server.sh start` completes but server isn't running
- Health check shows services as not running

**Solutions:**

1. **Check for configuration errors:**
   ```bash
   ./server.sh status
   docker logs terraria-server 2>&1 | tail -50
   ```

2. **Check for port conflicts:**
   ```bash
   ss -tlnp | grep 7777
   ```
   If port is in use, stop the conflicting service or change port in `.env`.

3. **Rebuild the container:**
   ```bash
   ./server.sh clean
   ./server.sh build
   ./server.sh start
   ```

### Server Crashes Repeatedly

**Symptoms:**
- Server starts then stops
- Crash messages in logs

**Solutions:**

1. **Check crash logs:**
   ```bash
   docker exec terraria-server cat /terraria/logs/crashes.log
   ```

2. **Check Terraria server errors:**
   ```bash
   docker exec terraria-server tail -100 /terraria/logs/terraria-stderr.log
   ```

3. **Check for corrupted world:**
   - See [World Issues](#world-issues) below

4. **Check system resources:**
   ```bash
   docker stats terraria-server --no-stream
   ```
   If memory is at limit, increase in docker-compose.yml.

5. **Increase restart delay:**
   Edit `.env`:
   ```bash
   RESTART_DELAY=10
   RESTART_DELAY_MAX=120
   ```

### Server Is Slow/Laggy

**Symptoms:**
- Players experience lag
- Commands take long to respond

**Solutions:**

1. **Reduce max players:**
   Edit `.env`:
   ```bash
   MAX_PLAYERS=8
   ```

2. **Check CPU usage:**
   ```bash
   docker stats terraria-server
   ```

3. **Use a smaller world:**
   Large worlds require more resources.

4. **Close other applications:**
   In Desktop Mode, close browsers and other programs.

5. **Ensure adequate cooling:**
   Steam Deck may throttle if overheating.

---

## Connection Issues

### Players Can't Connect (Local)

**Symptoms:**
- Connection timeout on local network
- "Connection refused" error

**Solutions:**

1. **Verify server is running:**
   ```bash
   ./server.sh status
   ```

2. **Check the correct IP:**
   ```bash
   ip addr show | grep "inet " | grep -v 127.0.0.1
   ```

3. **Test port locally:**
   ```bash
   nc -zv localhost 7777
   ```
   If this fails, the server isn't listening.

4. **Check Docker port mapping:**
   ```bash
   docker port terraria-server
   ```
   Should show `7777/tcp -> 0.0.0.0:7777`.

5. **Check firewall:**
   ```bash
   sudo iptables -L -n | grep 7777
   ```

### Players Can't Connect (Remote)

**Symptoms:**
- Local players can connect
- Remote players cannot

**Solutions:**

1. **Verify port forwarding:**
   - Check router configuration
   - Use online port checker (canyouseeme.org)

2. **Confirm public IP:**
   ```bash
   curl -s ifconfig.me
   ```

3. **Test from outside your network:**
   - Use mobile data (not Wi-Fi)
   - Ask a friend to test

4. **Check for ISP restrictions:**
   - Some ISPs block gaming ports
   - Try a different port (e.g., 17777)

5. **Check for CGNAT:**
   - If public IP starts with 100.64.x.x to 100.127.x.x, you're behind CGNAT
   - Contact ISP or use a VPN

### Password Not Working

**Symptoms:**
- Correct password rejected
- Can't join server

**Solutions:**

1. **Verify password in configuration:**
   ```bash
   grep SERVER_PASSWORD .env
   ```

2. **Check for special characters:**
   - Avoid quotes and backslashes in passwords
   - Use simple alphanumeric passwords

3. **Restart after password change:**
   ```bash
   ./server.sh restart
   ```

---

## Backup and Restore Issues

### Backups Not Running

**Symptoms:**
- No new backups appearing
- Backup scheduler not working

**Solutions:**

1. **Verify backups are enabled:**
   ```bash
   grep BACKUP_ENABLED .env
   ```

2. **Check backup scheduler status:**
   ```bash
   docker exec terraria-server supervisorctl status backup-scheduler
   ```

3. **Check backup scheduler logs:**
   ```bash
   docker exec terraria-server tail -50 /terraria/logs/backup-scheduler-stdout.log
   ```

4. **Run manual backup:**
   ```bash
   ./server.sh backup
   ```

5. **Check disk space:**
   ```bash
   df -h
   ```

### Restore Fails

**Symptoms:**
- Restore command errors
- World not restored

**Solutions:**

1. **Use the server.sh restore command:**
   ```bash
   ./server.sh restore <backup-file>
   ```
   This will handle stopping/starting the server automatically.

2. **Verify backup file exists:**
   ```bash
   ./server.sh backups
   ```

3. **Check backup integrity:**
   ```bash
   tar -tzf data/backups/<backup-file> | head
   ```

4. **Check permissions:**
   ```bash
   ls -la data/backups/
   ```

5. **Try a different backup:**
   - The backup file may be corrupted
   - Try an older backup

### Backups Taking Too Much Space

**Symptoms:**
- Disk filling up
- Many old backups

**Solutions:**

1. **Reduce retention:**
   Edit `.env`:
   ```bash
   BACKUP_RETENTION=24
   ```

2. **Run cleanup:**
   ```bash
   docker exec terraria-server /terraria/scripts/backup.sh cleanup
   ```

3. **Increase backup interval:**
   ```bash
   BACKUP_INTERVAL=60
   ```

---

## World Issues

### World Won't Load

**Symptoms:**
- Server starts but world doesn't load
- "World file not found" errors

**Solutions:**

1. **Check world file exists:**
   ```bash
   ls -la data/worlds/
   ```

2. **Verify WORLD_NAME setting:**
   ```bash
   grep WORLD_NAME .env
   ```
   Ensure it matches the file name (without .wld).

3. **Check file permissions:**
   ```bash
   docker exec terraria-server ls -la /terraria/worlds/
   ```

4. **Let server auto-create:**
   Edit `.env`:
   ```bash
   AUTOCREATE=2
   ```

### Corrupted World

**Symptoms:**
- Server crashes when loading world
- "World is corrupt" message

**Solutions:**

1. **Restore from backup:**
   ```bash
   ./server.sh backups
   # Find a good backup
   ./server.sh restore <backup-file>
   ```

2. **Try the .wld.bak file:**
   Terraria keeps a backup:
   ```bash
   cp data/worlds/MyWorld.wld.bak data/worlds/MyWorld.wld
   ```

3. **Create a new world:**
   ```bash
   docker exec terraria-server /terraria/scripts/world-manager.sh create
   ```

### World Not Saving

**Symptoms:**
- Progress lost after restart
- World file not updating

**Solutions:**

1. **Check volume mounts:**
   ```bash
   docker inspect terraria-server | grep Mounts -A 20
   ```

2. **Verify data directory exists:**
   ```bash
   ls -la data/worlds/
   ```

3. **Use the save command:**
   ```bash
   ./server.sh save
   ```

---

## Docker Issues

### Container Won't Start

**Symptoms:**
- `./server.sh start` fails
- Container exits immediately

**Solutions:**

1. **Check Docker is running:**
   ```bash
   docker info
   ```

2. **Check container logs:**
   ```bash
   docker logs terraria-server
   ```

3. **Verify image exists:**
   ```bash
   docker images | grep terraria
   ```
   If missing, run `./server.sh build`.

4. **Check docker-compose syntax:**
   ```bash
   docker-compose -f docker/docker-compose.yml config
   ```

### Build Fails

**Symptoms:**
- `./server.sh build` errors
- Image not created

**Solutions:**

1. **Check internet connection:**
   ```bash
   ping google.com
   ```

2. **Clear Docker cache:**
   ```bash
   ./server.sh build --no-cache
   ```

3. **Check disk space:**
   ```bash
   df -h
   docker system df
   ```

4. **Clean up Docker:**
   ```bash
   docker system prune -a
   ```

### Out of Disk Space

**Symptoms:**
- "No space left on device" errors
- Builds fail

**Solutions:**

1. **Check disk usage:**
   ```bash
   df -h
   ```

2. **Clean Docker resources:**
   ```bash
   docker system prune -a
   ```

3. **Remove old backups:**
   ```bash
   docker exec terraria-server /terraria/scripts/backup.sh cleanup
   ```

4. **Check log sizes:**
   ```bash
   du -sh data/logs/*
   ```

---

## Steam Deck-Specific Issues

### Server Stops in Game Mode

**Symptoms:**
- Server stops when switching to Game Mode
- Container killed

**Solutions:**

1. **Start server before switching modes:**
   ```bash
   ./server.sh start
   ```
   The container should persist.

2. **Check resource limits:**
   Steam Deck may kill background processes.

3. **Disable aggressive power management:**
   In Desktop Mode, check power settings.

### Performance Issues in Game Mode

**Symptoms:**
- Lag while playing games
- Server affects gameplay

**Solutions:**

1. **Reduce server resources:**
   Edit docker-compose.yml:
   ```yaml
   deploy:
     resources:
       limits:
         memory: 1024M
       reservations:
         memory: 512M
   ```

2. **Limit player count:**
   ```bash
   MAX_PLAYERS=4
   ```

3. **Host from Desktop Mode only:**
   Switch to Desktop Mode when hosting.

### Container Not Found After Reboot

**Symptoms:**
- Server gone after restart
- "No such container" error

**Solutions:**

1. **Container doesn't auto-start:**
   You need to manually start:
   ```bash
   ./server.sh start
   ```

2. **Create a startup script:**
   Add to Desktop Mode autostart.

3. **Enable restart policy:**
   Already configured in docker-compose.yml (`restart: unless-stopped`).

---

## Log Locations

### Inside Container

| Log File | Contents |
|----------|----------|
| `/terraria/logs/terraria-stdout.log` | Terraria server output |
| `/terraria/logs/terraria-stderr.log` | Terraria server errors |
| `/terraria/logs/supervisord.log` | Process manager log |
| `/terraria/logs/crashes.log` | Crash notifications |
| `/terraria/logs/backup-scheduler-stdout.log` | Backup scheduler log |

### Host System

| Path | Contents |
|------|----------|
| `data/logs/` | Mounted from container |
| Docker logs | `docker logs terraria-server` |

### Viewing Logs

```bash
# View recent logs
./server.sh logs 100

# Live follow all logs
./server.sh livelogs

# Specific log file
docker exec terraria-server tail -100 /terraria/logs/terraria-stdout.log

# Search logs
docker exec terraria-server grep "error" /terraria/logs/*.log
```

---

## Getting Help

### Information to Collect

When seeking help, gather:

1. **Server status:**
   ```bash
   ./server.sh status > status.txt
   ```

2. **Recent logs:**
   ```bash
   docker logs terraria-server --tail 100 > docker-logs.txt
   ```

3. **Configuration (remove passwords!):**
   ```bash
   grep -v PASSWORD .env > config.txt
   ```

4. **System info:**
   ```bash
   uname -a
   docker --version
   docker-compose --version
   ```

### Where to Get Help

1. **Check existing documentation:**
   - [SETUP.md](SETUP.md)
   - [CONFIGURATION.md](CONFIGURATION.md)
   - [NETWORKING.md](NETWORKING.md)

2. **Search for similar issues:**
   - Check project issues (if hosted on GitHub)
   - Search Terraria forums for server issues

3. **Community resources:**
   - Terraria subreddit: r/Terraria
   - Steam Deck subreddit: r/SteamDeck
   - Terraria Discord servers

### Reporting Bugs

When reporting a bug, include:

1. **Description:** What happened vs. what you expected
2. **Steps to reproduce:** How to trigger the issue
3. **Environment:** Steam Deck model, SteamOS version
4. **Logs:** Relevant error messages
5. **Configuration:** Non-sensitive settings

---

## Quick Fixes Reference

| Problem | Quick Fix |
|---------|-----------|
| Server won't start | `./server.sh clean && ./server.sh start` |
| Terraria crash | Check `/terraria/logs/crashes.log` |
| No backups | Check `BACKUP_ENABLED=true` |
| Port conflict | Change port in `.env`, restart |
| Out of memory | Increase limits in docker-compose.yml |
| World corrupt | Restore from backup |
| Connection refused | Check firewall, port forwarding |
| Container missing | `./server.sh start` |

---

*For setup instructions, see [SETUP.md](SETUP.md)*
*For configuration options, see [CONFIGURATION.md](CONFIGURATION.md)*
*For networking help, see [NETWORKING.md](NETWORKING.md)*
