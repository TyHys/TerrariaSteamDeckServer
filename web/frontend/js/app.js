/**
 * TerrariaSteamDeckServer Web Application
 * Main application logic and UI handlers
 */

// ==============================
// Application State
// ==============================
const app = {
    currentPage: 'dashboard',
    refreshInterval: null,
    logsRefreshInterval: null,
    serverStatus: null,
    config: null
};

// ==============================
// Initialization
// ==============================
document.addEventListener('DOMContentLoaded', async () => {
    // Check authentication status
    if (api.isAuthenticated()) {
        const valid = await api.verifyToken();
        if (valid.valid) {
            showApp();
            initApp();
        } else {
            api.clearToken();
            showLogin();
        }
    } else {
        showLogin();
    }

    // Setup event listeners
    setupEventListeners();
});

// Listen for auth expiration
window.addEventListener('auth:expired', () => {
    showLogin();
    showToast('Session Expired', 'Please log in again.', 'warning');
});

// ==============================
// Authentication
// ==============================
function showLogin() {
    document.getElementById('login-screen').classList.add('active');
    document.getElementById('app-screen').classList.remove('active');
    document.getElementById('app-screen').style.display = 'none';
}

function showApp() {
    document.getElementById('login-screen').classList.remove('active');
    document.getElementById('app-screen').classList.add('active');
    document.getElementById('app-screen').style.display = 'flex';
}

async function handleLogin(e) {
    e.preventDefault();
    
    const btn = e.target.querySelector('button[type="submit"]');
    const btnText = btn.querySelector('.btn-text');
    const btnLoading = btn.querySelector('.btn-loading');
    const errorDiv = document.getElementById('login-error');
    
    const username = document.getElementById('username').value;
    const password = document.getElementById('password').value;

    // Show loading state
    btn.disabled = true;
    btnText.classList.add('hidden');
    btnLoading.classList.remove('hidden');
    errorDiv.classList.add('hidden');

    try {
        await api.login(username, password);
        showApp();
        initApp();
        showToast('Welcome', 'Successfully logged in', 'success');
    } catch (error) {
        errorDiv.textContent = error.message || 'Login failed';
        errorDiv.classList.remove('hidden');
    } finally {
        btn.disabled = false;
        btnText.classList.remove('hidden');
        btnLoading.classList.add('hidden');
    }
}

function handleLogout() {
    api.logout();
    stopRefreshIntervals();
    showLogin();
    showToast('Logged Out', 'You have been logged out', 'info');
}

// ==============================
// App Initialization
// ==============================
function initApp() {
    // Load initial data
    refreshDashboard();
    loadConfig();
    
    // Start auto-refresh
    startRefreshIntervals();
    
    // Navigate to dashboard
    navigateTo('dashboard');
}

function startRefreshIntervals() {
    // Refresh dashboard every 30 seconds
    app.refreshInterval = setInterval(() => {
        if (app.currentPage === 'dashboard') {
            refreshDashboard();
        }
    }, 30000);
}

function stopRefreshIntervals() {
    if (app.refreshInterval) {
        clearInterval(app.refreshInterval);
        app.refreshInterval = null;
    }
    if (app.logsRefreshInterval) {
        clearInterval(app.logsRefreshInterval);
        app.logsRefreshInterval = null;
    }
}

