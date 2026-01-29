"""
API Routes for TerrariaSteamDeckServer Web Backend
"""

from flask import Blueprint

# Create blueprints for each API section
auth_bp = Blueprint('auth', __name__, url_prefix='/api/auth')
server_bp = Blueprint('server', __name__, url_prefix='/api/server')
worlds_bp = Blueprint('worlds', __name__, url_prefix='/api/worlds')
backups_bp = Blueprint('backups', __name__, url_prefix='/api/backups')
config_bp = Blueprint('config', __name__, url_prefix='/api/config')
logs_bp = Blueprint('logs', __name__, url_prefix='/api/logs')

# Import routes to register them with blueprints
from . import auth_routes
from . import server_routes
from . import worlds_routes
from . import backups_routes
from . import config_routes
from . import logs_routes
