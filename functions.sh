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
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/installation_$(date +'%Y-%m-%d_%H-%M-%S').log"

# Create logs directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Global variables (will be set by menus.sh)
INSTALLATION_MODE="simple"
DOMAIN=""
GPU_COUNT=0
USE_NVIDIA=false
EXPOSE_OLLAMA_API=false
OLLAMA_MODELS=()
CREATE_NON_ROOT_USER=false
DOCKER_USER="openwebui"
DOCKER_UID=1000
DOCKER_GID=1000
COUNTRY="US"
STATE="California"
CITY="San Francisco"
ORG="Self-Signed"
ORG_UNIT="IT"

# Logging functions
log() { 
    echo -e "\033[0;32m[INFO]\033[0m $(date +'%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log_error() { 
    echo -e "\033[0;31m[ERROR]\033[0m $(date +'%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE" >&2
}

log_warning() { 
    echo -e "\033[1;33m[WARN]\033[0m $(date +'%Y-%m-%d %H:%M:%S') $*" | tee -a "$LOG_FILE"
}

log_step() { 
    echo -e "\n\033[0;32m========================================\033[0m" | tee -a "$LOG_FILE"
    echo -e "\033[0;32m$*\033[0m" | tee -a "$LOG_FILE"
    echo -e "\033[0;32m========================================\033[0m\n" | tee -a "$LOG_FILE"
}

error_exit() { 
    log_error "$1"
    exit 1
}

on_exit() {
    local code=${1:-$?}
    if [ "$code" -ne 0 ]; then
        log_error "Installer failed or interrupted (exit $code). Running docker compose down..."
        (cd "$SCRIPT_DIR" && docker compose down) 2>/dev/null || true
    fi
    log "Installer exit code: $code"
    exit "$code"
}

install_dependencies() {
    log_step "STEP 1: Installing system dependencies"
    
    # Remove broken Trivy repository if it exists
    if [ -f /etc/apt/sources.list.d/trivy.list ]; then
        log "Removing old Trivy repository..."
        rm -f /etc/apt/sources.list.d/trivy.list
    fi
    
    log "Updating package lists..."
    # Show progress in terminal, log only errors
    apt-get update 2>&1 | tee >(grep -iE "err|fail|error" >> "$LOG_FILE" 2>/dev/null) || true
    log "✓ Package lists updated"
    
    log "Installing base dependencies..."
    # Show progress in terminal, log only errors
    apt-get install -y ca-certificates curl gnupg lsb-release wget openssl jq 2>&1 | \
       tee >(grep -iE "err|fail|error" >> "$LOG_FILE" 2>/dev/null) | \
       grep -E "Setting up|Unpacking|Processing" || true
    log "✓ System dependencies installed"
}

install_docker() {
    log_step "STEP 2: Installing Docker"
    
    # Check if Docker is installed via snap
    if command -v snap &> /dev/null && snap list docker &> /dev/null 2>&1; then
        log_warning "Docker is installed via snap"
        log_warning "Snap Docker has limitations with GPU support and volume mounts"
        log_warning ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  ⚠️  Docker Snap Detected"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Docker installed via snap has known issues:"
        echo "  - NVIDIA GPU support doesn't work properly"
        echo "  - Volume mount restrictions"
        echo "  - Limited systemd integration"
        echo ""
        echo "It is STRONGLY recommended to reinstall Docker via apt."
        echo ""
        read -p "Do you want to reinstall Docker via apt now? [y/N]: " reinstall_docker
        
        if [[ "$reinstall_docker" =~ ^[Yy]$ ]]; then
            log "Removing Docker snap..."
            snap remove docker >> "$LOG_FILE" 2>&1 || log_warning "Failed to remove Docker snap"
            sleep 2
        else
            log_warning "Continuing with Docker snap (GPU may not work)"
            log_warning "To reinstall later, run: sudo snap remove docker && curl -fsSL https://get.docker.com | sh"
            return 0
        fi
    fi
    
    if command -v docker &> /dev/null && ! snap list docker &> /dev/null 2>&1; then
        DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
        log "Docker already installed: $DOCKER_VERSION"
        
        # Verify it's not a problematic installation
        if docker info &> /dev/null; then
            log "✓ Docker is working correctly"
            return 0
        else
            log_warning "Docker command found but not working properly"
        fi
    fi
    
    log "Downloading Docker installation script..."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh 2>&1 | \
        tee >(grep -iE "err|fail|error" >> "$LOG_FILE" 2>/dev/null) || \
        error_exit "Failed to download Docker installer"
    
    log "Installing Docker via apt (official method)..."
    echo "  (This may take a few minutes, progress shown below)"
    # Show installation progress in terminal, log errors only
    if sh /tmp/get-docker.sh 2>&1 | \
       tee >(grep -iE "err|fail|error" >> "$LOG_FILE" 2>/dev/null) | \
       grep -E "docker|version|Installing|Setting up" || true; then
        log "✓ Docker installed"
    else
        error_exit "Failed to install Docker"
    fi
    rm -f /tmp/get-docker.sh
    
    log "Starting and enabling Docker service..."
    systemctl enable --now docker >> "$LOG_FILE" 2>&1 || error_exit "Failed to start Docker"
    
    # Add current user to docker group if not root
    if [ "$SUDO_USER" != "" ] && [ "$SUDO_USER" != "root" ]; then
        log "Adding user $SUDO_USER to docker group..."
        usermod -aG docker "$SUDO_USER" >> "$LOG_FILE" 2>&1 || log_warning "Failed to add user to docker group"
        log_warning "You may need to log out and back in for docker group to take effect"
    fi
    
    log "✓ Docker installed and started successfully"
}