// ==============================
// Event Listeners Setup
// ==============================
function setupEventListeners() {
    // Login form
    document.getElementById('login-form').addEventListener('submit', handleLogin);
    
    // Logout button
    document.getElementById('logout-btn').addEventListener('click', handleLogout);
    
    // Navigation
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            const page = e.currentTarget.dataset.page;
            navigateTo(page);
        });
    });
    
    // Refresh button
    document.getElementById('refresh-btn').addEventListener('click', () => {
        refreshCurrentPage();
    });

    // ==============================
    // Dashboard Controls
    // ==============================
    document.getElementById('btn-start').addEventListener('click', handleStartServer);
    document.getElementById('btn-stop').addEventListener('click', handleStopServer);
    document.getElementById('btn-restart').addEventListener('click', handleRestartServer);
    document.getElementById('btn-health-check').addEventListener('click', handleHealthCheck);
    
    // Quick actions
    document.getElementById('btn-quick-backup').addEventListener('click', () => {
        handleCreateBackup();
    });
    document.getElementById('btn-quick-world').addEventListener('click', () => {
        navigateTo('worlds');
        setTimeout(() => showCreateWorldModal(), 100);
    });
    document.getElementById('btn-quick-logs').addEventListener('click', () => {
        navigateTo('logs');
    });

    // ==============================
    // Worlds Page
    // ==============================
    document.getElementById('btn-create-world').addEventListener('click', showCreateWorldModal);

    // ==============================
    // Backups Page
    // ==============================
    document.getElementById('btn-create-backup').addEventListener('click', () => handleCreateBackup());
    document.getElementById('btn-cleanup-backups').addEventListener('click', handleCleanupBackups);

    // ==============================
    // Configuration Page
    // ==============================
    document.getElementById('config-form').addEventListener('submit', handleSaveConfig);
    document.getElementById('btn-reload-config').addEventListener('click', loadConfig);

    // ==============================
    // Logs Page
    // ==============================
    document.getElementById('log-type-select').addEventListener('change', loadLogs);
    document.getElementById('log-lines-select').addEventListener('change', loadLogs);
    document.getElementById('btn-refresh-logs').addEventListener('click', loadLogs);
    document.getElementById('btn-search-logs').addEventListener('click', handleSearchLogs);
    document.getElementById('logs-search-input').addEventListener('keypress', (e) => {
        if (e.key === 'Enter') handleSearchLogs();
    });
    document.getElementById('log-auto-refresh').addEventListener('change', (e) => {
        if (e.target.checked) {
            app.logsRefreshInterval = setInterval(loadLogs, 5000);
        } else if (app.logsRefreshInterval) {
            clearInterval(app.logsRefreshInterval);
            app.logsRefreshInterval = null;
        }
    });

    // ==============================
    // Modal
    // ==============================
    document.querySelector('.modal-overlay').addEventListener('click', closeModal);
    document.querySelector('.modal-close').addEventListener('click', closeModal);
}

// ==============================
// Navigation
// ==============================
function navigateTo(page) {
    // Update active nav link
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.toggle('active', link.dataset.page === page);
    });
    
    // Update active page
    document.querySelectorAll('.page').forEach(pageEl => {
        pageEl.classList.toggle('active', pageEl.id === `page-${page}`);
    });
    
    // Update page title
    const titles = {
        dashboard: 'Dashboard',
        worlds: 'Worlds',
        backups: 'Backups',
        config: 'Configuration',
        logs: 'Logs'
    };
    document.getElementById('current-page-title').textContent = titles[page] || page;
    
    // Store current page
    app.currentPage = page;
    
    // Load page data
    switch (page) {
        case 'dashboard':
            refreshDashboard();
            break;
        case 'worlds':
            loadWorlds();
            break;
        case 'backups':
            loadBackups();
            break;
        case 'config':
            loadConfig();
            break;
        case 'logs':
            loadLogs();
            break;
    }
}

function refreshCurrentPage() {
    navigateTo(app.currentPage);
    showToast('Refreshed', 'Page data updated', 'info');
}

// ==============================
// Dashboard Functions
// ==============================
async function refreshDashboard() {
    try {
        // Get server status
        const status = await api.getServerStatus();
        app.serverStatus = status;
        updateServerStatusDisplay(status);
        
        // Get config for info display
        if (!app.config) {
            const config = await api.getConfig();
            app.config = config;
        }
        updateServerInfoDisplay(app.config);
        
        // Update disk usage
        updateDiskUsageDisplay(status.disk);
        
    } catch (error) {
        console.error('Failed to refresh dashboard:', error);
        updateServerStatusDisplay({ running: false, error: error.message });
    }
}

