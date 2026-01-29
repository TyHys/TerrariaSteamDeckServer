"""
Authentication module for TerrariaSteamDeckServer Web Backend
Provides JWT token-based authentication.
"""

import jwt
import time
from functools import wraps
from flask import request, jsonify, current_app
from config import Config


def generate_token(username: str) -> str:
    """Generate a JWT token for the authenticated user."""
    payload = {
        'sub': username,
        'iat': int(time.time()),
        'exp': int(time.time()) + Config.API_TOKEN_EXPIRY
    }
    return jwt.encode(payload, Config.SECRET_KEY, algorithm='HS256')


def verify_token(token: str) -> dict:
    """
    Verify a JWT token and return the payload.
    Raises jwt.InvalidTokenError on failure.
    """
    return jwt.decode(token, Config.SECRET_KEY, algorithms=['HS256'])


def authenticate(username: str, password: str) -> bool:
    """Verify username and password against configuration."""
    return (
        username == Config.API_USERNAME and 
        password == Config.API_PASSWORD and
        Config.API_PASSWORD  # Ensure password is set
    )


def require_auth(f):
    """
    Decorator to require authentication for API endpoints.
    
    Accepts either:
    - Authorization: Bearer <token>
    - X-API-Token: <token>
    """
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        
        # Check Authorization header (Bearer token)
        auth_header = request.headers.get('Authorization')
        if auth_header and auth_header.startswith('Bearer '):
            token = auth_header[7:]  # Remove 'Bearer ' prefix
        
        # Check X-API-Token header as alternative
        if not token:
            token = request.headers.get('X-API-Token')
        
        if not token:
            return jsonify({
                'error': 'Authentication required',
                'message': 'No token provided. Use Authorization: Bearer <token> or X-API-Token header.'
            }), 401
        
        try:
            payload = verify_token(token)
            # Add user info to request context
            request.current_user = payload.get('sub')
        except jwt.ExpiredSignatureError:
            return jsonify({
                'error': 'Token expired',
                'message': 'Your authentication token has expired. Please log in again.'
            }), 401
        except jwt.InvalidTokenError as e:
            return jsonify({
                'error': 'Invalid token',
                'message': str(e)
            }), 401
        
        return f(*args, **kwargs)
    
    return decorated
