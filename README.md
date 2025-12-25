# OpenWebUI + Nginx + Ollama Stack
**One-command deployment** for a complete AI chat interface with Ollama LLM backend and Nginx reverse proxy.

<p align="center">
<a href="https://ibb.co/vCQ6Cc4j"><img src="https://i.ibb.co/qLW3LDYr/ollama-bundle-banner-sypher93.jpg" alt="ollama-bundle-banner-sypher93" border="0"></a>
</p>

## ✨ Features

<p align="center">
<a href="https://imgbb.com/"><img src="https://i.ibb.co/PG0jd8sQ/ai-bundle-deploy-logo-sypher93.png" alt="ai bundle deploy logo sypher93" border="0"></a>
</p>

- 🚀 **Interactive installation** - User-friendly prompts guide you through setup
- 🤖 **Automated model installation** - Choose and install AI models during setup
- 🐳 **Docker Compose** - Nginx + OpenWebUI + Ollama in one stack
- 🔒 **SSL/TLS support** - HTTP (simple) or HTTPS (advanced) modes
- 🎮 **GPU acceleration** - Automatic NVIDIA GPU detection and configuration
- 🧠 **Smart recommendations** - Hardware-aware model suggestions
- 🌐 **API exposure control** - Choose to expose Ollama API or keep it internal
- 📊 **Resource detection** - Automatic IP, RAM, GPU, and disk detection
- 📝 **Timestamped logs** - Installation history preserved in `logs/` directory
- 📦 **Modular architecture** - Easy to customize and maintain

## 📋 Prerequisites

- **OS**: Debian 12+ or Ubuntu 22.04+ (Tested on Debian 13 / Ubuntu Server 24.04)
- **Access**: Root or sudo privileges
- **CPU**: 4+ cores recommended
- **Disk**: 20GB+ free space (50GB+ for multiple models)
- **RAM**: 
  - 4GB minimum (small models only)
  - 8GB recommended (7B models)
  - 16GB+ for larger models
- **GPU** (optional): NVIDIA GPU with drivers installed
- **Network**: Open ports 80 (HTTP) and/or 443 (HTTPS)

## 🚀 Quick Start
```bash
# Clone repository
git clone https://github.com/sypher93/ollama-bundle.git
cd ollama-bundle

# Run installer
sudo chmod +x *.sh
sudo ./install.sh
```

The installer will guide you through:
1. **Installation mode** - Simple (HTTP) or Advanced (HTTPS)
2. **Server configuration** - Auto-detected IP with manual override option
3. **SSL certificates** - Use defaults or customize (Advanced mode)
4. **GPU detection** - Automatic NVIDIA GPU configuration
5. **Ollama API** - Expose on host or keep internal
6. **Model selection** - Choose AI models with hardware-specific recommendations

## 🎯 Installation Modes

### Simple Mode (HTTP)
- Quick setup for testing/development
- HTTP only (port 80)
- No SSL certificates
- Auto-detected IP address

### Advanced Mode (HTTPS)
- Production-ready with SSL
- Self-signed or custom certificates
- HTTP → HTTPS redirect with TLS 1.3
- Enhanced security headers
- Configurable certificate details

**Security scan**: Optional Trivy scan on Docker images during installation (output in logs).

## 🤖 AI Model Installation

During installation, the script will:
1. **Detect your hardware** (RAM, GPU VRAM, disk space)
2. **Recommend compatible models** based on your system
3. **Allow model selection** with size and requirement information

### Available Models

| Model | Size | RAM (CPU) | VRAM (GPU) | Best For |
|-------|------|-----------|------------|----------|
| llama3.2:3b | 2GB | 4GB | 4GB | Fast responses, general use |
| llama3.1:8b | 4.7GB | 8GB | 8GB | Balanced performance |
| mistral:7b | 4GB | 8GB | 8GB | General tasks |
| codellama:13b | 7GB | 16GB | 12GB | Code generation |
| qwen2.5:7b | 4.7GB | 8GB | 8GB | Multilingual support |
| phi3:medium | 7.9GB | 16GB | 12GB | Microsoft model |
| gemma2:9b | 5.4GB | 12GB | 10GB | Google model |

**Hardware Recommendations:**
- **24GB+ VRAM**: All models including 70B+
- **12GB VRAM**: Models up to 13B
- **8GB VRAM**: Models up to 8B
- **CPU-only (16GB RAM)**: Models up to 8B (slower)
- **CPU-only (8GB RAM)**: Only 3B models recommended

## 📁 Project Structure
```
ollama-bundle/
├── install.sh             # Main installer
├── functions.sh           # Core functions
├── menus.sh               # Interactive prompts
├── generate-compose.sh    # Docker Compose generator
├── generate-config.sh     # Nginx config generator
├── post-install.sh        # Post-installation checks
├── logs/                  # Installation logs (timestamped)
│   └── installation_YYYY-MM-DD_HH-MM-SS.log
├── conf.d/                # Nginx configuration
├── ssl/                   # SSL certificates (Advanced mode)
└── docker-compose.yml     # Generated stack configuration
```