install_nvidia_toolkit() {
    if [ "$USE_NVIDIA" = false ]; then 
        return 0
    fi
    
    log_step "STEP 3: Installing NVIDIA Container Toolkit"
    
    log "Adding NVIDIA Container Toolkit repository..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | \
        gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg 2>&1 | \
        tee >(grep -iE "err|fail|error" >> "$LOG_FILE" 2>/dev/null) || \
        error_exit "Failed to add NVIDIA GPG key"
    
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null
    
    apt-get update 2>&1 | tee >(grep -iE "err|fail|error" >> "$LOG_FILE" 2>/dev/null) || \
        error_exit "Failed to update after adding NVIDIA repo"
    
    log "Installing NVIDIA Container Toolkit..."
    apt-get install -y nvidia-container-toolkit 2>&1 | \
        tee >(grep -iE "err|fail|error" >> "$LOG_FILE" 2>/dev/null) | \
        grep -E "Setting up|Unpacking" || true
    log "✓ NVIDIA Container Toolkit installed"
    
    log "Configuring Docker for NVIDIA runtime..."
    nvidia-ctk runtime configure --runtime=docker 2>&1 | \
        tee >(grep -iE "err|fail|error" >> "$LOG_FILE" 2>/dev/null) || \
        error_exit "Failed to configure NVIDIA runtime"
    
    # Try to restart Docker with different methods
    log "Restarting Docker service..."
    if systemctl is-active --quiet docker.service 2>/dev/null; then
        # Docker installed via systemd
        systemctl restart docker >> "$LOG_FILE" 2>&1 || \
            log_warning "Failed to restart Docker via systemctl, trying alternative methods..."
    elif systemctl is-active --quiet docker.socket 2>/dev/null; then
        # Docker socket-based activation
        systemctl restart docker.socket >> "$LOG_FILE" 2>&1 || \
            log_warning "Failed to restart Docker socket"
    elif command -v snap &> /dev/null && snap list docker &> /dev/null; then
        # Docker installed via snap
        log "Docker installed via snap, restarting..."
        snap restart docker >> "$LOG_FILE" 2>&1 || \
            log_warning "Failed to restart Docker snap"
    else
        # Docker Desktop or other installation
        log_warning "Docker not found as systemd service or snap"
        log_warning "Please restart Docker manually:"
        log_warning "  - Docker Desktop: Restart from the app"
        log_warning "  - Or run: sudo pkill -SIGHUP dockerd"
        log_warning ""
        read -p "Press Enter after restarting Docker, or 's' to skip and continue [Enter/s]: " restart_choice
        if [[ "$restart_choice" =~ ^[Ss]$ ]]; then
            log "Skipping Docker restart, continuing installation..."
        fi
    fi
    
    # Verify Docker is running
    if docker info &> /dev/null; then
        log "✓ Docker is running"
    else
        log_warning "Docker may not be running properly"
        log_warning "You may need to restart it manually after installation"
    fi
    
    log "✓ NVIDIA Container Toolkit installed and configured"
}

