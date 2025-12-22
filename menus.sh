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

select_installation_mode() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Installation Mode Selection"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Choose installation mode:"
    echo "  1) Simple (HTTP, root user, no SSL)"
    echo "  2) Advanced (HTTPS, dedicated user, SSL certificates)"
    echo ""
    
    while true; do
        read -rp "Enter your choice [1-2]: " choice
        case "$choice" in
            1)
                INSTALLATION_MODE="simple"
                CREATE_NON_ROOT_USER=false
                echo "✓ Selected: Simple installation mode"
                break
                ;;
            2)
                INSTALLATION_MODE="advanced"
                CREATE_NON_ROOT_USER=true
                echo "✓ Selected: Advanced installation mode"
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1 or 2."
                ;;
        esac
    done
    echo ""
}

prompt_configuration() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Configuration Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Get domain/IP
    while true; do
        read -rp "Enter your server's IPv4 address or domain: " DOMAIN
        if [[ -n "$DOMAIN" ]]; then
            echo "✓ Domain/IP set to: $DOMAIN"
            break
        else
            echo "Domain/IP cannot be empty"
        fi
    done
    echo ""
    
    # SSL certificate details (only for advanced mode)
    if [ "$INSTALLATION_MODE" = "advanced" ]; then
        echo "SSL Certificate Details:"
        read -rp "Country code (C) [US]: " input_country
        COUNTRY=${input_country:-US}
        
        read -rp "State (ST) [California]: " input_state
        STATE=${input_state:-California}
        
        read -rp "City (L) [San Francisco]: " input_city
        CITY=${input_city:-San Francisco}
        
        read -rp "Organization (O) [MyOrg]: " input_org
        ORG=${input_org:-MyOrg}
        
        read -rp "Organizational Unit (OU) [IT]: " input_ou
        ORG_UNIT=${input_ou:-IT}
        
        echo "✓ SSL certificate details configured"
        echo ""
    fi
    
    # GPU configuration
    if lspci 2>/dev/null | grep -i nvidia &> /dev/null; then
        echo "NVIDIA GPU detected on system"
        read -rp "Do you want to use NVIDIA GPU acceleration? [y/N]: " use_gpu
        if [[ "$use_gpu" =~ ^[Yy]$ ]]; then
            USE_NVIDIA=true
            while true; do
                read -rp "How many GPUs do you want to use? [1]: " gpu_input
                GPU_COUNT=${gpu_input:-1}
                if [[ "$GPU_COUNT" =~ ^[0-9]+$ ]] && [ "$GPU_COUNT" -gt 0 ]; then
                    echo "✓ GPU count set to: $GPU_COUNT"
                    break
                else
                    echo "Please enter a valid positive number"
                fi
            done
        else
            echo "✓ GPU acceleration disabled"
        fi
        echo ""
    else
        echo "No NVIDIA GPU detected, skipping GPU configuration"
        echo ""
    fi
    
    echo "✓ Configuration completed"
    echo ""
}

prompt_ollama_api_exposure() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Ollama API Configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Do you want to expose the Ollama API on the host?"
    echo ""
    echo "  • No (default):  API accessible only via Docker network (recommended for security)"
    echo "  • Yes:           API accessible on host at port 11434 (allows external tools to connect)"
    echo ""
    
    read -rp "Expose Ollama API on host? [y/N]: " expose_api
    if [[ "$expose_api" =~ ^[Yy]$ ]]; then
        EXPOSE_OLLAMA_API=true
        echo "✓ Ollama API will be exposed on port 11434"
    else
        EXPOSE_OLLAMA_API=false
        echo "✓ Ollama API will remain internal (Docker network only)"
    fi
    echo ""
}