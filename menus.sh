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
    
    # Automatic IP detection with confirmation
    echo "Detecting host IP address..."
    local detected_ip
    detected_ip=$(hostname -I | awk '{print $1}')
    
    if [[ -n "$detected_ip" ]]; then
        echo "✓ Detected IP: $detected_ip"
        echo ""
        read -rp "Use this IP address? [Y/n]: " use_detected_ip
        
        if [[ ! "$use_detected_ip" =~ ^[Nn]$ ]]; then
            DOMAIN="$detected_ip"
            echo "✓ Using detected IP: $DOMAIN"
        else
            # Manual entry
            while true; do
                read -rp "Enter your server's IPv4 address or domain: " DOMAIN
                if [[ -n "$DOMAIN" ]]; then
                    echo "✓ Domain/IP set to: $DOMAIN"
                    break
                else
                    echo "Domain/IP cannot be empty"
                fi
            done
        fi
    else
        # Fallback to manual entry if detection fails
        echo "⚠ Could not detect IP address automatically"
        while true; do
            read -rp "Enter your server's IPv4 address or domain: " DOMAIN
            if [[ -n "$DOMAIN" ]]; then
                echo "✓ Domain/IP set to: $DOMAIN"
                break
            else
                echo "Domain/IP cannot be empty"
            fi
        done
    fi
    echo ""
    
    # SSL certificate details (only for advanced mode)
    if [ "$INSTALLATION_MODE" = "advanced" ]; then
        echo "SSL Certificate Details:"
        echo ""
        read -rp "Use default certificate information? [Y/n]: " use_defaults
        
        if [[ ! "$use_defaults" =~ ^[Nn]$ ]]; then
            # Use predefined defaults
            COUNTRY="US"
            STATE="California"
            CITY="San Francisco"
            ORG="Self-Signed"
            ORG_UNIT="IT"
            echo "✓ Using default certificate information"
        else
            # Manual entry
            read -rp "Country code (C) [US]: " input_country
            COUNTRY=${input_country:-US}
            
            read -rp "State (ST) [California]: " input_state
            STATE=${input_state:-California}
            
            read -rp "City (L) [San Francisco]: " input_city
            CITY=${input_city:-San Francisco}
            
            read -rp "Organization (O) [Self-Signed]: " input_org
            ORG=${input_org:-Self-Signed}
            
            read -rp "Organizational Unit (OU) [IT]: " input_ou
            ORG_UNIT=${input_ou:-IT}
            
            echo "✓ SSL certificate details configured"
        fi
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

