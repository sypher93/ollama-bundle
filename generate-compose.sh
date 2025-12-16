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
OUTPUT_FILE="$SCRIPT_DIR/docker-compose.yml"

# Variables should be passed as arguments or environment variables
# Expected: INSTALLATION_MODE, USE_NVIDIA, GPU_COUNT

generate_compose() {
    local nginx_ports=""
    local nginx_volumes=""
    local gpu_config=""
    
    # Configure ports and volumes based on installation mode
    if [ "${INSTALLATION_MODE:-simple}" = "simple" ]; then
        nginx_ports='      - "80:80"'
        nginx_volumes='      - ./conf.d/open-webui.conf:/etc/nginx/conf.d/default.conf:ro'
    else
        nginx_ports='      - "80:80"
      - "443:443"'
        nginx_volumes='      - ./conf.d/open-webui.conf:/etc/nginx/conf.d/default.conf:ro
      - ./ssl:/etc/nginx/ssl:ro'
    fi
    
    # Configure GPU if needed
    if [ "${USE_NVIDIA:-false}" = "true" ]; then
        local gpu_count="${GPU_COUNT:-1}"
        local gpu_indices=""
        for ((i=0; i<gpu_count; i++)); do
            if [ $i -gt 0 ]; then
                gpu_indices+=","
            fi
            gpu_indices+="$i"
        done
        
        gpu_config="    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: $gpu_count
              capabilities: [gpu]
    environment:
      - CUDA_VISIBLE_DEVICES=$gpu_indices"
    fi

    cat > "$OUTPUT_FILE" << EOF
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    restart: unless-stopped
    expose:
      - "11434"
    volumes:
      - ollama:/root/.ollama
$gpu_config
    networks:
      - openwebui-network

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    restart: unless-stopped
    environment:
      - OLLAMA_BASE_URL=http://ollama:11434
      - WEBUI_SECRET_KEY=\${WEBUI_SECRET_KEY:-$(openssl rand -base64 32)}
    expose:
      - "8080"
    volumes:
      - open-webui:/app/backend/data
    networks:
      - openwebui-network
    depends_on:
      - ollama

  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    ports:
$nginx_ports
    volumes:
$nginx_volumes
    networks:
      - openwebui-network
    depends_on:
      - open-webui

networks:
  openwebui-network:
    driver: bridge

volumes:
  ollama:
    driver: local
  open-webui:
    driver: local
EOF
}

generate_compose
echo "✓ Docker Compose file generated: $OUTPUT_FILE"