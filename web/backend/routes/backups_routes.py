"""
Backups management API routes
"""

import os
import re
from flask import request, jsonify
from . import backups_bp
from auth import require_auth
from utils import (
    run_script, is_server_running, strip_ansi_codes,
    get_file_info, format_bytes
)
from config import Config


def parse_backup_filename(filename):
    """
    Parse backup filename to extract world name and timestamp.
    Format: backup_WORLDNAME_YYYYMMDD_HHMMSS.tar.gz
    """
    match = re.match(r'backup_(.+)_(\d{8})_(\d{6})\.tar(?:\.gz)?$', filename)
    if match:
        return {
            'world_name': match.group(1),
            'date': match.group(2),
            'time': match.group(3)
        }
    return None


@backups_bp.route('', methods=['GET'])
@require_auth
def list_backups():
    """
    List all backups.
    
    Query parameters:
        - world: Filter by world name
        - limit: Maximum number of backups to return
    
    Response:
        {
            "backups": [
                {
                    "filename": "backup_MyWorld_20260128_120000.tar.gz",
                    "world_name": "MyWorld",
                    "size": "15M",
                    "size_bytes": 15728640,
                    "created": 1706443200.0
                }
            ],
            "count": 1,
            "total_size": "15M"
        }
    """
    world_filter = request.args.get('world', '')
    limit = request.args.get('limit', type=int)
    
    backups = []
    total_size = 0
    
    if os.path.exists(Config.BACKUP_DIR):
        for filename in os.listdir(Config.BACKUP_DIR):
            if not filename.startswith('backup_') or not (filename.endswith('.tar.gz') or filename.endswith('.tar')):
                continue
            
            parsed = parse_backup_filename(filename)
            if not parsed:
                continue
            
            # Apply world filter
            if world_filter and parsed['world_name'] != world_filter:
                continue
            
            filepath = os.path.join(Config.BACKUP_DIR, filename)
            info = get_file_info(filepath)
            
            if info:
                total_size += info['size_bytes']
                backups.append({
                    'filename': filename,
                    'world_name': parsed['world_name'],
                    'date': parsed['date'],
                    'time': parsed['time'],
                    'size_bytes': info['size_bytes'],
                    'size': info['size_human'],
                    'created': info['modified']
                })
    
    # Sort by creation time (newest first)
    backups.sort(key=lambda b: b['created'], reverse=True)
    
    # Apply limit
    if limit and limit > 0:
        backups = backups[:limit]
    
    return jsonify({
        'backups': backups,
        'count': len(backups),
        'total_size': format_bytes(total_size),
        'total_size_bytes': total_size,
        'retention': Config.BACKUP_RETENTION
    }), 200


@backups_bp.route('/<filename>', methods=['GET'])
@require_auth
def get_backup(filename):
    """
    Get detailed information about a specific backup.
    
    Response:
        {
            "filename": "backup_MyWorld_20260128_120000.tar.gz",
            "world_name": "MyWorld",
            "size": "15M",
            "created": 1706443200.0,
            "contents": ["MyWorld/MyWorld.wld", "MyWorld/backup_info.txt"]
        }
    """
    # Sanitize filename
    if '..' in filename or '/' in filename:
        return jsonify({
            'error': 'Invalid filename',
            'message': 'Invalid backup filename'
        }), 400
    
    filepath = os.path.join(Config.BACKUP_DIR, filename)
    
    if not os.path.exists(filepath):
        return jsonify({
            'error': 'Backup not found',
            'message': f"Backup '{filename}' does not exist"
        }), 404
    
    info = get_file_info(filepath)
    parsed = parse_backup_filename(filename)
    
    response = {
        'filename': filename,
        'path': filepath,
        'world_name': parsed['world_name'] if parsed else 'unknown',
        'size_bytes': info['size_bytes'],
        'size': info['size_human'],
        'created': info['modified']
    }
    
    # Get archive contents
    import subprocess
    if filename.endswith('.gz'):
        cmd = ['tar', '-tzf', filepath]
    else:
        cmd = ['tar', '-tf', filepath]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        if result.returncode == 0:
            response['contents'] = result.stdout.strip().split('\n')
    except:
        pass
    
    return jsonify(response), 200


