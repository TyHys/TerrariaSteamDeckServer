"""
Configuration module for TerrariaSteamDeckServer Web Backend
Loads settings from environment variables with sensible defaults.
"""

import os
import secrets
from datetime import timedelta


class Config:
    """Base configuration class."""
    
    # Flask settings
    SECRET_KEY = os.environ.get('API_SECRET_KEY', secrets.token_hex(32))
    DEBUG = os.environ.get('API_DEBUG', 'false').lower() == 'true'
    
    # API settings
    API_HOST = os.environ.get('API_HOST', '0.0.0.0')
    API_PORT = int(os.environ.get('API_PORT', '8080'))
    
    # Authentication settings
    API_USERNAME = os.environ.get('API_USERNAME', 'admin')
    API_PASSWORD = os.environ.get('API_PASSWORD', '')  # Required to be set
    API_TOKEN_EXPIRY = int(os.environ.get('API_TOKEN_EXPIRY', '86400'))  # 24 hours default
    
    # CORS settings
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*')
    
    # Terraria paths
    TERRARIA_DIR = os.environ.get('TERRARIA_DIR', '/terraria')
    WORLD_DIR = os.environ.get('WORLD_DIR', '/terraria/worlds')
    BACKUP_DIR = os.environ.get('BACKUP_DIR', '/terraria/backups')
    LOG_DIR = os.environ.get('LOG_DIR', '/terraria/logs')
    SCRIPTS_DIR = os.environ.get('SCRIPTS_DIR', '/terraria/scripts')
    CONFIG_DIR = os.environ.get('CONFIG_DIR', '/terraria/config')
    
    # Script paths
    SERVER_CONTROL_SCRIPT = os.path.join(SCRIPTS_DIR, 'server-control.sh')
    WORLD_MANAGER_SCRIPT = os.path.join(SCRIPTS_DIR, 'world-manager.sh')
    BACKUP_SCRIPT = os.path.join(SCRIPTS_DIR, 'backup.sh')
    RESTORE_SCRIPT = os.path.join(SCRIPTS_DIR, 'restore.sh')
    
    # Server settings (read from environment, same as Terraria server)
    WORLD_NAME = os.environ.get('WORLD_NAME', 'world')
    MAX_PLAYERS = int(os.environ.get('MAX_PLAYERS', '8'))
    SERVER_PORT = int(os.environ.get('SERVER_PORT', '7777'))
    SERVER_PASSWORD = os.environ.get('SERVER_PASSWORD', '')
    MOTD = os.environ.get('MOTD', 'Welcome to the Terraria Server!')
    DIFFICULTY = int(os.environ.get('DIFFICULTY', '0'))
    AUTOCREATE = int(os.environ.get('AUTOCREATE', '2'))
    SECURE = int(os.environ.get('SECURE', '1'))
    
    # Backup settings
    BACKUP_ENABLED = os.environ.get('BACKUP_ENABLED', 'true').lower() == 'true'
    BACKUP_INTERVAL = int(os.environ.get('BACKUP_INTERVAL', '30'))
    BACKUP_RETENTION = int(os.environ.get('BACKUP_RETENTION', '48'))
    
    @classmethod
    def validate(cls):
        """Validate required configuration."""
        errors = []
        
        if not cls.API_PASSWORD:
            errors.append("API_PASSWORD must be set for authentication")
        
        if len(cls.API_PASSWORD) < 8 and cls.API_PASSWORD:
            errors.append("API_PASSWORD should be at least 8 characters")
        
        return errors


class DevelopmentConfig(Config):
    """Development configuration."""
    DEBUG = True


class ProductionConfig(Config):
    """Production configuration."""
    DEBUG = False


def get_config():
    """Get configuration based on environment."""
    env = os.environ.get('FLASK_ENV', 'production')
    if env == 'development':
        return DevelopmentConfig
    return ProductionConfig