prompt_ollama_models() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Ollama Models Installation"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Do you want to install AI models now?"
    echo ""
    echo "  • Models can be installed later via: docker exec ollama ollama pull <model>"
    echo "  • Initial download may take 5-30 minutes depending on model size"
    echo ""
    
    read -rp "Install models now? [Y/n]: " install_models
    
    if [[ "$install_models" =~ ^[Nn]$ ]]; then
        echo "✓ Model installation skipped"
        echo ""
        return 0
    fi
    
    echo ""
    echo "Available models:"
    echo ""
    echo "  1) llama3.2:3b       - Recommended, small and fast (2GB, 4GB RAM min)"
    echo "  2) llama3.1:8b       - Balanced performance (4.7GB, 8GB RAM min)"
    echo "  3) mistral:7b        - Good for general tasks (4GB, 8GB RAM min)"
    echo "  4) codellama:13b     - Best for coding (7GB, 16GB RAM min)"
    echo "  5) qwen2.5:7b        - Multilingual model (4.7GB, 8GB RAM min)"
    echo "  6) phi3:medium       - Microsoft model (7.9GB, 16GB RAM min)"
    echo "  7) gemma2:9b         - Google model (5.4GB, 12GB RAM min)"
    echo "  8) Custom model      - Enter model name manually"
    echo "  9) None              - Skip installation"
    echo ""
    
    # Detect system resources
    local total_ram=$(free -g | awk '/^Mem:/{print $2}')
    local available_disk=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
    
    # GPU detection
    local has_gpu=false
    local gpu_vram=0
    local gpu_name="None"
    
    if lspci 2>/dev/null | grep -i nvidia &> /dev/null; then
        has_gpu=true
        # Try to get GPU info with nvidia-smi
        if command -v nvidia-smi &> /dev/null; then
            gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
            gpu_vram=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -1)
            gpu_vram=$((gpu_vram / 1024))  # Convert MB to GB
        else
            # GPU detected but nvidia-smi not available yet
            gpu_name=$(lspci | grep -i nvidia | head -1 | cut -d: -f3 | xargs)
            gpu_vram="Unknown"
        fi
    fi
    
    echo "📊 System Resources:"
    echo "   CPU RAM: ${total_ram}GB"
    echo "   Available Disk: ${available_disk}GB"
    if [ "$has_gpu" = true ]; then
        echo "   GPU: $gpu_name"
        if [ "$gpu_vram" != "Unknown" ] && [ "$gpu_vram" -gt 0 ]; then
            echo "   GPU VRAM: ${gpu_vram}GB"
        fi
    else
        echo "   GPU: None detected (CPU-only mode)"
    fi
    echo ""
    
    # Smart recommendations based on hardware
    echo "💡 Recommendations for your system:"
    
    if [ "$has_gpu" = true ] && [ "$gpu_vram" != "Unknown" ] && [ "$gpu_vram" -gt 0 ]; then
        # GPU-based recommendations
        if [ "$gpu_vram" -ge 24 ]; then
            echo "   🚀 Excellent GPU! All models will run smoothly, even large ones (70B+)"
            echo "   ✓ Recommended: Options 1-7 (all supported)"
            echo "   ✓ You can even try: llama3.1:70b, mixtral:8x7b"
        elif [ "$gpu_vram" -ge 12 ]; then
            echo "   🎮 Great GPU! Models up to 13B will run well"
            echo "   ✓ Recommended: Options 1-7 (all supported)"
            echo "   ⚠ Avoid: 70B+ models (require 24GB+ VRAM)"
        elif [ "$gpu_vram" -ge 8 ]; then
            echo "   🎯 Good GPU! Models up to 8B will run smoothly"
            echo "   ✓ Recommended: Options 1, 2, 3, 5 (3b-8b models)"
            echo "   ⚠ Possible but slower: Options 4, 6, 7 (13b+ models)"
        elif [ "$gpu_vram" -ge 6 ]; then
            echo "   ✓ GPU detected! Best for models up to 7B"
            echo "   ✓ Recommended: Options 1, 3 (3b-7b models)"
            echo "   ⚠ May struggle with: 8B+ models"
        else
            echo "   ⚠ Limited GPU VRAM detected"
            echo "   ✓ Recommended: Option 1 only (llama3.2:3b)"
            echo "   ⚠ Larger models will likely fail or be very slow"
        fi
    else
        # CPU-only recommendations
        echo "   💻 CPU-only mode (no GPU detected)"
        if [ "$total_ram" -ge 32 ]; then
            echo "   ✓ High RAM! Models up to 13B will work (slowly)"
            echo "   ✓ Recommended: Options 1-4"
            echo "   ⚠ Expect slower responses than with GPU"
        elif [ "$total_ram" -ge 16 ]; then
            echo "   ✓ Good RAM! Models up to 8B will work"
            echo "   ✓ Recommended: Options 1, 2, 3, 5"
            echo "   ⚠ Responses will be slower without GPU"
        elif [ "$total_ram" -ge 8 ]; then
            echo "   ✓ Minimum RAM. Stick to small models"
            echo "   ✓ Recommended: Option 1 (llama3.2:3b)"
            echo "   ⚠ Larger models may cause system slowdown"
        else
            echo "   ⚠ Limited RAM detected (${total_ram}GB)"
            echo "   ⚠ Only very small models recommended"
            echo "   ✓ Try: Option 1 (llama3.2:3b) with caution"
        fi
    fi
    echo ""
    
    # Disk space warning
    if [ "$available_disk" -lt 20 ]; then
        echo "⚠️  WARNING: Low disk space (${available_disk}GB available)"
        echo "   Consider freeing up space before installing large models"
        echo ""
    fi
    
    OLLAMA_MODELS=()
    
    while true; do
        read -rp "Select model(s) (comma-separated, e.g., 1,2,3 or 9 to skip): " model_choices
        
        # Remove spaces and split by comma
        IFS=',' read -ra choices <<< "${model_choices// /}"
        
        local skip_install=false
        
        for choice in "${choices[@]}"; do
            case "$choice" in
                1)
                    OLLAMA_MODELS+=("llama3.2:3b")
                    ;;
                2)
                    OLLAMA_MODELS+=("llama3.1:8b")
                    ;;
                3)
                    OLLAMA_MODELS+=("mistral:7b")
                    ;;
                4)
                    OLLAMA_MODELS+=("codellama:13b")
                    ;;
                5)
                    OLLAMA_MODELS+=("qwen2.5:7b")
                    ;;
                6)
                    OLLAMA_MODELS+=("phi3:medium")
                    ;;
                7)
                    OLLAMA_MODELS+=("gemma2:9b")
                    ;;
                8)
                    read -rp "Enter custom model name (e.g., llama3.3:70b): " custom_model
                    if [[ -n "$custom_model" ]]; then
                        OLLAMA_MODELS+=("$custom_model")
                    fi
                    ;;
                9)
                    skip_install=true
                    break
                    ;;
                *)
                    echo "Invalid choice: $choice"
                    continue 2
                    ;;
            esac
        done
        
        if [ "$skip_install" = true ]; then
            OLLAMA_MODELS=()
            echo "✓ Model installation skipped"
            echo ""
            return 0
        fi
        
        if [ ${#OLLAMA_MODELS[@]} -gt 0 ]; then
            # Remove duplicates
            OLLAMA_MODELS=($(printf "%s\n" "${OLLAMA_MODELS[@]}" | sort -u))
            
            echo ""
            echo "Selected models:"
            for model in "${OLLAMA_MODELS[@]}"; do
                echo "  ✓ $model"
            done
            
            # Calculate total size estimate and check hardware compatibility
            local total_size=0
            local max_ram_needed=0
            local max_vram_needed=0
            local warnings=()
            
            for model in "${OLLAMA_MODELS[@]}"; do
                local model_size=0
                local ram_needed=0
                local vram_needed=0
                
                case "$model" in
                    *3b*)
                        model_size=2
                        ram_needed=4
                        vram_needed=4
                        ;;
                    *7b*|*8b*)
                        model_size=5
                        ram_needed=8
                        vram_needed=8
                        ;;
                    *9b*)
                        model_size=6
                        ram_needed=12
                        vram_needed=10
                        ;;
                    *13b*)
                        model_size=7
                        ram_needed=16
                        vram_needed=12
                        ;;
                    *medium*)
                        model_size=8
                        ram_needed=16
                        vram_needed=12
                        ;;
                    *70b*)
                        model_size=40
                        ram_needed=64
                        vram_needed=48
                        ;;
                    *)
                        model_size=5  # Default estimate
                        ram_needed=8
                        vram_needed=8
                        ;;
                esac
                
                total_size=$((total_size + model_size))
                
                # Check if this model exceeds current max requirements
                if [ "$ram_needed" -gt "$max_ram_needed" ]; then
                    max_ram_needed=$ram_needed
                fi
                if [ "$vram_needed" -gt "$max_vram_needed" ]; then
                    max_vram_needed=$vram_needed
                fi
                
                # Check compatibility with current hardware
                if [ "$has_gpu" = true ] && [ "$gpu_vram" != "Unknown" ] && [ "$gpu_vram" -gt 0 ]; then
                    if [ "$gpu_vram" -lt "$vram_needed" ]; then
                        warnings+=("⚠️  $model may not fit in GPU VRAM (needs ${vram_needed}GB, you have ${gpu_vram}GB)")
                    fi
                else
                    if [ "$total_ram" -lt "$ram_needed" ]; then
                        warnings+=("⚠️  $model requires ${ram_needed}GB RAM (you have ${total_ram}GB)")
                    fi
                fi
            done
            
            echo ""
            echo "Estimated total download: ~${total_size}GB"
            
            if [ "$has_gpu" = true ] && [ "$gpu_vram" != "Unknown" ] && [ "$gpu_vram" -gt 0 ]; then
                echo "Maximum VRAM needed: ${max_vram_needed}GB (you have ${gpu_vram}GB)"
            else
                echo "Maximum RAM needed: ${max_ram_needed}GB (you have ${total_ram}GB)"
            fi
            echo ""
            
            # Display warnings if any
            if [ ${#warnings[@]} -gt 0 ]; then
                echo "⚠️  Hardware Compatibility Warnings:"
                for warning in "${warnings[@]}"; do
                    echo "   $warning"
                done
                echo ""
                echo "These models may:"
                echo "  - Fail to load completely"
                echo "  - Run extremely slowly"
                echo "  - Cause system instability"
                echo ""
            fi
            
            if [ "$available_disk" -lt "$total_size" ]; then
                echo "⚠️  CRITICAL: Not enough disk space!"
                echo "   Required: ~${total_size}GB"
                echo "   Available: ${available_disk}GB"
                echo ""
                read -rp "Continue anyway? [y/N]: " force_continue
                if [[ ! "$force_continue" =~ ^[Yy]$ ]]; then
                    continue
                fi
            fi
            
            read -rp "Confirm installation? [Y/n]: " confirm
            if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
                echo "✓ Models will be installed after services start"
                echo ""
                break
            fi
        else
            echo "No models selected"
        fi
    done
}