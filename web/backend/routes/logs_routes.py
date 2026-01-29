"""
Logs API routes
"""

import os
from flask import request, jsonify
from . import logs_bp
from auth import require_auth
from config import Config


@logs_bp.route('', methods=['GET'])
@require_auth
def list_logs():
    """
    List available log files.
    
    Response:
        {
            "logs": [
                {
                    "name": "terraria-stdout.log",
                    "type": "server",
                    "size": "1.2M",
                    "modified": 1706443200.0
                }
            ]
        }
    """
    logs = []
    
    log_types = {
        'terraria-stdout.log': 'server',
        'terraria-stderr.log': 'error',
        'supervisord.log': 'supervisor',
        'crashes.log': 'crash',
        'backup.log': 'backup',
        'restore.log': 'restore',
        'world-manager.log': 'world'
    }
    
    if os.path.exists(Config.LOG_DIR):
        for filename in os.listdir(Config.LOG_DIR):
            filepath = os.path.join(Config.LOG_DIR, filename)
            if os.path.isfile(filepath):
                stat = os.stat(filepath)
                
                logs.append({
                    'name': filename,
                    'type': log_types.get(filename, 'other'),
                    'size_bytes': stat.st_size,
                    'size': format_bytes(stat.st_size),
                    'modified': stat.st_mtime
                })
    
    # Sort by modification time (newest first)
    logs.sort(key=lambda l: l['modified'], reverse=True)
    
    return jsonify({
        'logs': logs,
        'count': len(logs),
        'path': Config.LOG_DIR
    }), 200


@logs_bp.route('/<log_type>', methods=['GET'])
@require_auth
def get_log(log_type):
    """
    Get log content.
    
    Path parameters:
        - log_type: One of 'server', 'error', 'supervisor', 'crash', 'backup'
    
    Query parameters:
        - lines: Number of lines to return (default: 100, max: 1000)
        - offset: Start from this line (for pagination)
    
    Response:
        {
            "log_type": "server",
            "filename": "terraria-stdout.log",
            "content": "...",
            "lines": 100,
            "total_lines": 5000
        }
    """
    # Map log types to filenames
    log_files = {
        'server': 'terraria-stdout.log',
        'stdout': 'terraria-stdout.log',
        'error': 'terraria-stderr.log',
        'stderr': 'terraria-stderr.log',
        'supervisor': 'supervisord.log',
        'crash': 'crashes.log',
        'crashes': 'crashes.log',
        'backup': 'backup.log',
        'restore': 'restore.log',
        'world': 'world-manager.log'
    }
    
    if log_type not in log_files:
        return jsonify({
            'error': 'Invalid log type',
            'message': f"Unknown log type: {log_type}",
            'available': list(log_files.keys())
        }), 400
    
    filename = log_files[log_type]
    filepath = os.path.join(Config.LOG_DIR, filename)
    
    if not os.path.exists(filepath):
        return jsonify({
            'log_type': log_type,
            'filename': filename,
            'exists': False,
            'content': '',
            'message': 'Log file does not exist or is empty'
        }), 200
    
    # Get parameters
    lines = min(request.args.get('lines', 100, type=int), 1000)
    offset = max(request.args.get('offset', 0, type=int), 0)
    
    try:
        # Read file and count total lines
        with open(filepath, 'r', errors='replace') as f:
            all_lines = f.readlines()
        
        total_lines = len(all_lines)
        
        # Get requested lines (from the end by default)
        if offset == 0:
            # Return last N lines
            selected_lines = all_lines[-lines:] if lines < total_lines else all_lines
            start_line = max(total_lines - lines, 0)
        else:
            # Return lines from offset
            selected_lines = all_lines[offset:offset + lines]
            start_line = offset
        
        content = ''.join(selected_lines)
        
        return jsonify({
            'log_type': log_type,
            'filename': filename,
            'exists': True,
            'content': content,
            'lines_returned': len(selected_lines),
            'total_lines': total_lines,
            'start_line': start_line,
            'end_line': start_line + len(selected_lines)
        }), 200
        
    except Exception as e:
        return jsonify({
            'error': 'Read failed',
            'message': str(e)
        }), 500


@logs_bp.route('/<log_type>/clear', methods=['POST'])
@require_auth
def clear_log(log_type):
    """
    Clear a log file.
    
    Query parameters:
        - confirm: Set to 'true' to confirm
    
    Response:
        {
            "success": true,
            "message": "Log cleared"
        }
    """
    # Map log types to filenames
    log_files = {
        'crash': 'crashes.log',
        'crashes': 'crashes.log',
        'backup': 'backup.log',
        'restore': 'restore.log',
        'world': 'world-manager.log'
    }
    
    # Only allow clearing certain logs
    if log_type not in log_files:
        return jsonify({
            'error': 'Cannot clear',
            'message': f"Log type '{log_type}' cannot be cleared",
            'clearable': list(log_files.keys())
        }), 400
    
    # Require confirmation
    confirm = request.args.get('confirm', 'false').lower()
    if confirm != 'true':
        return jsonify({
            'error': 'Confirmation required',
            'message': 'Add ?confirm=true to URL to confirm'
        }), 400
    
    filename = log_files[log_type]
    filepath = os.path.join(Config.LOG_DIR, filename)
    
    try:
        # Truncate the file
        with open(filepath, 'w') as f:
            f.write('')
        
        return jsonify({
            'success': True,
            'message': f"Log '{filename}' cleared"
        }), 200
    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'Failed to clear log',
            'error': str(e)
        }), 500


@logs_bp.route('/search', methods=['GET'])
@require_auth
def search_logs():
    """
    Search log files for a pattern.
    
    Query parameters:
        - q: Search query (required)
        - log: Specific log to search (optional, searches all if not specified)
        - limit: Max results (default: 50)
    
    Response:
        {
            "query": "error",
            "results": [
                {
                    "log": "terraria-stderr.log",
                    "line_number": 42,
                    "content": "Error: something went wrong"
                }
            ],
            "count": 1
        }
    """
    query = request.args.get('q', '')
    specific_log = request.args.get('log', '')
    limit = min(request.args.get('limit', 50, type=int), 200)
    
    if not query:
        return jsonify({
            'error': 'Missing query',
            'message': 'Search query is required (use ?q=pattern)'
        }), 400
    
    results = []
    
    if os.path.exists(Config.LOG_DIR):
        for filename in os.listdir(Config.LOG_DIR):
            if specific_log and filename != specific_log:
                continue
            
            filepath = os.path.join(Config.LOG_DIR, filename)
            if not os.path.isfile(filepath):
                continue
            
            try:
                with open(filepath, 'r', errors='replace') as f:
                    for line_num, line in enumerate(f, 1):
                        if query.lower() in line.lower():
                            results.append({
                                'log': filename,
                                'line_number': line_num,
                                'content': line.strip()
                            })
                            
                            if len(results) >= limit:
                                break
            except:
                continue
            
            if len(results) >= limit:
                break
    
    return jsonify({
        'query': query,
        'results': results,
        'count': len(results),
        'limited': len(results) >= limit
    }), 200


def format_bytes(size: int) -> str:
    """Format bytes to human readable string."""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if abs(size) < 1024.0:
            return f"{size:.1f}{unit}"
        size /= 1024.0
    return f"{size:.1f}TB"
