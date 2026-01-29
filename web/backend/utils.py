"""
Utility functions for TerrariaSteamDeckServer Web Backend
Provides helpers for running scripts and parsing output.
"""

import subprocess
import os
import re
from typing import Tuple, Optional, Dict, Any
from config import Config


def run_script(script_path: str, args: list = None, timeout: int = 30) -> Tuple[bool, str, str]:
    """
    Run a shell script and return the result.
    
    Args:
        script_path: Path to the script to execute
        args: Optional list of arguments
        timeout: Timeout in seconds
    
    Returns:
        Tuple of (success, stdout, stderr)
    """
    if not os.path.exists(script_path):
        return False, '', f'Script not found: {script_path}'
    
    cmd = [script_path]
    if args:
        cmd.extend(args)
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, 'TERM': 'dumb'}  # Disable color codes
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, '', f'Script timed out after {timeout} seconds'
    except Exception as e:
        return False, '', str(e)


def run_command(cmd: list, timeout: int = 30) -> Tuple[bool, str, str]:
    """
    Run a command and return the result.
    
    Args:
        cmd: Command and arguments as list
        timeout: Timeout in seconds
    
    Returns:
        Tuple of (success, stdout, stderr)
    """
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, 'TERM': 'dumb'}
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, '', f'Command timed out after {timeout} seconds'
    except Exception as e:
        return False, '', str(e)


def is_server_running() -> bool:
    """Check if the Terraria server process is running."""
    success, stdout, _ = run_command(['pgrep', '-f', 'TerrariaServer'])
    return success and stdout.strip()


def is_supervisor_running() -> bool:
    """Check if Supervisor is running."""
    return os.path.exists('/tmp/supervisor.sock')


def get_supervisor_status() -> Optional[Dict[str, Any]]:
    """Get Supervisor status for all programs."""
    success, stdout, _ = run_command(['supervisorctl', 'status'])
    if not success:
        return None
    
    programs = {}
    for line in stdout.strip().split('\n'):
        if not line.strip():
            continue
        # Parse: "program_name    STATE   ..."
        parts = line.split()
        if len(parts) >= 2:
            name = parts[0]
            state = parts[1]
            programs[name] = {
                'state': state,
                'running': state == 'RUNNING',
                'details': ' '.join(parts[2:]) if len(parts) > 2 else ''
            }
    
    return programs


def strip_ansi_codes(text: str) -> str:
    """Remove ANSI color codes from text."""
    ansi_escape = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')
    return ansi_escape.sub('', text)


def parse_world_list(output: str) -> list:
    """Parse world list output into structured data."""
    worlds = []
    lines = output.strip().split('\n')
    
    in_table = False
    for line in lines:
        line = strip_ansi_codes(line).strip()
        
        # Skip header lines
        if 'NAME' in line and 'SIZE' in line:
            in_table = True
            continue
        if line.startswith('---') or not line:
            continue
        if 'No worlds found' in line:
            break
        if line.startswith('Total:'):
            break
        
        if in_table and line:
            # Parse table row: NAME SIZE LAST_MODIFIED
            parts = line.split()
            if len(parts) >= 3:
                worlds.append({
                    'name': parts[0],
                    'size': parts[1],
                    'modified': ' '.join(parts[2:])
                })
    
    return worlds


def parse_backup_list(output: str) -> list:
    """Parse backup list output into structured data."""
    backups = []
    lines = output.strip().split('\n')
    
    in_table = False
    for line in lines:
        line = strip_ansi_codes(line).strip()
        
        # Skip header lines
        if 'BACKUP FILE' in line:
            in_table = True
            continue
        if line.startswith('---') or not line:
            continue
        if 'No backups found' in line:
            break
        if line.startswith('Total:') or line.startswith('Retention'):
            break
        
        if in_table and line:
            # Parse table row: BACKUP_FILE SIZE CREATED
            parts = line.split()
            if len(parts) >= 3:
                backups.append({
                    'filename': parts[0],
                    'size': parts[1],
                    'created': ' '.join(parts[2:])
                })
    
    return backups


def get_disk_usage(path: str) -> Dict[str, Any]:
    """Get disk usage information for a path."""
    try:
        stat = os.statvfs(path)
        total = stat.f_blocks * stat.f_frsize
        free = stat.f_bfree * stat.f_frsize
        used = total - free
        
        return {
            'total_bytes': total,
            'used_bytes': used,
            'free_bytes': free,
            'total_human': format_bytes(total),
            'used_human': format_bytes(used),
            'free_human': format_bytes(free),
            'percent_used': round((used / total) * 100, 1) if total > 0 else 0
        }
    except Exception as e:
        return {'error': str(e)}


def format_bytes(size: int) -> str:
    """Format bytes to human readable string."""
    for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
        if abs(size) < 1024.0:
            return f"{size:.1f}{unit}"
        size /= 1024.0
    return f"{size:.1f}PB"


def get_file_info(filepath: str) -> Optional[Dict[str, Any]]:
    """Get information about a file."""
    if not os.path.exists(filepath):
        return None
    
    stat = os.stat(filepath)
    return {
        'path': filepath,
        'name': os.path.basename(filepath),
        'size_bytes': stat.st_size,
        'size_human': format_bytes(stat.st_size),
        'modified': stat.st_mtime,
        'created': stat.st_ctime
    }
