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

check_health() {
    local name="$1"
    local health
    health=$(docker inspect -f '{{.State.Health.Status}}' "$name" 2>/dev/null || echo "none")
    
    case "$health" in
        "healthy")
            echo "✓ $name is healthy"
            return 0
            ;;
        "starting")
            echo "⟳ $name is starting..."
            return 0
            ;;
        "unhealthy")
            echo "✗ $name is unhealthy"
            return 1
            ;;
        "none")
            echo "⚠ $name has no health check"
            return 0
            ;;
        *)
            echo "? $name health status unknown: $health"
            return 1
            ;;
    esac
}

check_port() {
    local port="$1"
    if ss -tulpn 2>/dev/null | grep -q ":$port " || netstat -tuln 2>/dev/null | grep -q ":$port "; then
        echo "✓ Port $port is listening"
        return 0
    else
        echo "⚠ Port $port is NOT listening on host"
        return 1
    fi
}

wait_for_healthy() {
    local container="$1"
    local max_attempts=30
    local attempt=0
    
    echo "⟳ Waiting for $container to be healthy..."
    
    while [ $attempt -lt $max_attempts ]; do
        local health
        health=$(docker inspect -f '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        
        if [ "$health" = "healthy" ]; then
            echo "✓ $container is healthy"
            return 0
        elif [ "$health" = "none" ]; then
            # No health check, just check if running
            if docker inspect -f '{{.State.Running}}' "$container" 2>/dev/null | grep -q "true"; then
                echo "✓ $container is running (no health check)"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    echo "✗ $container did not become healthy in time"
    return 1
}

check_upstream() {
    echo "⟳ Checking if Nginx can reach OpenWebUI..."
    
    # Wait a bit for services to be ready
    sleep 5
    
    # Try to check from host first (more reliable)
    if curl -sf -m 5 http://localhost:3000 >/dev/null 2>&1; then
        echo "✓ OpenWebUI is accessible directly on port 3000"
    else
        echo "⚠ OpenWebUI not accessible on port 3000 yet"
    fi
    
    # Check if nginx can reach open-webui via docker network
    local result
    result=$(docker exec nginx wget --timeout=10 -qO- http://open-webui:8080 2>&1 || echo "FAIL")
    
    if [[ "$result" == "FAIL" ]] || [[ -z "$result" ]]; then
        echo "✗ Nginx cannot reach OpenWebUI at http://open-webui:8080"
        echo "  Checking OpenWebUI logs:"
        docker logs --tail 20 open-webui 2>&1 | grep -i "error\|fail\|exception" || echo "  No obvious errors in logs"
        return 1
    else
        echo "✓ Nginx ↔ OpenWebUI upstream connection works"
        return 0
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
echo "━━━ Health Checks ━━━"
wait_for_healthy "ollama" || all_ok=false
wait_for_healthy "open-webui" || all_ok=false
wait_for_healthy "nginx" || all_ok=false

echo ""
echo "━━━ Network Ports ━━━"
check_port 80 || true  # Non-critical
check_port 3000 || true  # Non-critical
check_port 11434 || true  # Non-critical

echo ""
echo "━━━ Service Connectivity ━━━"
check_upstream || all_ok=false

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$all_ok" = true ]; then
    echo "✅ All checks passed!"
    echo ""
    echo "Access URLs:"
    echo "  → Nginx reverse proxy:         http://$(hostname -I | awk '{print $1}')"
    echo "  → Direct OpenWebUI [DEBUG]:    http://open-webui:8080 (internal only)"
    echo "  → Ollama API [DEBUG]:          http://ollama:11434 (internal only)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 0
else
    echo "⚠️  Some checks failed!"
    echo ""
    echo "Troubleshooting commands:"
    echo "  docker compose logs -f open-webui"
    echo "  docker compose ps"
    echo "  docker inspect open-webui"
    echo "  docker exec -it nginx wget -qO- http://open-webui:8080"
    echo "  docker exec -it nginx wget -qO- http://ollama:11434/api/tags"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    exit 1
fi