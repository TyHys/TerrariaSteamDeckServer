"""
Worlds management API routes
"""

import os
import re
from flask import request, jsonify
from . import worlds_bp
from auth import require_auth
from utils import (
    run_script, run_command, is_server_running, strip_ansi_codes,
    parse_world_list, get_file_info, format_bytes
)
from config import Config


@worlds_bp.route('', methods=['GET'])
@require_auth
def list_worlds():
    """
    List all available worlds.
    
    Response:
        {
            "worlds": [
                {
                    "name": "MyWorld",
                    "size": "15M",
                    "size_bytes": 15728640,
                    "modified": "2026-01-28 12:00"
                }
            ],
            "count": 1
        }
    """
    worlds = []
    
    if os.path.exists(Config.WORLD_DIR):
        for filename in os.listdir(Config.WORLD_DIR):
            if filename.endswith('.wld'):
                filepath = os.path.join(Config.WORLD_DIR, filename)
                info = get_file_info(filepath)
                if info:
                    world_name = filename[:-4]  # Remove .wld extension
                    
                    # Check for backup file
                    has_backup = os.path.exists(filepath + '.bak')
                    
                    worlds.append({
                        'name': world_name,
                        'filename': filename,
                        'size_bytes': info['size_bytes'],
                        'size': info['size_human'],
                        'modified': info['modified'],
                        'has_backup': has_backup
                    })
    
    # Sort by name
    worlds.sort(key=lambda w: w['name'].lower())
    
    return jsonify({
        'worlds': worlds,
        'count': len(worlds)
    }), 200


@worlds_bp.route('/<name>', methods=['GET'])
@require_auth
def get_world(name):
    """
    Get detailed information about a specific world.
    
    Response:
        {
            "name": "MyWorld",
            "filename": "MyWorld.wld",
            "size_bytes": 15728640,
            "size": "15M",
            "modified": 1706443200.0,
            "has_backup": true,
            "backup_size": "15M"
        }
    """
    # Sanitize name
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    
    filepath = os.path.join(Config.WORLD_DIR, f'{name}.wld')
    
    if not os.path.exists(filepath):
        return jsonify({
            'error': 'World not found',
            'message': f"World '{name}' does not exist"
        }), 404
    
    info = get_file_info(filepath)
    
    response = {
        'name': name,
        'filename': f'{name}.wld',
        'path': filepath,
        'size_bytes': info['size_bytes'],
        'size': info['size_human'],
        'modified': info['modified'],
        'created': info['created'],
        'has_backup': False
    }
    
    # Check for backup file
    bak_filepath = filepath + '.bak'
    if os.path.exists(bak_filepath):
        bak_info = get_file_info(bak_filepath)
        response['has_backup'] = True
        response['backup_size'] = bak_info['size_human']
        response['backup_modified'] = bak_info['modified']
    
    return jsonify(response), 200


@worlds_bp.route('', methods=['POST'])
@require_auth
def create_world():
    """
    Create a new world.
    
    Request body:
        {
            "name": "MyNewWorld",
            "size": 2,           # 1=Small, 2=Medium, 3=Large
            "difficulty": 0,     # 0=Classic, 1=Expert, 2=Master, 3=Journey
            "seed": "optional"   # World seed (optional)
        }
    
    Response:
        {
            "success": true,
            "message": "World created",
            "world": { ... }
        }
    """
    data = request.get_json()
    
    if not data:
        return jsonify({
            'error': 'Invalid request',
            'message': 'Request body must be JSON'
        }), 400
    
    name = data.get('name', '')
    size = data.get('size', 2)
    difficulty = data.get('difficulty', 0)
    seed = data.get('seed', '')
    
    if not name:
        return jsonify({
            'error': 'Missing parameter',
            'message': 'World name is required'
        }), 400
    
    # Sanitize name
    sanitized_name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    if not sanitized_name:
        return jsonify({
            'error': 'Invalid name',
            'message': 'World name must contain at least one alphanumeric character'
        }), 400
    
    # Check if world exists
    filepath = os.path.join(Config.WORLD_DIR, f'{sanitized_name}.wld')
    if os.path.exists(filepath):
        return jsonify({
            'error': 'World exists',
            'message': f"World '{sanitized_name}' already exists"
        }), 409
    
    # Validate size and difficulty
    if size not in [1, 2, 3]:
        size = 2
    if difficulty not in [0, 1, 2, 3]:
        difficulty = 0
    
    # Create world using environment variables and script
    env = os.environ.copy()
    env['WORLD_NAME'] = sanitized_name
    env['AUTOCREATE'] = str(size)
    env['DIFFICULTY'] = str(difficulty)
    if seed:
        env['WORLD_SEED'] = seed
    
    # Run world creation (this can take a while)
    success, stdout, stderr = run_script(
        Config.WORLD_MANAGER_SCRIPT,
        ['create-auto'],
        timeout=300  # 5 minutes for world generation
    )
    
    # Check if world was created
    if os.path.exists(filepath):
        info = get_file_info(filepath)
        return jsonify({
            'success': True,
            'message': f"World '{sanitized_name}' created successfully",
            'world': {
                'name': sanitized_name,
                'size': info['size_human'],
                'size_code': size,
                'difficulty': difficulty
            }
        }), 201
    
    return jsonify({
        'success': False,
        'message': 'Failed to create world',
        'error': strip_ansi_codes(stderr or stdout)
    }), 500