function updateServerStatusDisplay(status) {
    const statusDisplay = document.getElementById('server-status-display');
    const statusIcon = statusDisplay.querySelector('.status-icon');
    const statusText = document.getElementById('server-status-text');
    const indicator = document.getElementById('server-status-indicator');
    const indicatorText = indicator.querySelector('.status-text');
    
    const isRunning = status.running || (status.terraria && status.terraria.running);
    
    // Update status display
    statusIcon.classList.toggle('online', isRunning);
    statusIcon.classList.toggle('offline', !isRunning);
    statusText.textContent = isRunning ? 'Running' : 'Stopped';
    
    // Update top bar indicator
    indicator.classList.toggle('online', isRunning);
    indicator.classList.toggle('offline', !isRunning);
    indicatorText.textContent = isRunning ? 'Online' : 'Offline';
    
    // Update control buttons
    document.getElementById('btn-start').disabled = isRunning;
    document.getElementById('btn-stop').disabled = !isRunning;
    document.getElementById('btn-restart').disabled = !isRunning;
}

function updateServerInfoDisplay(config) {
    if (!config || !config.server) return;
    
    document.getElementById('info-world').textContent = config.server.world_name || '-';
    document.getElementById('info-port').textContent = config.server.port || '7777';
    document.getElementById('info-players').textContent = config.server.max_players || '8';
    document.getElementById('info-password').textContent = config.server.has_password ? 'Yes' : 'No';
}

function updateDiskUsageDisplay(disk) {
    if (!disk) return;
    
    if (disk.worlds) {
        const worlds = disk.worlds;
        document.getElementById('disk-worlds').textContent = 
            worlds.used_human || formatBytes(worlds.used_bytes || 0);
    }
    
    if (disk.backups) {
        const backups = disk.backups;
        document.getElementById('disk-backups').textContent = 
            backups.used_human || formatBytes(backups.used_bytes || 0);
    }
}

async function handleHealthCheck() {
    const btn = document.getElementById('btn-health-check');
    btn.disabled = true;
    
    try {
        const health = await api.getHealth();
        updateHealthDisplay(health.checks);
    } catch (error) {
        showToast('Health Check Failed', error.message, 'error');
    } finally {
        btn.disabled = false;
    }
}

function updateHealthDisplay(checks) {
    if (!checks) return;
    
    const updateCheck = (id, check) => {
        const el = document.getElementById(id);
        if (el && check) {
            el.textContent = check.message || check.status;
            el.className = 'health-status ' + (check.status || 'unknown');
        }
    };
    
    updateCheck('health-supervisor', checks.supervisor);
    updateCheck('health-terraria', checks.terraria);
    updateCheck('health-backup', checks.backup_scheduler);
    updateCheck('health-disk', checks.disk);
}

// ==============================
// Server Control Functions
// ==============================
async function handleStartServer() {
    const btn = document.getElementById('btn-start');
    btn.disabled = true;
    
    try {
        await api.startServer();
        showToast('Server Starting', 'The server is starting up...', 'success');
        setTimeout(refreshDashboard, 2000);
    } catch (error) {
        showToast('Start Failed', error.message, 'error');
        btn.disabled = false;
    }
}

async function handleStopServer() {
    const btn = document.getElementById('btn-stop');
    btn.disabled = true;
    
    try {
        await api.stopServer();
        showToast('Server Stopping', 'The server is shutting down...', 'warning');
        setTimeout(refreshDashboard, 2000);
    } catch (error) {
        showToast('Stop Failed', error.message, 'error');
        btn.disabled = false;
    }
}

async function handleRestartServer() {
    const btn = document.getElementById('btn-restart');
    btn.disabled = true;
    
    try {
        await api.restartServer();
        showToast('Server Restarting', 'The server is restarting...', 'warning');
        setTimeout(refreshDashboard, 3000);
    } catch (error) {
        showToast('Restart Failed', error.message, 'error');
        btn.disabled = false;
    }
}