create_docker_user() {
    if [ "$CREATE_NON_ROOT_USER" = false ]; then 
        return 0
    fi
    
    log_step "Configuring docker user $DOCKER_USER"
    
    # Check if user already exists
    if id "$DOCKER_USER" >/dev/null 2>&1; then
        DOCKER_UID=$(id -u "$DOCKER_USER")
        DOCKER_GID=$(id -g "$DOCKER_USER")
        log "User $DOCKER_USER already exists (UID: $DOCKER_UID, GID: $DOCKER_GID)"
        log "✓ Using existing user"
        return 0
    fi
    
    log "Creating user $DOCKER_USER..."
    
    # Try to create group
    if ! getent group "$DOCKER_USER" >/dev/null 2>&1; then
        groupadd -g "$DOCKER_GID" "$DOCKER_USER" >> "$LOG_FILE" 2>&1 || {
            log_warning "Could not create group with GID $DOCKER_GID, using auto-assigned GID"
            groupadd "$DOCKER_USER" >> "$LOG_FILE" 2>&1 || true
        }
    fi
    
    # Get actual GID
    DOCKER_GID=$(getent group "$DOCKER_USER" | cut -d: -f3)
    
    # Try to create user
    useradd -u "$DOCKER_UID" -g "$DOCKER_GID" -m -s /bin/bash "$DOCKER_USER" >> "$LOG_FILE" 2>&1 || {
        log_warning "Could not create user with UID $DOCKER_UID, using auto-assigned UID"
        useradd -g "$DOCKER_GID" -m -s /bin/bash "$DOCKER_USER" >> "$LOG_FILE" 2>&1 || \
            error_exit "Failed to create user $DOCKER_USER"
    }
    
    # Get actual UID
    DOCKER_UID=$(id -u "$DOCKER_USER")
    
    log "✓ User $DOCKER_USER created (UID: $DOCKER_UID, GID: $DOCKER_GID)"
}

create_directories() {
    log_step "Creating directory structure"
    
    mkdir -p "$SCRIPT_DIR/conf.d" || error_exit "Failed to create conf.d"
    mkdir -p "$SCRIPT_DIR/ssl" || error_exit "Failed to create ssl"
    
    if [ "$CREATE_NON_ROOT_USER" = true ]; then
        chown -R "$DOCKER_USER:$DOCKER_USER" "$SCRIPT_DIR" 2>/dev/null || \
            log_warning "Failed to change ownership"
    fi
    
    log "✓ Directory structure created"
}

generate_ssl_certificates() {
    if [ "$INSTALLATION_MODE" = "simple" ]; then 
        return 0
    fi
    
    log_step "Generating SSL certificates"
    
    log "Generating self-signed SSL certificate..."
    
    # Ensure ssl directory exists and has correct permissions
    mkdir -p "$SCRIPT_DIR/ssl" || error_exit "Failed to create ssl directory"
    
    # Generate certificate
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$SCRIPT_DIR/ssl/nginx.key" \
        -out "$SCRIPT_DIR/ssl/nginx.crt" \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${ORG_UNIT}/CN=${DOMAIN}" \
        >> "$LOG_FILE" 2>&1 || error_exit "Failed to generate SSL certificate"
    
    # Verify files were created
    if [ ! -f "$SCRIPT_DIR/ssl/nginx.key" ] || [ ! -f "$SCRIPT_DIR/ssl/nginx.crt" ]; then
        error_exit "SSL certificate files were not created"
    fi
    
    # Set permissions (must be readable by Docker/nginx)
    chmod 644 "$SCRIPT_DIR/ssl/nginx.key" || log_warning "Failed to set permissions on SSL key"
    chmod 644 "$SCRIPT_DIR/ssl/nginx.crt" || log_warning "Failed to set permissions on SSL cert"
    
    # If using non-root user, ensure they can read the files
    if [ "$CREATE_NON_ROOT_USER" = true ]; then
        chown -R "$DOCKER_USER:$DOCKER_USER" "$SCRIPT_DIR/ssl" 2>/dev/null || \
            log_warning "Failed to change ownership of ssl directory"
    fi
    
    log "✓ SSL certificate generated and verified"
    log "  Key:  $SCRIPT_DIR/ssl/nginx.key"
    log "  Cert: $SCRIPT_DIR/ssl/nginx.crt"
}

