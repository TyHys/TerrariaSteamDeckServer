"""
TerrariaSteamDeckServer Web Backend
Flask-based REST API for server management with integrated web UI
"""

import os
import sys
from flask import Flask, jsonify, request, send_from_directory
from flask_cors import CORS

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config import Config, get_config
from routes import auth_bp, server_bp, worlds_bp, backups_bp, config_bp, logs_bp

# Frontend static files directory
FRONTEND_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'frontend')
# In container, frontend is at /terraria/web/frontend
if os.path.exists('/terraria/web/frontend'):
    FRONTEND_DIR = '/terraria/web/frontend'


def create_app(config_class=None):
    """Application factory for the Flask app."""
    
    app = Flask(__name__, static_folder=FRONTEND_DIR, static_url_path='')
    
    # Load configuration
    if config_class is None:
        config_class = get_config()
    
    app.config.from_object(config_class)
    
    # Initialize CORS
    cors_origins = Config.CORS_ORIGINS
    if cors_origins == '*':
        CORS(app, resources={r"/api/*": {"origins": "*"}})
    else:
        origins = [o.strip() for o in cors_origins.split(',')]
        CORS(app, resources={r"/api/*": {"origins": origins}})
    
    # Register blueprints
    app.register_blueprint(auth_bp)
    app.register_blueprint(server_bp)
    app.register_blueprint(worlds_bp)
    app.register_blueprint(backups_bp)
    app.register_blueprint(config_bp)
    app.register_blueprint(logs_bp)
    
    # Serve frontend index.html
    @app.route('/')
    def index():
        """Serve the main web interface."""
        return send_from_directory(FRONTEND_DIR, 'index.html')
    
    # Serve static files (CSS, JS, etc.)
    @app.route('/<path:path>')
    def serve_static(path):
        """Serve static files from the frontend directory."""
        # Don't serve API routes as static files
        if path.startswith('api/'):
            return jsonify({'error': 'Not Found'}), 404
        
        # Try to serve the file
        file_path = os.path.join(FRONTEND_DIR, path)
        if os.path.exists(file_path) and os.path.isfile(file_path):
            return send_from_directory(FRONTEND_DIR, path)
        
        # For SPA routing, return index.html for unknown paths
        return send_from_directory(FRONTEND_DIR, 'index.html')
    
    # API info endpoint (for API discovery)
    @app.route('/api')
    def api_info():
        """API information endpoint."""
        return jsonify({
            'name': 'TerrariaSteamDeckServer API',
            'version': '1.0.0',
            'status': 'running',
            'endpoints': {
                'auth': '/api/auth',
                'server': '/api/server',
                'worlds': '/api/worlds',
                'backups': '/api/backups',
                'config': '/api/config',
                'logs': '/api/logs'
            }
        })
    
    # API status endpoint (no auth required)
    @app.route('/api/status')
    def api_status():
        from utils import is_server_running, is_supervisor_running
        return jsonify({
            'api': 'running',
            'supervisor': is_supervisor_running(),
            'terraria': is_server_running()
        })
    
    # Error handlers
    @app.errorhandler(400)
    def bad_request(error):
        return jsonify({
            'error': 'Bad Request',
            'message': str(error.description) if hasattr(error, 'description') else 'Invalid request'
        }), 400
    
    @app.errorhandler(401)
    def unauthorized(error):
        return jsonify({
            'error': 'Unauthorized',
            'message': 'Authentication required'
        }), 401
    
    @app.errorhandler(404)
    def not_found(error):
        return jsonify({
            'error': 'Not Found',
            'message': f"The requested URL {request.path} was not found"
        }), 404
    
    @app.errorhandler(405)
    def method_not_allowed(error):
        return jsonify({
            'error': 'Method Not Allowed',
            'message': f"Method {request.method} not allowed for {request.path}"
        }), 405
    
    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({
            'error': 'Internal Server Error',
            'message': 'An unexpected error occurred'
        }), 500
    
    # Request logging in debug mode
    if Config.DEBUG:
        @app.before_request
        def log_request():
            app.logger.debug(f"{request.method} {request.path}")
    
    return app


def main():
    """Run the development server."""
    
    # Validate configuration
    errors = Config.validate()
    if errors:
        print("Configuration errors:")
        for error in errors:
            print(f"  - {error}")
        print("\nPlease set the required environment variables.")
        print("Example: export API_PASSWORD='your_secure_password'")
        sys.exit(1)
    
    app = create_app()
    
    print(f"""
╔══════════════════════════════════════════════════════════════╗
║         TerrariaSteamDeckServer Web API                      ║
╠══════════════════════════════════════════════════════════════╣
║  Host:     {Config.API_HOST:<48} ║
║  Port:     {Config.API_PORT:<48} ║
║  Debug:    {str(Config.DEBUG):<48} ║
╠══════════════════════════════════════════════════════════════╣
║  API Endpoints:                                              ║
║    POST /api/auth/login     - Get auth token                 ║
║    GET  /api/server/status  - Server status                  ║
║    POST /api/server/start   - Start server                   ║
║    POST /api/server/stop    - Stop server                    ║
║    GET  /api/worlds         - List worlds                    ║
║    POST /api/worlds         - Create world                   ║
║    GET  /api/backups        - List backups                   ║
║    POST /api/backups        - Create backup                  ║
║    GET  /api/config         - Get config                     ║
║    GET  /api/logs           - List logs                      ║
╚══════════════════════════════════════════════════════════════╝
""")
    
    app.run(
        host=Config.API_HOST,
        port=Config.API_PORT,
        debug=Config.DEBUG
    )


if __name__ == '__main__':
    main()