@worlds_bp.route('/<name>', methods=['DELETE'])
@require_auth
def delete_world(name):
    """
    Delete a world.
    
    Query parameters:
        - confirm: Set to world name to confirm deletion
    
    Response:
        {
            "success": true,
            "message": "World deleted"
        }
    """
    # Sanitize name
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    
    filepath = os.path.join(Config.WORLD_DIR, f'{name}.wld')
    
    if not os.path.exists(filepath):
        return jsonify({
            'error': 'World not found',
            'message': f"World '{name}' does not exist"
        }), 404
    
    # Require confirmation
    confirm = request.args.get('confirm', '')
    if confirm != name:
        return jsonify({
            'error': 'Confirmation required',
            'message': f"Add ?confirm={name} to URL to confirm deletion"
        }), 400
    
    # Check if this is the active world
    if name == Config.WORLD_NAME and is_server_running():
        return jsonify({
            'error': 'Cannot delete active world',
            'message': 'Stop the server before deleting the active world'
        }), 400
    
    try:
        # Delete world file
        os.remove(filepath)
        
        # Delete backup file if exists
        bak_filepath = filepath + '.bak'
        if os.path.exists(bak_filepath):
            os.remove(bak_filepath)
        
        return jsonify({
            'success': True,
            'message': f"World '{name}' deleted successfully"
        }), 200
    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'Failed to delete world',
            'error': str(e)
        }), 500


@worlds_bp.route('/<name>/copy', methods=['POST'])
@require_auth
def copy_world(name):
    """
    Copy a world to a new name.
    
    Request body:
        {
            "destination": "NewWorldName"
        }
    
    Response:
        {
            "success": true,
            "message": "World copied",
            "world": { ... }
        }
    """
    # Sanitize source name
    name = re.sub(r'[^a-zA-Z0-9_-]', '', name)
    
    src_filepath = os.path.join(Config.WORLD_DIR, f'{name}.wld')
    
    if not os.path.exists(src_filepath):
        return jsonify({
            'error': 'World not found',
            'message': f"Source world '{name}' does not exist"
        }), 404
    
    data = request.get_json()
    if not data or not data.get('destination'):
        return jsonify({
            'error': 'Missing parameter',
            'message': 'Destination name is required'
        }), 400
    
    # Sanitize destination name
    dest_name = re.sub(r'[^a-zA-Z0-9_-]', '', data['destination'])
    if not dest_name:
        return jsonify({
            'error': 'Invalid name',
            'message': 'Destination name must contain at least one alphanumeric character'
        }), 400
    
    dest_filepath = os.path.join(Config.WORLD_DIR, f'{dest_name}.wld')
    
    if os.path.exists(dest_filepath):
        return jsonify({
            'error': 'World exists',
            'message': f"Destination world '{dest_name}' already exists"
        }), 409
    
    try:
        import shutil
        
        # Copy world file
        shutil.copy2(src_filepath, dest_filepath)
        
        # Copy backup file if exists
        src_bak = src_filepath + '.bak'
        if os.path.exists(src_bak):
            shutil.copy2(src_bak, dest_filepath + '.bak')
        
        info = get_file_info(dest_filepath)
        
        return jsonify({
            'success': True,
            'message': f"World '{name}' copied to '{dest_name}'",
            'world': {
                'name': dest_name,
                'size': info['size_human'],
                'modified': info['modified']
            }
        }), 201
    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'Failed to copy world',
            'error': str(e)
        }), 500