create_nginx_config() {
    log_step "Creating Nginx configuration"
    
    if [ "$INSTALLATION_MODE" = "simple" ]; then
        log "Creating HTTP configuration..."
        cat > "$SCRIPT_DIR/conf.d/open-webui.conf" <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://open-webui:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 180s;
        proxy_send_timeout 180s;
        proxy_read_timeout 180s;

        # Buffering
        proxy_buffering off;
        proxy_request_buffering off;
    }
}
EOF
    else
        log "Creating HTTPS configuration..."
        cat > "$SCRIPT_DIR/conf.d/open-webui.conf" <<'EOF'
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name _;

    # SSL certificates
    ssl_certificate /etc/nginx/ssl/nginx.crt;
    ssl_certificate_key /etc/nginx/ssl/nginx.key;
    
    # SSL protocols and ciphers
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://open-webui:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts
        proxy_connect_timeout 180s;
        proxy_send_timeout 180s;
        proxy_read_timeout 180s;

        # Buffering
        proxy_buffering off;
        proxy_request_buffering off;
    }
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name _;
    return 301 https://$host$request_uri;
}
EOF
    fi
    
    log "✓ Nginx configuration created"
}

run_security_scan() {
    log_step "Security scan (optional)"
    
    read -p "Do you want to run Trivy security scan? [y/N]: " run_scan
    if [[ ! "$run_scan" =~ ^[Yy]$ ]]; then
        log "Skipping security scan"
        return 0
    fi
    
    log "Installing Trivy..."
    if ! command -v trivy &> /dev/null; then
        # Try to install Trivy, but don't fail if it doesn't work
        {
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | \
                gpg --dearmor -o /usr/share/keyrings/trivy.gpg
            
            # Get Debian/Ubuntu codename
            local os_codename
            os_codename=$(lsb_release -sc)
            
            # For Trixie and other new releases, use 'stable' instead
            if [[ "$os_codename" == "trixie" ]] || [[ "$os_codename" == "sid" ]]; then
                log_warning "Trixie/Sid detected, using bookworm repository for Trivy"
                os_codename="bookworm"
            fi
            
            echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb ${os_codename} main" | \
                tee /etc/apt/sources.list.d/trivy.list > /dev/null
            
            apt-get update
            apt-get install -y trivy
        } >> "$LOG_FILE" 2>&1 || {
            log_warning "Failed to install Trivy - skipping security scan"
            log_warning "You can install Trivy manually later if needed"
            return 0
        }
    fi
    
    if command -v trivy &> /dev/null; then
        log "Scanning images (this may take 5-10 minutes)..."
        echo "  Scanning nginx:alpine..."
        trivy image nginx:alpine >> "$LOG_FILE" 2>&1 || log_warning "Failed to scan nginx:alpine"
        echo "  ✓ nginx:alpine scanned"
        
        echo "  Scanning ollama/ollama:latest..."
        trivy image ollama/ollama:latest >> "$LOG_FILE" 2>&1 || log_warning "Failed to scan ollama/ollama:latest"
        echo "  ✓ ollama/ollama:latest scanned"
        
        echo "  Scanning ghcr.io/open-webui/open-webui:main..."
        trivy image ghcr.io/open-webui/open-webui:main >> "$LOG_FILE" 2>&1 || log_warning "Failed to scan open-webui:main"
        echo "  ✓ open-webui:main scanned"
        
        log "✓ Security scan completed (check $LOG_FILE for details)"
    else
        log_warning "Trivy not available, skipping security scan"
    fi
}

start_services() {
    log_step "Starting services"
    
    cd "$SCRIPT_DIR" || error_exit "Failed to change to script directory"
    
    log "Pulling Docker images (this may take several minutes)..."
    echo "  This step downloads ~2-3GB of data, please be patient..."
    echo ""
    
    # Pull images with progress visible in terminal
    # Only log start/end, let progress bars show in terminal
    if docker compose pull 2>&1 | tee -a >(grep -E "Error|error|failed" >> "$LOG_FILE"); then
        log "✓ Docker images pulled successfully"
    else
        error_exit "Failed to pull Docker images"
    fi
    
    echo ""
    log "Starting containers..."
    docker compose up -d 2>&1 | tee -a >(grep -v "^$" >> "$LOG_FILE") || error_exit "Failed to start containers"
    
    log "✓ Services started"
}

