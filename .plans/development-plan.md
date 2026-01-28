# TerrariaSteamDeckServer Development Plan

## Project Overview

This project creates a Docker-containerized Terraria dedicated server optimized for Steam Deck devices running in Desktop Mode. The solution includes a web-based management interface, automated backup system, and world creation tools. The server is designed to be robust enough for public hosting.

---

## Technical Architecture

### Core Components

| Component | Technology | Purpose |
|-----------|------------|---------|
| Terraria Server | TShock/Vanilla Dedicated Server Binary | Game server runtime |
| Container Runtime | Docker | Isolation and portability |
| Web Interface Backend | TBD (Python/Flask or Node.js) | API and server management |
| Web Interface Frontend | TBD (HTML/CSS/JS or React) | User-facing management UI |
| Process Manager | Supervisor or custom script | Crash detection and auto-restart |
| Backup System | Shell scripts + cron/scheduler | Automated world backups |

### Container Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Container                      │
│  ┌─────────────────┐  ┌─────────────────────────────┐   │
│  │ Terraria Server │  │ Web Interface (Backend/UI) │   │
│  │   (Port 7777)   │  │        (Port 8080)          │   │
│  └─────────────────┘  └─────────────────────────────┘   │
│  ┌─────────────────┐  ┌─────────────────────────────┐   │
│  │ Process Manager │  │      Backup Scheduler       │   │
│  └─────────────────┘  └─────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐    ┌─────────────────────────────┐
│  Volume: Worlds │    │  Volume: Backups & Config   │
└─────────────────┘    └─────────────────────────────┘
```

### Directory Structure (Proposed)

```
TerrariaSteamDeckServer/
├── docker/
│   ├── Dockerfile
│   └── docker-compose.yml
├── server/
│   ├── config/
│   │   └── serverconfig.txt
│   └── scripts/
│       ├── start-server.sh
│       ├── backup.sh
│       └── restore.sh
├── web/
│   ├── backend/
│   │   └── (API code)
│   └── frontend/
│       └── (UI code)
├── docs/
│   ├── SETUP.md
│   ├── CONFIGURATION.md
│   ├── NETWORKING.md
│   └── TROUBLESHOOTING.md
└── README.md
```

---

## Development Phases

### Phase 1: Core Docker Infrastructure

**Objective:** Create a working Docker container that runs a vanilla Terraria dedicated server.

**Tasks:**
- [ ] Research and select the best Terraria dedicated server approach for Linux/Docker
- [ ] Create base Dockerfile with Terraria server installation
- [ ] Configure container networking (expose port 7777)
- [ ] Set up Docker volumes for world persistence
- [ ] Create docker-compose.yml for easy deployment
- [ ] Implement basic server configuration file (serverconfig.txt)
- [ ] Test basic server startup and player connection

**Deliverables:**
- Working Dockerfile
- docker-compose.yml
- Basic serverconfig.txt template

---

### Phase 2: Process Management & Stability

**Objective:** Implement crash detection and automatic restart functionality.

**Tasks:**
- [ ] Select process management approach (Supervisor, s6, or custom wrapper script)
- [ ] Implement server process monitoring
- [ ] Implement automatic restart on crash
- [ ] Add configurable restart delay/backoff
- [ ] Implement server logging with rotation
- [ ] Add graceful shutdown handling (proper world save on container stop)

**Deliverables:**
- Process manager configuration
- Server wrapper script with crash recovery
- Logging system

---

### Phase 3: World Management & Backups

**Objective:** Provide tools for world creation and automated backup functionality.

**Tasks:**
- [ ] Implement world creation script/tool (size selection, name, seed)
- [ ] Design backup strategy (frequency, retention policy)
- [ ] Implement automated backup scheduler
- [ ] Create backup script with compression
- [ ] Implement backup restoration tool
- [ ] Add backup listing and management functionality
- [ ] Ensure backups are stored in persistent volume

**Deliverables:**
- World creation tool
- Automated backup system
- Backup restoration tool
- Backup management utilities

---

### Phase 4: Web Interface - Backend

**Objective:** Create a REST API for server management operations.

**Tasks:**
- [ ] Select backend technology (recommend Python/Flask for simplicity)
- [ ] Design API endpoints:
  - `GET /api/status` - Server status (running, players, world info)
  - `POST /api/server/start` - Start server
  - `POST /api/server/stop` - Stop server
  - `POST /api/server/restart` - Restart server
  - `GET /api/config` - Get server configuration
  - `PUT /api/config` - Update server configuration
  - `GET /api/worlds` - List available worlds
  - `POST /api/worlds` - Create new world
  - `DELETE /api/worlds/{name}` - Delete world
  - `GET /api/backups` - List backups
  - `POST /api/backups` - Create manual backup
  - `POST /api/backups/{id}/restore` - Restore backup
  - `DELETE /api/backups/{id}` - Delete backup
  - `GET /api/logs` - Get server logs
- [ ] Implement authentication (basic auth or token-based)
- [ ] Implement input validation and error handling
- [ ] Add CORS configuration for frontend

**Deliverables:**
- REST API backend application
- API documentation

---

### Phase 5: Web Interface - Frontend

**Objective:** Create a user-friendly web UI for server management.

**Tasks:**
- [ ] Select frontend approach (recommend simple HTML/CSS/JS for minimal dependencies)
- [ ] Design UI layout and components
- [ ] Implement dashboard page:
  - Server status indicator
  - Quick start/stop/restart buttons
  - Current player count
  - World information
- [ ] Implement configuration page:
  - Server settings form (max players, password, MOTD, etc.)
  - Save/apply configuration
- [ ] Implement world management page:
  - World list
  - Create new world form
  - Delete world functionality
- [ ] Implement backup management page:
  - Backup list with timestamps
  - Create backup button
  - Restore backup functionality
  - Delete old backups
- [ ] Implement logs viewer page:
  - Real-time or refreshable log display
  - Log filtering/search
- [ ] Add responsive design for various screen sizes
- [ ] Implement user feedback (loading states, success/error messages)

**Deliverables:**
- Complete web UI
- Integrated with backend API

---

### Phase 6: Integration & Container Finalization

**Objective:** Integrate all components into the final Docker container.

**Tasks:**
- [ ] Integrate web interface into Docker container
- [ ] Configure container entrypoint to start all services
- [ ] Optimize container size (multi-stage build if needed)
- [ ] Configure internal networking between components
- [ ] Set up health checks
- [ ] Test full workflow: build, run, configure, play, backup, restore
- [ ] Create default/example configuration files

**Deliverables:**
- Finalized Docker image
- Complete docker-compose.yml with all options

---

### Phase 7: Documentation

**Objective:** Create comprehensive documentation for setup and usage.

**Tasks:**
- [ ] Write main README.md:
  - Project overview
  - Quick start guide
  - Prerequisites (Docker installation on Steam Deck)
  - Basic usage commands
- [ ] Write SETUP.md:
  - Detailed installation steps
  - Steam Deck-specific considerations
  - First-time configuration
- [ ] Write CONFIGURATION.md:
  - All server configuration options explained
  - Web interface configuration
  - Backup configuration
- [ ] Write NETWORKING.md:
  - Port requirements (7777 for game, 8080 for web UI)
  - Brief port forwarding explanation
  - Advice to consult router-specific documentation
  - Firewall considerations
- [ ] Write TROUBLESHOOTING.md:
  - Common issues and solutions
  - Log locations
  - How to report bugs

**Deliverables:**
- Complete documentation suite

---

### Phase 8: Testing & Polish

**Objective:** Verify functionality on Steam Deck and handle edge cases.

**Tasks:**
- [ ] Test complete installation on fresh Steam Deck
- [ ] Test server with multiple concurrent players
- [ ] Test backup and restore under various conditions
- [ ] Test crash recovery scenarios
- [ ] Test web interface on different browsers
- [ ] Verify public hosting viability (connection stability, performance)
- [ ] Address any discovered issues
- [ ] Performance optimization if needed
- [ ] Final code cleanup and comments

**Deliverables:**
- Tested, production-ready solution

---

## Server Configuration Options

The following Terraria server settings will be configurable via the web interface:

| Setting | Description | Default |
|---------|-------------|---------|
| World | World file to use | (user selected) |
| Max Players | Maximum concurrent players | 8 |
| Port | Server port | 7777 |
| Password | Server password | (empty) |
| MOTD | Message of the day | Welcome! |
| Difficulty | World difficulty (when creating) | Normal |
| World Size | Small/Medium/Large (when creating) | Medium |
| Secure | Anti-cheat protection | Enabled |
| Language | Server language | English |

---

## Backup Strategy

| Aspect | Configuration |
|--------|---------------|
| Automatic Backup Frequency | Every 30 minutes (configurable) |
| Backup Retention | Keep last 48 backups (~24 hours) |
| Backup Format | Compressed .tar.gz |
| Backup Location | Persistent Docker volume |
| Manual Backups | Available via web interface |

---

## Networking Requirements

**Ports:**
- **7777/TCP** - Terraria game server (must be forwarded for public access)
- **8080/TCP** - Web management interface (local access only recommended)

**Note:** Port forwarding is required for players outside your local network to connect. Router configuration varies by manufacturer - consult your router's documentation for specific port forwarding instructions.

---

## Technology Decisions (To Be Finalized)

| Decision | Options | Recommendation | Rationale |
|----------|---------|----------------|-----------|
| Terraria Server Binary | Official Dedicated Server | Official | Most stable, no mod overhead |
| Backend Framework | Flask, FastAPI, Node.js/Express | Flask | Simple, Python is common on Linux |
| Frontend Framework | Vanilla JS, React, Vue | Vanilla JS | No build step, minimal complexity |
| Process Manager | Supervisor, s6-overlay, custom | Supervisor | Well-documented, reliable |
| Base Docker Image | Debian, Ubuntu, Alpine | Debian Slim | Good compatibility, reasonable size |

---

## Success Criteria

- [ ] Container builds and runs on Steam Deck without errors
- [ ] Terraria server accepts player connections
- [ ] Server automatically restarts after crash
- [ ] Web interface is accessible and functional
- [ ] Configuration changes apply correctly
- [ ] Worlds can be created through the interface
- [ ] Backups run automatically on schedule
- [ ] Backups can be restored successfully
- [ ] Documentation is clear enough for new users
- [ ] Solution is stable enough for public hosting

---

## Open Questions / Future Considerations

Items explicitly out of scope but potentially valuable for future versions:

1. **tModLoader Support** - Could be added as an optional container variant
2. **Multiple Server Instances** - Would require architecture changes
3. **Remote Access** - SSH or external management panel
4. **Mobile-Friendly UI** - Enhanced responsive design
5. **Player Statistics/Analytics** - Track playtime, deaths, boss kills
6. **Discord Integration** - Webhooks for server events
7. **Auto-Start on Boot** - Systemd service integration

---

*Plan created: January 28, 2026*
*Last updated: January 28, 2026*
