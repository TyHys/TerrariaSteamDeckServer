"""
Configuration API routes
"""

import os
from flask import request, jsonify
from . import config_bp
from auth import require_auth
from config import Config


@config_bp.route('', methods=['GET'])
@require_auth
def get_config():
    """
    Get current server configuration.
    
    Response:
        {
            "server": {
                "world_name": "world",
                "max_players": 8,
                "port": 7777,
                "has_password": false,
                "motd": "Welcome!",
                "difficulty": 0,
                "autocreate": 2,
                "secure": 1
            },
            "backup": {
                "enabled": true,
                "interval": 30,
                "retention": 48
            },
            "paths": {
                "worlds": "/terraria/worlds",
                "backups": "/terraria/backups",
                "logs": "/terraria/logs"
            }
        }
    """
    return jsonify({
        'server': {
            'world_name': Config.WORLD_NAME,
            'max_players': Config.MAX_PLAYERS,
            'port': Config.SERVER_PORT,
            'has_password': bool(Config.SERVER_PASSWORD),
            'motd': Config.MOTD,
            'difficulty': Config.DIFFICULTY,
            'difficulty_name': get_difficulty_name(Config.DIFFICULTY),
            'autocreate': Config.AUTOCREATE,
            'autocreate_name': get_world_size_name(Config.AUTOCREATE),
            'secure': Config.SECURE
        },
        'backup': {
            'enabled': Config.BACKUP_ENABLED,
            'interval': Config.BACKUP_INTERVAL,
            'retention': Config.BACKUP_RETENTION
        },
        'paths': {
            'worlds': Config.WORLD_DIR,
            'backups': Config.BACKUP_DIR,
            'logs': Config.LOG_DIR,
            'config': Config.CONFIG_DIR
        }
    }), 200


@config_bp.route('', methods=['PUT'])
@require_auth
def update_config():
    """
    Update server configuration.
    
    Note: Changes are applied to environment variables and will take effect
    on next server restart. Some settings require regenerating the config file.
    
    Request body:
        {
            "max_players": 16,
            "motd": "New message",
            "password": "new_password"
        }
    
    Response:
        {
            "success": true,
            "message": "Configuration updated",
            "restart_required": true
        }
    """
    data = request.get_json()
    
    if not data:
        return jsonify({
            'error': 'Invalid request',
            'message': 'Request body must be JSON'
        }), 400
    
    # Track what was updated
    updated = []
    restart_required = False
    
    # Allowed configuration updates
    allowed_updates = {
        'max_players': ('MAX_PLAYERS', int, 1, 255),
        'motd': ('MOTD', str, 0, 500),
        'password': ('SERVER_PASSWORD', str, 0, 64),
        'difficulty': ('DIFFICULTY', int, 0, 3),
        'autocreate': ('AUTOCREATE', int, 1, 3),
        'secure': ('SECURE', int, 0, 1),
        'backup_enabled': ('BACKUP_ENABLED', bool, None, None),
        'backup_interval': ('BACKUP_INTERVAL', int, 1, 1440),
        'backup_retention': ('BACKUP_RETENTION', int, 1, 1000)
    }
    
    for key, value in data.items():
        if key not in allowed_updates:
            continue
        
        env_key, value_type, min_val, max_val = allowed_updates[key]
        
        try:
            if value_type == bool:
                typed_value = bool(value)
                os.environ[env_key] = 'true' if typed_value else 'false'
            elif value_type == int:
                typed_value = int(value)
                if min_val is not None and typed_value < min_val:
                    typed_value = min_val
                if max_val is not None and typed_value > max_val:
                    typed_value = max_val
                os.environ[env_key] = str(typed_value)
            else:
                typed_value = str(value)
                if max_val is not None and len(typed_value) > max_val:
                    typed_value = typed_value[:max_val]
                os.environ[env_key] = typed_value
            
            updated.append(key)
            
            # Mark restart required for game settings
            if key in ['max_players', 'motd', 'password', 'difficulty', 'autocreate', 'secure']:
                restart_required = True
                
        except (ValueError, TypeError):
            pass
    
    if not updated:
        return jsonify({
            'success': False,
            'message': 'No valid configuration options provided'
        }), 400
    
    return jsonify({
        'success': True,
        'message': f"Updated: {', '.join(updated)}",
        'updated': updated,
        'restart_required': restart_required
    }), 200


@config_bp.route('/runtime', methods=['GET'])
@require_auth
def get_runtime_config():
    """
    Get the current runtime server configuration file content.
    
    Response:
        {
            "exists": true,
            "content": "..."
        }
    """
    runtime_config_path = os.path.join(Config.CONFIG_DIR, 'serverconfig-runtime.txt')
    
    if not os.path.exists(runtime_config_path):
        return jsonify({
            'exists': False,
            'message': 'Runtime config not yet generated'
        }), 200
    
    try:
        with open(runtime_config_path, 'r') as f:
            content = f.read()
        
        return jsonify({
            'exists': True,
            'path': runtime_config_path,
            'content': content
        }), 200
    except Exception as e:
        return jsonify({
            'error': 'Read failed',
            'message': str(e)
        }), 500


def get_difficulty_name(difficulty: int) -> str:
    """Convert difficulty code to name."""
    names = {
        0: 'Classic',
        1: 'Expert',
        2: 'Master',
        3: 'Journey'
    }
    return names.get(difficulty, 'Unknown')


def get_world_size_name(size: int) -> str:
    """Convert world size code to name."""
    names = {
        1: 'Small',
        2: 'Medium',
        3: 'Large'
    }
    return names.get(size, 'Unknown')