// ==============================
// Worlds Page Functions
// ==============================
async function loadWorlds() {
    const container = document.getElementById('worlds-list');
    container.innerHTML = '<div class="loading-state">Loading worlds...</div>';
    
    try {
        const result = await api.getWorlds();
        const config = await api.getConfig();
        const activeWorld = config.server?.world_name;
        
        if (!result.worlds || result.worlds.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">🌍</div>
                    <div class="empty-state-title">No Worlds Found</div>
                    <div class="empty-state-text">Create your first world to get started.</div>
                    <button class="btn btn-primary" onclick="showCreateWorldModal()">
                        Create World
                    </button>
                </div>
            `;
            return;
        }
        
        container.innerHTML = result.worlds.map(world => `
            <div class="world-card" data-world="${escapeHtml(world.name)}">
                <div class="world-card-header">
                    <div class="world-name">
                        🌍 ${escapeHtml(world.name)}
                        ${world.name === activeWorld ? '<span class="world-active">Active</span>' : ''}
                    </div>
                </div>
                <div class="world-card-body">
                    <div class="world-info">
                        <div class="world-info-item">
                            <span class="world-info-label">Size</span>
                            <span class="world-info-value">${world.size}</span>
                        </div>
                        <div class="world-info-item">
                            <span class="world-info-label">Modified</span>
                            <span class="world-info-value">${formatDate(world.modified)}</span>
                        </div>
                        <div class="world-info-item">
                            <span class="world-info-label">Backup</span>
                            <span class="world-info-value">${world.has_backup ? 'Yes' : 'No'}</span>
                        </div>
                    </div>
                    <div class="world-card-actions">
                        <button class="btn btn-outline btn-sm" onclick="handleCopyWorld('${escapeHtml(world.name)}')">
                            Copy
                        </button>
                        <button class="btn btn-outline btn-sm" onclick="handleBackupWorld('${escapeHtml(world.name)}')">
                            Backup
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="handleDeleteWorld('${escapeHtml(world.name)}')" 
                            ${world.name === activeWorld ? 'disabled title="Cannot delete active world"' : ''}>
                            Delete
                        </button>
                    </div>
                </div>
            </div>
        `).join('');
        
    } catch (error) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">❌</div>
                <div class="empty-state-title">Error Loading Worlds</div>
                <div class="empty-state-text">${escapeHtml(error.message)}</div>
            </div>
        `;
    }
}

function showCreateWorldModal() {
    const body = `
        <form id="create-world-form">
            <div class="form-group">
                <label for="world-name">World Name</label>
                <input type="text" id="world-name" required placeholder="MyWorld" 
                    pattern="[a-zA-Z0-9_-]+" title="Only letters, numbers, underscores, and hyphens">
            </div>
            <div class="form-group">
                <label for="world-size">World Size</label>
                <select id="world-size">
                    <option value="1">Small</option>
                    <option value="2" selected>Medium</option>
                    <option value="3">Large</option>
                </select>
            </div>
            <div class="form-group">
                <label for="world-difficulty">Difficulty</label>
                <select id="world-difficulty">
                    <option value="0" selected>Classic</option>
                    <option value="1">Expert</option>
                    <option value="2">Master</option>
                    <option value="3">Journey</option>
                </select>
            </div>
            <div class="form-group">
                <label for="world-seed">Seed (optional)</label>
                <input type="text" id="world-seed" placeholder="Leave empty for random">
            </div>
        </form>
    `;
    
    showModal('Create New World', body, [
        { text: 'Cancel', class: 'btn-outline', action: closeModal },
        { text: 'Create World', class: 'btn-primary', action: handleCreateWorld }
    ]);
}

async function handleCreateWorld() {
    const name = document.getElementById('world-name').value.trim();
    const size = parseInt(document.getElementById('world-size').value);
    const difficulty = parseInt(document.getElementById('world-difficulty').value);
    const seed = document.getElementById('world-seed').value.trim();
    
    if (!name) {
        showToast('Validation Error', 'World name is required', 'error');
        return;
    }
    
    closeModal();
    showToast('Creating World', 'This may take a few minutes...', 'info');
    
    try {
        await api.createWorld(name, size, difficulty, seed);
        showToast('World Created', `World "${name}" has been created`, 'success');
        loadWorlds();
    } catch (error) {
        showToast('Creation Failed', error.message, 'error');
    }
}

async function handleDeleteWorld(name) {
    if (!confirm(`Are you sure you want to delete world "${name}"? This cannot be undone.`)) {
        return;
    }
    
    try {
        await api.deleteWorld(name);
        showToast('World Deleted', `World "${name}" has been deleted`, 'success');
        loadWorlds();
    } catch (error) {
        showToast('Delete Failed', error.message, 'error');
    }
}

async function handleCopyWorld(name) {
    const destination = prompt(`Enter name for the copy of "${name}":`);
    if (!destination) return;
    
    try {
        await api.copyWorld(name, destination);
        showToast('World Copied', `World copied to "${destination}"`, 'success');
        loadWorlds();
    } catch (error) {
        showToast('Copy Failed', error.message, 'error');
    }
}

async function handleBackupWorld(name) {
    try {
        await api.createBackup(name);
        showToast('Backup Created', `Backup of "${name}" created`, 'success');
    } catch (error) {
        showToast('Backup Failed', error.message, 'error');
    }
}

// ==============================
// Backups Page Functions
// ==============================
async function loadBackups() {
    const container = document.getElementById('backups-list');
    container.innerHTML = '<div class="loading-state">Loading backups...</div>';
    
    try {
        const result = await api.getBackups();
        
        // Update info bar
        document.getElementById('backup-count').textContent = `${result.count} backups`;
        document.getElementById('backup-size').textContent = `${result.total_size} total`;
        document.getElementById('backup-retention').textContent = `Retention: ${result.retention} backups`;
        
        if (!result.backups || result.backups.length === 0) {
            container.innerHTML = `
                <div class="empty-state">
                    <div class="empty-state-icon">💾</div>
                    <div class="empty-state-title">No Backups Found</div>
                    <div class="empty-state-text">Create your first backup to protect your worlds.</div>
                    <button class="btn btn-primary" onclick="handleCreateBackup()">
                        Create Backup
                    </button>
                </div>
            `;
            return;
        }
        
        container.innerHTML = `
            <div class="backup-row header">
                <div>Filename</div>
                <div>World</div>
                <div>Date</div>
                <div>Size</div>
                <div>Actions</div>
            </div>
            ${result.backups.map(backup => `
                <div class="backup-row" data-backup="${escapeHtml(backup.filename)}">
                    <div class="backup-filename">${escapeHtml(backup.filename)}</div>
                    <div class="backup-world">${escapeHtml(backup.world_name)}</div>
                    <div class="backup-date">${formatBackupDate(backup.date, backup.time)}</div>
                    <div class="backup-size">${backup.size}</div>
                    <div class="backup-actions">
                        <button class="btn btn-success btn-sm" onclick="handleRestoreBackup('${escapeHtml(backup.filename)}')">
                            Restore
                        </button>
                        <button class="btn btn-danger btn-sm" onclick="handleDeleteBackup('${escapeHtml(backup.filename)}')">
                            Delete
                        </button>
                    </div>
                </div>
            `).join('')}
        `;
        
    } catch (error) {
        container.innerHTML = `
            <div class="empty-state">
                <div class="empty-state-icon">❌</div>
                <div class="empty-state-title">Error Loading Backups</div>
                <div class="empty-state-text">${escapeHtml(error.message)}</div>
            </div>
        `;
    }
}

async function handleCreateBackup(world = '') {
    showToast('Creating Backup', 'Please wait...', 'info');
    
    try {
        await api.createBackup(world);
        showToast('Backup Created', 'Backup created successfully', 'success');
        if (app.currentPage === 'backups') {
            loadBackups();
        }
    } catch (error) {
        showToast('Backup Failed', error.message, 'error');
    }
}

async function handleRestoreBackup(filename) {
    // Check if server is running first
    try {
        const status = await api.getServerStatus();
        if (status.running) {
            showToast('Server Running', 'Stop the server before restoring a backup', 'warning');
            return;
        }
    } catch (error) {
        // Continue anyway
    }
    
    if (!confirm(`Restore backup "${filename}"? This will overwrite current world data.`)) {
        return;
    }
    
    try {
        await api.restoreBackup(filename);
        showToast('Backup Restored', 'Backup restored successfully', 'success');
        loadBackups();
    } catch (error) {
        showToast('Restore Failed', error.message, 'error');
    }
}

async function handleDeleteBackup(filename) {
    if (!confirm(`Delete backup "${filename}"? This cannot be undone.`)) {
        return;
    }
    
    try {
        await api.deleteBackup(filename);
        showToast('Backup Deleted', 'Backup deleted successfully', 'success');
        loadBackups();
    } catch (error) {
        showToast('Delete Failed', error.message, 'error');
    }
}

async function handleCleanupBackups() {
    if (!confirm('Run backup cleanup? This will remove old backups based on the retention policy.')) {
        return;
    }
    
    try {
        await api.cleanupBackups();
        showToast('Cleanup Complete', 'Old backups have been removed', 'success');
        loadBackups();
    } catch (error) {
        showToast('Cleanup Failed', error.message, 'error');
    }
}

// ==============================
// Configuration Page Functions
// ==============================
async function loadConfig() {
    try {
        const config = await api.getConfig();
        app.config = config;
        
        // Populate form
        if (config.server) {
            document.getElementById('config-max-players').value = config.server.max_players || 8;
            document.getElementById('config-password').value = '';  // Don't show password
            document.getElementById('config-motd').value = config.server.motd || '';
            document.getElementById('config-difficulty').value = config.server.difficulty || 0;
            document.getElementById('config-autocreate').value = config.server.autocreate || 2;
            document.getElementById('config-secure').checked = config.server.secure == 1;
        }
        
        if (config.backup) {
            document.getElementById('config-backup-enabled').checked = config.backup.enabled;
            document.getElementById('config-backup-interval').value = config.backup.interval || 30;
            document.getElementById('config-backup-retention').value = config.backup.retention || 48;
        }
        
        hideConfigMessage();
        
    } catch (error) {
        showConfigMessage(`Error loading configuration: ${error.message}`, 'error');
    }
}

async function handleSaveConfig(e) {
    e.preventDefault();
    
    const settings = {
        max_players: parseInt(document.getElementById('config-max-players').value),
        motd: document.getElementById('config-motd').value,
        difficulty: parseInt(document.getElementById('config-difficulty').value),
        autocreate: parseInt(document.getElementById('config-autocreate').value),
        secure: document.getElementById('config-secure').checked ? 1 : 0,
        backup_enabled: document.getElementById('config-backup-enabled').checked,
        backup_interval: parseInt(document.getElementById('config-backup-interval').value),
        backup_retention: parseInt(document.getElementById('config-backup-retention').value)
    };
    
    // Only include password if changed
    const password = document.getElementById('config-password').value;
    if (password) {
        settings.password = password;
    }
    
    try {
        const result = await api.updateConfig(settings);
        
        if (result.restart_required) {
            showConfigMessage('Configuration saved. Restart the server for changes to take effect.', 'warning');
        } else {
            showConfigMessage('Configuration saved successfully.', 'success');
        }
        
        // Reload config to update app state
        loadConfig();
        
    } catch (error) {
        showConfigMessage(`Failed to save: ${error.message}`, 'error');
    }
}

function showConfigMessage(message, type) {
    const el = document.getElementById('config-message');
    el.textContent = message;
    el.className = 'form-message ' + type;
    el.classList.remove('hidden');
}

function hideConfigMessage() {
    document.getElementById('config-message').classList.add('hidden');
}

// ==============================
// Logs Page Functions
// ==============================
async function loadLogs() {
    const viewer = document.getElementById('logs-viewer');
    const logType = document.getElementById('log-type-select').value;
    const lines = parseInt(document.getElementById('log-lines-select').value);
    
    viewer.textContent = 'Loading logs...';
    
    try {
        const result = await api.getLog(logType, lines);
        
        if (!result.exists || !result.content) {
            viewer.textContent = 'Log file is empty or does not exist.';
        } else {
            viewer.textContent = result.content;
            // Scroll to bottom
            viewer.scrollTop = viewer.scrollHeight;
        }
        
    } catch (error) {
        viewer.textContent = `Error loading logs: ${error.message}`;
    }
}

async function handleSearchLogs() {
    const query = document.getElementById('logs-search-input').value.trim();
    if (!query) {
        showToast('Search', 'Enter a search term', 'warning');
        return;
    }
    
    const viewer = document.getElementById('logs-viewer');
    viewer.textContent = 'Searching...';
    
    try {
        const result = await api.searchLogs(query);
        
        if (!result.results || result.results.length === 0) {
            viewer.textContent = `No results found for "${query}"`;
        } else {
            viewer.textContent = result.results.map(r => 
                `[${r.log}:${r.line_number}] ${r.content}`
            ).join('\n');
        }
        
    } catch (error) {
        viewer.textContent = `Search error: ${error.message}`;
    }
}

// ==============================
// Modal Functions
// ==============================
function showModal(title, bodyHtml, buttons = []) {
    const container = document.getElementById('modal-container');
    const titleEl = document.getElementById('modal-title');
    const bodyEl = document.getElementById('modal-body');
    const footerEl = document.getElementById('modal-footer');
    
    titleEl.textContent = title;
    bodyEl.innerHTML = bodyHtml;
    
    footerEl.innerHTML = buttons.map(btn => `
        <button class="btn ${btn.class || 'btn-outline'}" data-action="${btn.text}">
            ${btn.text}
        </button>
    `).join('');
    
    // Add button click handlers
    buttons.forEach(btn => {
        footerEl.querySelector(`[data-action="${btn.text}"]`).addEventListener('click', btn.action);
    });
    
    container.classList.remove('hidden');
}

function closeModal() {
    document.getElementById('modal-container').classList.add('hidden');
}

// ==============================
// Toast Notifications
// ==============================
function showToast(title, message, type = 'info') {
    const container = document.getElementById('toast-container');
    
    const icons = {
        success: '✅',
        error: '❌',
        warning: '⚠️',
        info: 'ℹ️'
    };
    
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
        <span class="toast-icon">${icons[type] || icons.info}</span>
        <div class="toast-content">
            <div class="toast-title">${escapeHtml(title)}</div>
            <div class="toast-message">${escapeHtml(message)}</div>
        </div>
        <button class="toast-close">&times;</button>
    `;
    
    // Add close handler
    toast.querySelector('.toast-close').addEventListener('click', () => {
        toast.remove();
    });
    
    container.appendChild(toast);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        if (toast.parentNode) {
            toast.style.animation = 'slideIn 0.3s ease reverse';
            setTimeout(() => toast.remove(), 300);
        }
    }, 5000);
}

// ==============================
// Utility Functions
// ==============================
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatBytes(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function formatDate(timestamp) {
    if (!timestamp) return '-';
    const date = typeof timestamp === 'number' ? new Date(timestamp * 1000) : new Date(timestamp);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}

function formatBackupDate(dateStr, timeStr) {
    if (!dateStr) return '-';
    // Format: YYYYMMDD to YYYY-MM-DD
    const year = dateStr.substring(0, 4);
    const month = dateStr.substring(4, 6);
    const day = dateStr.substring(6, 8);
    
    let formatted = `${year}-${month}-${day}`;
    
    if (timeStr) {
        // Format: HHMMSS to HH:MM
        const hour = timeStr.substring(0, 2);
        const minute = timeStr.substring(2, 4);
        formatted += ` ${hour}:${minute}`;
    }
    
    return formatted;
}