verify_installation() {
    log_step "Verifying installation"
    
    log "Waiting for services to initialize..."
    echo "  This may take 2-3 minutes for OpenWebUI to be fully ready..."
    echo ""
    
    # Wait for Ollama
    log "Checking Ollama..."
    local max_attempts=30
    local attempt=0
    while [ $attempt -lt $max_attempts ]; do
        if docker exec ollama curl -sf http://localhost:11434/api/tags >/dev/null 2>&1; then
            log "✓ Ollama is responding"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_warning "Ollama may still be starting"
    fi
    echo ""
    
    # Wait for OpenWebUI
    log "Checking OpenWebUI..."
    attempt=0
    max_attempts=60
    while [ $attempt -lt $max_attempts ]; do
        if docker exec open-webui curl -sf http://localhost:8080 >/dev/null 2>&1; then
            log "✓ OpenWebUI is responding"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_warning "OpenWebUI is taking longer than expected"
        log_warning "Check logs: docker logs open-webui"
    fi
    echo ""
    
    # Wait for Nginx
    log "Checking Nginx proxy..."
    attempt=0
    max_attempts=10
    local protocol="http"
    
    if [ "$INSTALLATION_MODE" = "advanced" ]; then
        protocol="https"
    fi
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf -k "${protocol}://localhost" >/dev/null 2>&1; then
            log "✓ Nginx proxy is responding"
            break
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log_warning "Nginx may have issues"
    fi
    echo ""
    
    log "✓ Basic verification completed"
}

display_final_info() {
    local protocol="http"
    local port="80"
    
    if [ "$INSTALLATION_MODE" = "advanced" ]; then
        protocol="https"
        port="443"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ OpenWebUI Installation Completed Successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  ▶️  Access OpenWebUI at: ${protocol}://${DOMAIN}:${port}"
    echo ""
    echo "  🌐 Service URLs:"
    echo "     - OpenWebUI:  ${protocol}://${DOMAIN}:${port}"
    echo "     - GitHub:     https://github.com/sypher93/ollama-bundle"
    echo ""
    echo "  📝 Installation Mode: $INSTALLATION_MODE"
    if [ "$USE_NVIDIA" = true ]; then
        echo "  🟩 GPU Acceleration: Enabled ($GPU_COUNT GPU(s))"
    fi
    if [ "$EXPOSE_OLLAMA_API" = true ]; then
        echo "  ↔️  Ollama API : Exposed (http://${DOMAIN}:11434)"
    fi
    if [ ${#OLLAMA_MODELS[@]} -gt 0 ]; then
        echo "  🤖 Installed Models: ${OLLAMA_MODELS[*]}"
    fi
    echo ""
    echo "  🔧 Useful Commands:"
    echo "     - View logs:        docker compose logs -f"
    echo "     - Restart services: docker compose restart"
    echo "     - Stop services:    docker compose down"
    echo ""
    if [ "$INSTALLATION_MODE" = "advanced" ]; then
        echo "  ⚠️  Note: Using self-signed SSL certificate"
        echo "     Your browser will show a security warning"
        echo ""
    fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

install_ollama_models() {
    if [ ${#OLLAMA_MODELS[@]} -eq 0 ]; then
        log "No models selected for installation"
        return 0
    fi
    
    log_step "Installing Ollama Models"
    
    log "Selected models: ${OLLAMA_MODELS[*]}"
    echo ""
    echo "⚠️  Model download can take 5-30 minutes depending on:"
    echo "   - Model size (2GB to 70GB)"
    echo "   - Your internet connection"
    echo "   - Number of models selected"
    echo ""
    read -p "Continue with model installation? [Y/n]: " continue_install
    
    if [[ "$continue_install" =~ ^[Nn]$ ]]; then
        log "Model installation skipped"
        log "You can install models later with: docker exec ollama ollama pull <model-name>"
        return 0
    fi
    
    local total_models=${#OLLAMA_MODELS[@]}
    local current=0
    
    for model in "${OLLAMA_MODELS[@]}"; do
        current=$((current + 1))
        log "[$current/$total_models] Pulling model: $model"
        echo ""
        
        # Pull the model with progress visible
        if docker exec ollama ollama pull "$model" 2>&1 | tee >(grep -iE "error|fail" >> "$LOG_FILE" 2>/dev/null); then
            log "✓ Model $model installed successfully"
        else
            log_warning "Failed to install model: $model"
            log_warning "You can try installing it manually later with:"
            log_warning "  docker exec ollama ollama pull $model"
        fi
        echo ""
    done
    
    log "✓ Model installation completed"
    echo ""
    log "Verifying installed models..."
    docker exec ollama ollama list || log_warning "Could not list models"
}