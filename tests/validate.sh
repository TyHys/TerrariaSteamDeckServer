#!/bin/bash
#---------------------------------------------------------------
# TerrariaSteamDeckServer Validation Script
# Performs basic validation checks on the codebase
#---------------------------------------------------------------

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

passed=0
failed=0
warnings=0

print_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((passed++))
}

print_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((failed++))
}

print_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((warnings++))
}

echo ""
echo "=========================================="
echo "TerrariaSteamDeckServer Validation"
echo "=========================================="
echo ""

#---------------------------------------------------------------
# Check required files exist
#---------------------------------------------------------------
echo "Checking required files..."

required_files=(
    "docker/Dockerfile"
    "docker/docker-compose.yml"
    "server/scripts/entrypoint.sh"
    "server/scripts/healthcheck.sh"
    "server/scripts/terraria-wrapper.sh"
    "server/scripts/backup.sh"
    "server/scripts/restore.sh"
    "server/scripts/backup-scheduler.sh"
    "server/scripts/server-control.sh"
    "server/scripts/world-manager.sh"
    "server/config/supervisord.conf"
    "server/config/serverconfig.txt"
    "server/config/logrotate.conf"
    "web/backend/app.py"
    "web/backend/config.py"
    "web/backend/auth.py"
    "web/backend/utils.py"
    "web/backend/requirements.txt"
    "web/frontend/index.html"
    "web/frontend/css/styles.css"
    "web/frontend/js/api.js"
    "web/frontend/js/app.js"
    ".env.example"
    "Makefile"
    "README.md"
    "docs/SETUP.md"
    "docs/CONFIGURATION.md"
    "docs/NETWORKING.md"
    "docs/TROUBLESHOOTING.md"
)

for file in "${required_files[@]}"; do
    if [ -f "${PROJECT_DIR}/${file}" ]; then
        print_pass "File exists: ${file}"
    else
        print_fail "Missing file: ${file}"
    fi
done

echo ""

#---------------------------------------------------------------
# Check shell scripts syntax
#---------------------------------------------------------------
echo "Checking shell script syntax..."

for script in "${PROJECT_DIR}"/server/scripts/*.sh; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            print_pass "Valid syntax: $(basename "$script")"
        else
            print_fail "Invalid syntax: $(basename "$script")"
        fi
    fi
done

echo ""

#---------------------------------------------------------------
# Check Python syntax
#---------------------------------------------------------------
echo "Checking Python syntax..."

if command -v python3 &> /dev/null; then
    for pyfile in "${PROJECT_DIR}"/web/backend/*.py; do
        if [ -f "$pyfile" ]; then
            if python3 -m py_compile "$pyfile" 2>/dev/null; then
                print_pass "Valid syntax: $(basename "$pyfile")"
            else
                print_fail "Invalid syntax: $(basename "$pyfile")"
            fi
        fi
    done
    
    for pyfile in "${PROJECT_DIR}"/web/backend/routes/*.py; do
        if [ -f "$pyfile" ]; then
            if python3 -m py_compile "$pyfile" 2>/dev/null; then
                print_pass "Valid syntax: $(basename "$pyfile")"
            else
                print_fail "Invalid syntax: $(basename "$pyfile")"
            fi
        fi
    done
else
    print_warn "Python3 not found, skipping Python syntax check"
fi

echo ""

#---------------------------------------------------------------
# Check directory structure
#---------------------------------------------------------------
echo "Checking directory structure..."

required_dirs=(
    "docker"
    "server/scripts"
    "server/config"
    "web/backend"
    "web/backend/routes"
    "web/frontend"
    "web/frontend/css"
    "web/frontend/js"
    "data"
    "docs"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "${PROJECT_DIR}/${dir}" ]; then
        print_pass "Directory exists: ${dir}"
    else
        print_fail "Missing directory: ${dir}"
    fi
done

echo ""

#---------------------------------------------------------------
# Check .env.example has required settings
#---------------------------------------------------------------
echo "Checking .env.example configuration..."

if grep -q "API_PASSWORD" "${PROJECT_DIR}/.env.example"; then
    print_pass "API_PASSWORD documented in .env.example"
else
    print_fail "API_PASSWORD missing from .env.example"
fi

if grep -q "WORLD_NAME" "${PROJECT_DIR}/.env.example"; then
    print_pass "WORLD_NAME documented in .env.example"
else
    print_fail "WORLD_NAME missing from .env.example"
fi

if grep -q "BACKUP_ENABLED" "${PROJECT_DIR}/.env.example"; then
    print_pass "BACKUP_ENABLED documented in .env.example"
else
    print_fail "BACKUP_ENABLED missing from .env.example"
fi

echo ""

#---------------------------------------------------------------
# Check Dockerfile health check
#---------------------------------------------------------------
echo "Checking Dockerfile..."

if grep -q "HEALTHCHECK" "${PROJECT_DIR}/docker/Dockerfile"; then
    print_pass "Health check configured in Dockerfile"
else
    print_fail "Health check missing from Dockerfile"
fi

if grep -q "EXPOSE 7777" "${PROJECT_DIR}/docker/Dockerfile"; then
    print_pass "Port 7777 exposed in Dockerfile"
else
    print_fail "Port 7777 not exposed in Dockerfile"
fi

if grep -q "EXPOSE 8080" "${PROJECT_DIR}/docker/Dockerfile"; then
    print_pass "Port 8080 exposed in Dockerfile"
else
    print_fail "Port 8080 not exposed in Dockerfile"
fi

echo ""

#---------------------------------------------------------------
# Summary
#---------------------------------------------------------------
echo "=========================================="
echo "Validation Summary"
echo "=========================================="
echo -e "  ${GREEN}Passed${NC}:   ${passed}"
echo -e "  ${RED}Failed${NC}:   ${failed}"
echo -e "  ${YELLOW}Warnings${NC}: ${warnings}"
echo ""

if [ ${failed} -eq 0 ]; then
    echo -e "${GREEN}All validation checks passed!${NC}"
    exit 0
else
    echo -e "${RED}Some validation checks failed.${NC}"
    exit 1
fi
