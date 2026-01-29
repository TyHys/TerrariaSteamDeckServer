"""
Authentication API routes
"""

from flask import request, jsonify
from . import auth_bp
from auth import authenticate, generate_token, verify_token, require_auth
import jwt


@auth_bp.route('/login', methods=['POST'])
def login():
    """
    Authenticate and receive a JWT token.
    
    Request body:
        {
            "username": "admin",
            "password": "your_password"
        }
    
    Response:
        {
            "token": "jwt_token_here",
            "expires_in": 86400
        }
    """
    data = request.get_json()
    
    if not data:
        return jsonify({
            'error': 'Invalid request',
            'message': 'Request body must be JSON'
        }), 400
    
    username = data.get('username', '')
    password = data.get('password', '')
    
    if not username or not password:
        return jsonify({
            'error': 'Missing credentials',
            'message': 'Username and password are required'
        }), 400
    
    if authenticate(username, password):
        token = generate_token(username)
        from config import Config
        return jsonify({
            'token': token,
            'expires_in': Config.API_TOKEN_EXPIRY,
            'username': username
        }), 200
    
    return jsonify({
        'error': 'Authentication failed',
        'message': 'Invalid username or password'
    }), 401


@auth_bp.route('/verify', methods=['GET'])
@require_auth
def verify():
    """
    Verify the current token is valid.
    
    Response:
        {
            "valid": true,
            "username": "admin"
        }
    """
    return jsonify({
        'valid': True,
        'username': request.current_user
    }), 200


@auth_bp.route('/refresh', methods=['POST'])
@require_auth
def refresh():
    """
    Refresh the current token.
    
    Response:
        {
            "token": "new_jwt_token_here",
            "expires_in": 86400
        }
    """
    token = generate_token(request.current_user)
    from config import Config
    return jsonify({
        'token': token,
        'expires_in': Config.API_TOKEN_EXPIRY,
        'username': request.current_user
    }), 200
