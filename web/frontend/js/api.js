/**
 * TerrariaSteamDeckServer API Client
 * Handles all communication with the backend REST API
 */

class TerrariaAPI {
    constructor(baseUrl = '') {
        // Use current origin if no base URL provided (for production)
        this.baseUrl = baseUrl || window.location.origin;
        this.token = localStorage.getItem('authToken');
    }

    /**
     * Get authorization headers
     */
    getHeaders() {
        const headers = {
            'Content-Type': 'application/json'
        };
        if (this.token) {
            headers['Authorization'] = `Bearer ${this.token}`;
        }
        return headers;
    }

    /**
     * Make an API request
     */
    async request(method, endpoint, data = null) {
        const url = `${this.baseUrl}${endpoint}`;
        const options = {
            method,
            headers: this.getHeaders()
        };

        if (data && (method === 'POST' || method === 'PUT')) {
            options.body = JSON.stringify(data);
        }

        try {
            const response = await fetch(url, options);
            
            // Handle 401 - unauthorized
            if (response.status === 401) {
                this.clearToken();
                window.dispatchEvent(new CustomEvent('auth:expired'));
                throw new APIError('Authentication expired', 401);
            }

            const result = await response.json();

            if (!response.ok) {
                throw new APIError(
                    result.message || result.error || 'Request failed',
                    response.status,
                    result
                );
            }

            return result;
        } catch (error) {
            if (error instanceof APIError) {
                throw error;
            }
            throw new APIError(error.message || 'Network error', 0);
        }
    }

    /**
     * Store authentication token
     */
    setToken(token) {
        this.token = token;
        localStorage.setItem('authToken', token);
    }

    /**
     * Clear authentication token
     */
    clearToken() {
        this.token = null;
        localStorage.removeItem('authToken');
    }

    /**
     * Check if user is authenticated
     */
    isAuthenticated() {
        return !!this.token;
    }

    // ==============================
    // Authentication Endpoints
    // ==============================

    /**
     * Login and get authentication token
     */
    async login(username, password) {
        const result = await this.request('POST', '/api/auth/login', {
            username,
            password
        });
        if (result.token) {
            this.setToken(result.token);
        }
        return result;
    }

    /**
     * Verify current token is valid
     */
    async verifyToken() {
        try {
            return await this.request('GET', '/api/auth/verify');
        } catch (error) {
            return { valid: false };
        }
    }

    /**
     * Refresh authentication token
     */
    async refreshToken() {
        const result = await this.request('POST', '/api/auth/refresh');
        if (result.token) {
            this.setToken(result.token);
        }
        return result;
    }

    /**
     * Logout - clear token locally
     */
    logout() {
        this.clearToken();
    }

    // ==============================
    // Server Control Endpoints
    // ==============================

    /**
     * Get server status
     */
    async getServerStatus() {
        return await this.request('GET', '/api/server/status');
    }

    /**
     * Start the server
     */
    async startServer() {
        return await this.request('POST', '/api/server/start');
    }

    /**
     * Stop the server
     */
    async stopServer() {
        return await this.request('POST', '/api/server/stop');
    }

    /**
     * Restart the server
     */
    async restartServer() {
        return await this.request('POST', '/api/server/restart');
    }

    /**
     * Run health check
     */
    async getHealth() {
        return await this.request('GET', '/api/server/health');
    }

    // ==============================
    // World Management Endpoints
    // ==============================

    /**
     * List all worlds
     */
    async getWorlds() {
        return await this.request('GET', '/api/worlds');
    }

    /**
     * Get world details
     */
    async getWorld(name) {
        return await this.request('GET', `/api/worlds/${encodeURIComponent(name)}`);
    }

    /**
     * Create a new world
     */
    async createWorld(name, size = 2, difficulty = 0, seed = '') {
        return await this.request('POST', '/api/worlds', {
            name,
            size,
            difficulty,
            seed
        });
    }

    /**
     * Delete a world
     */
    async deleteWorld(name) {
        return await this.request('DELETE', `/api/worlds/${encodeURIComponent(name)}?confirm=${encodeURIComponent(name)}`);
    }

    /**
     * Copy a world
     */
    async copyWorld(name, destination) {
        return await this.request('POST', `/api/worlds/${encodeURIComponent(name)}/copy`, {
            destination
        });
    }

    // ==============================
    // Backup Management Endpoints
    // ==============================

    /**
     * List all backups
     */
    async getBackups(world = '', limit = null) {
        let endpoint = '/api/backups';
        const params = [];
        if (world) params.push(`world=${encodeURIComponent(world)}`);
        if (limit) params.push(`limit=${limit}`);
        if (params.length) endpoint += '?' + params.join('&');
        return await this.request('GET', endpoint);
    }

    /**
     * Get backup details
     */
    async getBackup(filename) {
        return await this.request('GET', `/api/backups/${encodeURIComponent(filename)}`);
    }

    /**
     * Create a backup
     */
    async createBackup(world = '') {
        return await this.request('POST', '/api/backups', world ? { world } : {});
    }

    /**
     * Restore a backup
     */
    async restoreBackup(filename, noBackup = false) {
        let endpoint = `/api/backups/${encodeURIComponent(filename)}/restore`;
        if (noBackup) endpoint += '?no_backup=true';
        return await this.request('POST', endpoint);
    }

    /**
     * Delete a backup
     */
    async deleteBackup(filename) {
        return await this.request('DELETE', `/api/backups/${encodeURIComponent(filename)}?confirm=true`);
    }

    /**
     * Run backup cleanup
     */
    async cleanupBackups() {
        return await this.request('POST', '/api/backups/cleanup');
    }

    // ==============================
    // Configuration Endpoints
    // ==============================

    /**
     * Get server configuration
     */
    async getConfig() {
        return await this.request('GET', '/api/config');
    }

    /**
     * Update server configuration
     */
    async updateConfig(settings) {
        return await this.request('PUT', '/api/config', settings);
    }

    /**
     * Get runtime configuration
     */
    async getRuntimeConfig() {
        return await this.request('GET', '/api/config/runtime');
    }

    // ==============================
    // Logs Endpoints
    // ==============================

    /**
     * List log files
     */
    async getLogs() {
        return await this.request('GET', '/api/logs');
    }

    /**
     * Get log content
     */
    async getLog(type, lines = 100, offset = 0) {
        return await this.request('GET', `/api/logs/${type}?lines=${lines}&offset=${offset}`);
    }

    /**
     * Clear a log file
     */
    async clearLog(type) {
        return await this.request('POST', `/api/logs/${type}/clear?confirm=true`);
    }

    /**
     * Search logs
     */
    async searchLogs(query, log = '', limit = 50) {
        let endpoint = `/api/logs/search?q=${encodeURIComponent(query)}`;
        if (log) endpoint += `&log=${encodeURIComponent(log)}`;
        endpoint += `&limit=${limit}`;
        return await this.request('GET', endpoint);
    }

    // ==============================
    // Quick Status (No Auth)
    // ==============================

    /**
     * Get quick API status (no auth required)
     */
    async getQuickStatus() {
        try {
            const response = await fetch(`${this.baseUrl}/api/status`);
            return await response.json();
        } catch (error) {
            return { api: 'error', error: error.message };
        }
    }
}

/**
 * Custom API Error class
 */
class APIError extends Error {
    constructor(message, status, data = null) {
        super(message);
        this.name = 'APIError';
        this.status = status;
        this.data = data;
    }
}

// Create global API instance
const api = new TerrariaAPI();
