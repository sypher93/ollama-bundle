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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This installer must be run as root or with sudo" >&2
    exit 1
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/installation_$(date +'%Y-%m-%d_%H-%M-%S').log"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Display banner
clear
cat <<"EOF"
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                      .__                  ________________  
  _________.__.______ |  |__   ___________/   __   \_____  \ 
 /  ___<   |  |\____ \|  |  \_/ __ \_  __ \____    / _(__  < 
 \___ \ \___  ||  |_> >   Y  \  ___/|  | \/  /    / /       \
/____  >/ ____||   __/|___|  /\___  >__|    /____/ /______  /
     \/ \/     |__|        \/     \/                      \/ 
                                                                               
  Nginx + OpenWebUI + Ollama Bundle Installer
  Modular Version with Enhanced Error Handling
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  GitHub: https://github.com/sypher93
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
echo ""

# Source modules
if [ ! -f "$SCRIPT_DIR/functions.sh" ]; then
    echo "ERROR: functions.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/menus.sh" ]; then
    echo "ERROR: menus.sh not found in $SCRIPT_DIR" >&2
    exit 1
fi

source "$SCRIPT_DIR/functions.sh"
source "$SCRIPT_DIR/menus.sh"

# Set up trap for cleanup on exit
trap on_exit EXIT

# Main installation flow
main() {
    log_step "Starting installation"
    echo "📝 Log file: $LOG_FILE"
    echo ""
    
    # Step 1: User interaction
    select_installation_mode
    prompt_configuration
    
    # Step 2: System preparation
    install_dependencies
    install_docker
    install_nvidia_toolkit
    create_docker_user
    create_directories
    
    # Step 3: Configuration
    generate_ssl_certificates
    create_nginx_config
    
    # Step 4: Generate docker-compose.yml
    log_step "Generating Docker Compose configuration"
    
    # Export variables so generate-compose.sh can use them
    export INSTALLATION_MODE
    export USE_NVIDIA
    export GPU_COUNT
    
    if [ -f "$SCRIPT_DIR/generate-compose.sh" ]; then
        bash "$SCRIPT_DIR/generate-compose.sh" >> "$LOG_FILE" 2>&1 || \
            error_exit "Failed to generate docker-compose.yml"
    else
        error_exit "generate-compose.sh not found"
    fi
    
    # Step 5: Security scan (optional)
    run_security_scan
    
    # Step 6: Start services
    start_services
    
    # Step 7: Wait and verify
    verify_installation
    
    # Step 8: Post-installation checks
    log_step "Running post-installation verification"
    if [ -f "$SCRIPT_DIR/post_install.sh" ]; then
        bash "$SCRIPT_DIR/post_install.sh" || {
            log_warning "Post-installation checks had some issues"
            log_warning "Check logs: docker compose logs"
        }
    else
        log_warning "post_install.sh not found, skipping verification"
    fi
    
    # Step 9: Display final information
    display_final_info
    
    # Success!
    on_exit 0
}

# Run main function
main "$@"