## 🎉 Post-Installation

### Successful Installation

<a href="https://imgbb.com/"><img src="https://i.ibb.co/dJ1R8vvZ/ollama-bundle-install-complete-sypher93.png" alt="ollama bundle install complete sypher93" border="0"></a>

### 1. Access OpenWebUI

Open your browser:
- **Simple mode**: `http://YOUR_SERVER_IP`
- **Advanced mode**: `https://YOUR_SERVER_IP`

### 2. Create Admin Account

First user to register becomes admin.

### 3. Start Using AI

If you installed models during setup, they're ready to use immediately:

<a href="https://ibb.co/bg8zHMwm"><img src="https://i.ibb.co/jv1gVP0f/chat-llm-ollama-bundle.png" alt="chat-llm-ollama-bundle" border="0"></a>

### 4. Manage Models (Optional)

**Via Web Interface:**
Navigate to **Models** tab to add or remove models:

<a href="https://ibb.co/rKNZHfz8"><img src="https://i.ibb.co/DPT7Qgvc/manage-models-ollama-bundle.png" alt="manage-models-ollama-bundle" border="0"></a>

**Via Command Line:**
```bash
# Pull a model
docker exec ollama ollama pull llama3.2:3b

# List installed models
docker exec ollama ollama list

# Remove a model
docker exec ollama ollama rm llama3.2:3b
```

## Management Commands
```bash
# View logs
docker compose logs -f

# Restart services
docker compose restart

# Stop services
docker compose down

# Update stack
docker compose pull
docker compose up -d

# Check status
docker compose ps
```

## Switching from HTTP to HTTPS

Switch to HTTPS anytime by rerunning the installer:
```bash
sudo ./install.sh
```
Select **Advanced mode** - the installer will:
- Detect existing deployment
- Generate SSL certificates
- Update configuration automatically
- No container re-download needed

## Management

### Monitoring GPU Usage

Run `watch -n 1 nvidia-smi` to monitor GPU utilization, memory usage, and temperature every second. This displays live metrics like VRAM allocation during inference, helping detect bottlenecks or overheating.

### Monitoring System Resources

Use `htop` (install via your package manager if needed, e.g., `sudo apt install htop`) to track CPU, RAM, and process details interactively. Sort by CPU or memory to spot high usage from the LLM process. 
Press F6 to customize views.

<a href="https://ibb.co/G3nFBLbP"><img src="https://i.ibb.co/XkjVNgvJ/Monitoring-GPU-Usage-LLM-OLLAMA.png" alt="Monitoring-GPU-Usage-LLM-OLLAMA" border="0"></a>

### View Logs
```bash
docker compose logs -f          # All services
docker compose logs -f open-webui    # OpenWebUI only
```

### Restart Services
```bash
docker compose restart          # All services
docker compose restart open-webui    # OpenWebUI only
```

### Stop/Start
```bash
docker compose down             # Stop all
docker compose up -d            # Start all
```

### Update Images
```bash
docker compose pull
docker compose up -d
```

## Troubleshooting

**Docker MUST be installed via apt, NOT snap!**

Docker installed via snap has critical limitations:
- ❌ NVIDIA GPU support doesn't work
- ❌ Volume mount restrictions
- ❌ Limited systemd integration

The script will detect snap Docker and offer to reinstall it properly via apt.

**If you have Docker snap, remove it first:**
```bash
sudo snap remove docker
```

### File permissions and mount points

Make sure the script and related files have the correct permissions before running the installation.

Running the script from a mounted filesystem can cause permission-related errors; it is recommended to place and execute the script directly from a local partition instead of a mount point.

### Services not starting?
```bash
# Check container status
docker compose ps

# View detailed logs
docker compose logs
```

### OpenWebUI not accessible?
OpenWebUI takes 2-3 minutes to fully initialize on first start. Check logs:
```bash
docker logs open-webui
```

### Port conflicts?
Edit ports in `docker-compose.yml` or stop conflicting services:
```bash
sudo systemctl stop apache2  # or nginx
```

## Contributing

Contributions welcome! Please feel free to submit issues or pull requests.

## License

MIT License - See [LICENSE](LICENSE) file for details

## Author

**sypher93**
GitHub: [@sypher93](https://github.com/sypher93)


## Links

- GitHub: https://github.com/sypher93/ollama-bundle
- OpenWebUI: https://github.com/open-webui/open-webui
- Ollama: https://ollama.ai

---

⭐ **Star this repo** if you find it useful!

**Made with ❤️ for the self-hosted AI community**