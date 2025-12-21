#!/usr/bin/env bash

# -----------------------------
#
# Copyright (c) 2025 sypher93
# Author: sypher93
# License: MIT
# https://github.com/sypher93
#
# Modular installation script for Nginx + OpenWebUI + Ollama
#
# -----------------------------

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Post-installation verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Functions
check_container() {
    local name="$1"
    if docker inspect "$name" &>/dev/null; then
        echo "✓ Container $name exists"
        return 0
    else
        echo "✗ Container $name does not exist"
        return 1
    fi
}

check_running() {
    local name="$1"
    local status
    status=$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo false)

    if [[ "$status" == "true" ]]; then
        echo "✓ $name is running"
        return 0
    else
        echo "✗ $name is NOT running"
        return 1
    fi
}

check_service_internal() {
    local container="$1"
    local url="$2"
    local name="$3"
    
    if docker exec "$container" curl -sf "$url" >/dev/null 2>&1; then
        echo "✓ $name is responding"
        return 0
    else
        echo "⚠ $name may still be starting"
        return 1
    fi
}

check_nginx_public() {
    local protocol="${1:-http}"
    
    if curl -sf -k "${protocol}://localhost" >/dev/null 2>&1; then
        echo "✓ Nginx is accessible from host"
        return 0
    else
        echo "✗ Nginx is NOT accessible from host"
        return 1
    fi
}

# Main checks
echo "━━━ Container Status ━━━"
all_ok=true

check_container "ollama" || all_ok=false
check_container "open-webui" || all_ok=false
check_container "nginx" || all_ok=false

echo ""
echo "━━━ Running State ━━━"
check_running "ollama" || all_ok=false
check_running "open-webui" || all_ok=false
check_running "nginx" || all_ok=false

echo ""
echo "━━━ Service Health ━━━"
check_service_internal "ollama" "http://localhost:11434/api/tags" "Ollama API" || all_ok=false
check_service_internal "open-webui" "http://localhost:8080" "OpenWebUI" || all_ok=false
check_nginx_public "http" || all_ok=false

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$all_ok" = true ]; then
    echo "✅ All checks passed!"
    echo ""
    echo "Access your installation at:"
    echo "  → http://$(hostname -I | awk '{print $1}')"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "⚠️  Some checks had issues (may be normal during startup)"
    echo ""
    echo "Troubleshooting:"
    echo "  - Wait 1-2 minutes and check: curl http://localhost"
    echo "  - View logs: docker compose logs -f"
    echo "  - Check status: docker compose ps"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
fi