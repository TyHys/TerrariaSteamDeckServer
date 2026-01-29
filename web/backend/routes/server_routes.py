"""
Server control API routes
"""

from flask import request, jsonify
from . import server_bp
from auth import require_auth
from utils import (
    run_command, run_script, is_server_running, is_supervisor_running,
    get_supervisor_status, get_disk_usage, strip_ansi_codes
)
from config import Config


@server_bp.route('/status', methods=['GET'])
@require_auth
def get_status():
    """
    Get current server status.
    
    Response:
        {
            "running": true,
            "supervisor": true,
            "terraria": {
                "state": "RUNNING",
                "running": true,
                "details": "pid 1234, uptime 0:30:00"
            },
            "backup_scheduler": {...},
            "disk": {...}
        }
    """
    supervisor_status = get_supervisor_status()
    server_running = is_server_running()
    
    response = {
        'running': server_running,
        'supervisor': is_supervisor_running(),
        'processes': supervisor_status or {},
        'disk': {
            'worlds': get_disk_usage(Config.WORLD_DIR),
            'backups': get_disk_usage(Config.BACKUP_DIR)
        }
    }
    
    # Add terraria-specific status for convenience
    if supervisor_status and 'terraria' in supervisor_status:
        response['terraria'] = supervisor_status['terraria']
    else:
        response['terraria'] = {
            'state': 'RUNNING' if server_running else 'STOPPED',
            'running': server_running
        }
    
    return jsonify(response), 200


@server_bp.route('/start', methods=['POST'])
@require_auth
def start_server():
    """
    Start the Terraria server.
    
    Response:
        {
            "success": true,
            "message": "Server started"
        }
    """
    if is_server_running():
        return jsonify({
            'success': False,
            'message': 'Server is already running'
        }), 400
    
    success, stdout, stderr = run_command(['supervisorctl', 'start', 'terraria'])
    
    if success or 'already started' in stdout.lower():
        return jsonify({
            'success': True,
            'message': 'Server start command sent',
            'output': strip_ansi_codes(stdout)
        }), 200
    
    return jsonify({
        'success': False,
        'message': 'Failed to start server',
        'error': strip_ansi_codes(stderr or stdout)
    }), 500


@server_bp.route('/stop', methods=['POST'])
@require_auth
def stop_server():
    """
    Stop the Terraria server.
    
    Response:
        {
            "success": true,
            "message": "Server stopped"
        }
    """
    if not is_server_running():
        return jsonify({
            'success': False,
            'message': 'Server is not running'
        }), 400
    
    success, stdout, stderr = run_command(['supervisorctl', 'stop', 'terraria'])
    
    if success or 'already stopped' in stdout.lower():
        return jsonify({
            'success': True,
            'message': 'Server stop command sent. World will be saved.',
            'output': strip_ansi_codes(stdout)
        }), 200
    
    return jsonify({
        'success': False,
        'message': 'Failed to stop server',
        'error': strip_ansi_codes(stderr or stdout)
    }), 500


@server_bp.route('/restart', methods=['POST'])
@require_auth
def restart_server():
    """
    Restart the Terraria server.
    
    Response:
        {
            "success": true,
            "message": "Server restarting"
        }
    """
    success, stdout, stderr = run_command(['supervisorctl', 'restart', 'terraria'])
    
    if success:
        return jsonify({
            'success': True,
            'message': 'Server restart command sent. Players will be disconnected.',
            'output': strip_ansi_codes(stdout)
        }), 200
    
    return jsonify({
        'success': False,
        'message': 'Failed to restart server',
        'error': strip_ansi_codes(stderr or stdout)
    }), 500


@server_bp.route('/health', methods=['GET'])
@require_auth
def health_check():
    """
    Run a comprehensive health check.
    
    Response:
        {
            "healthy": true,
            "checks": {
                "supervisor": {"status": "ok", "message": "Running"},
                "terraria": {"status": "ok", "message": "Running"},
                "disk": {"status": "ok", "message": "500MB free"}
            }
        }
    """
    checks = {}
    overall_healthy = True
    
    # Check Supervisor
    if is_supervisor_running():
        checks['supervisor'] = {'status': 'ok', 'message': 'Running'}
    else:
        checks['supervisor'] = {'status': 'error', 'message': 'Not running'}
        overall_healthy = False
    
    # Check Terraria server
    if is_server_running():
        checks['terraria'] = {'status': 'ok', 'message': 'Running'}
    else:
        checks['terraria'] = {'status': 'warning', 'message': 'Not running'}
    
    # Check backup scheduler
    success, stdout, _ = run_command(['pgrep', '-f', 'backup-scheduler'])
    if success:
        checks['backup_scheduler'] = {'status': 'ok', 'message': 'Running'}
    elif Config.BACKUP_ENABLED:
        checks['backup_scheduler'] = {'status': 'warning', 'message': 'Not running'}
    else:
        checks['backup_scheduler'] = {'status': 'ok', 'message': 'Disabled'}
    
    # Check disk space
    disk_info = get_disk_usage(Config.WORLD_DIR)
    if 'error' not in disk_info:
        free_mb = disk_info['free_bytes'] / (1024 * 1024)
        if free_mb > 500:
            checks['disk'] = {'status': 'ok', 'message': f"{disk_info['free_human']} free"}
        elif free_mb > 100:
            checks['disk'] = {'status': 'warning', 'message': f"{disk_info['free_human']} free (low)"}
        else:
            checks['disk'] = {'status': 'error', 'message': f"{disk_info['free_human']} free (critical)"}
            overall_healthy = False
    else:
        checks['disk'] = {'status': 'error', 'message': disk_info['error']}
        overall_healthy = False
    
    return jsonify({
        'healthy': overall_healthy,
        'checks': checks
    }), 200 if overall_healthy else 503
