# Terraria Server Update Guide

This guide documents how to update the Terraria dedicated server to a new version.

## Quick Update (Recommended)

```bash
./server.sh update 1453    # Replace 1453 with desired version
```

This single command will:
1. Verify the version exists on terraria.org
2. Offer to create a backup
3. Update the Dockerfile
4. Stop, rebuild, and restart the server
5. Verify the new version is running

---

## Finding Available Versions

### Official Resources

- **Terraria Wiki (Recommended):** https://terraria.wiki.gg/wiki/Server#Downloads
  - Lists all available server versions with release dates
  
- **Direct Download URL Pattern:**
  ```
  https://terraria.org/api/download/pc-dedicated-server/terraria-server-{VERSION}.zip
  ```

### Version Number Format

Terraria uses a condensed 4-digit version format:

| Game Version | Server Version |
|--------------|----------------|
| 1.4.4.9      | 1449           |
| 1.4.5.0      | 1450           |
| 1.4.5.1      | 1451           |
| 1.4.5.3      | 1453           |

**Pattern:** Remove dots and trailing zeros → `1.4.5.3` becomes `1453`

---

## Manual Update Process

If you prefer to update manually instead of using `./server.sh update`:

### 1. Update the Dockerfile

Edit `docker/Dockerfile` and change the version in **two places**:

```dockerfile
# Line ~10 (build argument)
ARG TERRARIA_VERSION=1453

# Line ~35 (environment variable)
ENV TERRARIA_VERSION=1453
```

### 2. Rebuild and Restart

```bash
# Option A: Use convenience script
./stop-build-start.sh

# Option B: Manual steps
./stop.sh
./build.sh
./start.sh

# Option C: Direct docker compose commands
docker compose -f docker/docker-compose.yml --env-file .env down
docker compose -f docker/docker-compose.yml --env-file .env build --no-cache
docker compose -f docker/docker-compose.yml --env-file .env up -d
```

### 4. Verify the Update

```bash
# Check logs for successful startup
docker compose -f docker/docker-compose.yml --env-file .env logs -f

# Run health check
docker exec terraria-server /terraria/scripts/healthcheck.sh
```

---

## Important Notes

### World Data is Safe

Your world/save data is stored in `data/worlds/` which is a Docker volume mount. Updating the server binary does **not** affect your world files.

### Backup Before Major Updates

For major version changes (e.g., 1.4.4 → 1.4.5), create a manual backup first:

```bash
docker exec terraria-server /terraria/scripts/backup.sh create
```

Or use the web dashboard to create a backup.

### Version Compatibility

Players must be on the **same version** as the server to connect. Coordinate updates with your players.

### Rollback Process

If an update causes issues, revert the Dockerfile changes and rebuild:

```bash
# Edit docker/Dockerfile, change version back to previous
# Then rebuild
./stop-build-start.sh
```

---

## Update Checklist

- [ ] Check current player game version
- [ ] Verify server version exists on terraria.org
- [ ] Create backup (recommended for major updates)
- [ ] Update `ARG TERRARIA_VERSION` in Dockerfile
- [ ] Update `ENV TERRARIA_VERSION` in Dockerfile
- [ ] Run `./stop-build-start.sh`
- [ ] Verify server starts successfully
- [ ] Test player connection
- [ ] Update README.md version reference (optional)

---

## Version History

| Date       | Version | Notes                          |
|------------|---------|--------------------------------|
| 2026-01-31 | 1453    | Updated to 1.4.5.3             |
| Previous   | 1450    | Initial 1.4.5.0 release        |