@backups_bp.route('', methods=['POST'])
@require_auth
def create_backup():
    """
    Create a manual backup.
    
    Request body:
        {
            "world": "WorldName"  # Optional, backs up all worlds if not specified
        }
    
    Response:
        {
            "success": true,
            "message": "Backup created",
            "backups": [...]
        }
    """
    data = request.get_json() or {}
    world = data.get('world', '')
    
    # Sanitize world name if provided
    if world:
        world = re.sub(r'[^a-zA-Z0-9_-]', '', world)
        
        # Check world exists
        world_path = os.path.join(Config.WORLD_DIR, f'{world}.wld')
        if not os.path.exists(world_path):
            return jsonify({
                'error': 'World not found',
                'message': f"World '{world}' does not exist"
            }), 404
    
    # Run backup script
    args = ['create']
    if world:
        args.append(world)
    
    success, stdout, stderr = run_script(Config.BACKUP_SCRIPT, args, timeout=60)
    
    if success:
        # Get list of created backups (the newest ones)
        new_backups = []
        if os.path.exists(Config.BACKUP_DIR):
            for filename in sorted(os.listdir(Config.BACKUP_DIR), reverse=True)[:5]:
                if filename.startswith('backup_'):
                    filepath = os.path.join(Config.BACKUP_DIR, filename)
                    info = get_file_info(filepath)
                    parsed = parse_backup_filename(filename)
                    if info and parsed:
                        new_backups.append({
                            'filename': filename,
                            'world_name': parsed['world_name'],
                            'size': info['size_human']
                        })
        
        return jsonify({
            'success': True,
            'message': 'Backup created successfully',
            'output': strip_ansi_codes(stdout),
            'backups': new_backups
        }), 201
    
    return jsonify({
        'success': False,
        'message': 'Failed to create backup',
        'error': strip_ansi_codes(stderr or stdout)
    }), 500


@backups_bp.route('/<filename>/restore', methods=['POST'])
@require_auth
def restore_backup(filename):
    """
    Restore a backup.
    
    Query parameters:
        - force: Skip confirmation (set to 'true')
        - no_backup: Don't create pre-restore backup (set to 'true')
    
    Response:
        {
            "success": true,
            "message": "Backup restored"
        }
    """
    # Sanitize filename
    if '..' in filename or '/' in filename:
        return jsonify({
            'error': 'Invalid filename',
            'message': 'Invalid backup filename'
        }), 400
    
    filepath = os.path.join(Config.BACKUP_DIR, filename)
    
    if not os.path.exists(filepath):
        return jsonify({
            'error': 'Backup not found',
            'message': f"Backup '{filename}' does not exist"
        }), 404
    
    # Check if server is running
    if is_server_running():
        return jsonify({
            'error': 'Server running',
            'message': 'Stop the server before restoring a backup'
        }), 400
    
    # Build restore arguments
    args = ['restore', filename, '--force']  # API always uses --force
    
    no_backup = request.args.get('no_backup', 'false').lower() == 'true'
    if no_backup:
        args.append('--no-backup')
    
    success, stdout, stderr = run_script(Config.RESTORE_SCRIPT, args, timeout=60)
    
    if success:
        return jsonify({
            'success': True,
            'message': 'Backup restored successfully',
            'output': strip_ansi_codes(stdout)
        }), 200
    
    return jsonify({
        'success': False,
        'message': 'Failed to restore backup',
        'error': strip_ansi_codes(stderr or stdout)
    }), 500


@backups_bp.route('/<filename>', methods=['DELETE'])
@require_auth
def delete_backup(filename):
    """
    Delete a backup.
    
    Query parameters:
        - confirm: Set to 'true' to confirm deletion
    
    Response:
        {
            "success": true,
            "message": "Backup deleted"
        }
    """
    # Sanitize filename
    if '..' in filename or '/' in filename:
        return jsonify({
            'error': 'Invalid filename',
            'message': 'Invalid backup filename'
        }), 400
    
    filepath = os.path.join(Config.BACKUP_DIR, filename)
    
    if not os.path.exists(filepath):
        return jsonify({
            'error': 'Backup not found',
            'message': f"Backup '{filename}' does not exist"
        }), 404
    
    # Require confirmation
    confirm = request.args.get('confirm', 'false').lower()
    if confirm != 'true':
        return jsonify({
            'error': 'Confirmation required',
            'message': 'Add ?confirm=true to URL to confirm deletion'
        }), 400
    
    try:
        os.remove(filepath)
        return jsonify({
            'success': True,
            'message': f"Backup '{filename}' deleted successfully"
        }), 200
    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'Failed to delete backup',
            'error': str(e)
        }), 500


@backups_bp.route('/cleanup', methods=['POST'])
@require_auth
def cleanup_backups():
    """
    Run backup cleanup (remove old backups based on retention policy).
    
    Response:
        {
            "success": true,
            "message": "Cleanup completed"
        }
    """
    success, stdout, stderr = run_script(Config.BACKUP_SCRIPT, ['cleanup'], timeout=60)
    
    if success:
        return jsonify({
            'success': True,
            'message': 'Backup cleanup completed',
            'output': strip_ansi_codes(stdout)
        }), 200
    
    return jsonify({
        'success': False,
        'message': 'Failed to run cleanup',
        'error': strip_ansi_codes(stderr or stdout)
    }), 500
