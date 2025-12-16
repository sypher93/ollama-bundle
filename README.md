# OpenWebUI + Nginx + Ollama Stack

**One-command deployment** for a complete AI chat interface with Ollama LLM backend and Nginx reverse proxy.

<a href="https://ibb.co/vCQ6Cc4j"><img src="https://i.ibb.co/qLW3LDYr/ollama-bundle-banner-sypher93.jpg" alt="ollama-bundle-banner-sypher93" border="0"></a>

## Features

- 🔧 **Automated installation** - Single script deploys everything
- 🐳 **Docker Compose** - Nginx + OpenWebUI + Ollama in one stack
- 🔒 **SSL/TLS support** - HTTP (simple) or HTTPS (advanced) modes
- 🎮 **GPU acceleration** - Optional NVIDIA GPU support
- 📦 **Modular architecture** - Easy to customize and maintain

## Prerequisites

- **OS**: Debian 12+ or Ubuntu 22.04+ (Tested on Debian 13 / Ubuntu Server 24.04)
- **Access**: Root or sudo privileges
- **CPU**: 4+ Cores
- **Disk**: 50GB+ free space
- **RAM**: 8GB+ recommended
- **GPU** (optional): NVIDIA GPU with drivers installed
- **Network**: Open ports 80 (HTTP) and/or 443 (HTTPS)

## Quick Start

```bash
# Clone repository
git clone https://github.com/sypher93/ollama-bundle.git
cd ollama-bundle

# Run installer
sudo chmod +x *.sh
sudo ./install.sh
```

### Installation Options

**Simple Mode** (HTTP)
- Quick setup for testing/development
- HTTP only (port 80)
- No SSL certificates

**Advanced Mode** (HTTPS)
- Production-ready with SSL
- Self-signed certificates
- HTTP → HTTPS redirect with TLS 1.3
- Enhanced security headers

Trivy scan (optional) on the Docker images used during installation on both options, output of this scan is recorded in `installation.log`.

## Post-Installation

If the installation went smoothly, you should see this result :

<a href="https://imgbb.com/"><img src="https://i.ibb.co/gbxGkKmh/ollama-bundle-installer-success-sypher93.png" alt="ollama bundle installer success sypher93" border="0"></a>

**Seamlessly Switching from HTTP to HTTPS:**

Start the installation over HTTPS at any time by rerunning `sudo ./install.sh` and choosing option 2 (Advanced HTTPS); the installer will detect your existing HTTP deployment, switch it to HTTPS without redownloading the containers, generate an SSL certificate, and add the secure Nginx configuration automatically.

### 1. Access OpenWebUI

Open your browser and navigate to:
- **Simple mode**: `http://YOUR_SERVER_IP`
- **Advanced mode**: `https://YOUR_SERVER_IP`

### 2. Create Admin Account

Register on first visit - the first user becomes admin.

### 3. Download AI Models

**Option A: Via Web Interface**

Navigate to **Models** tab and pull models directly:

<a href="https://ibb.co/rKNZHfz8"><img src="https://i.ibb.co/DPT7Qgvc/manage-models-ollama-bundle.png" alt="manage-models-ollama-bundle" border="0"></a>

You can now start a chat with the LLM of your choice :

<a href="https://ibb.co/bg8zHMwm"><img src="https://i.ibb.co/jv1gVP0f/chat-llm-ollama-bundle.png" alt="chat-llm-ollama-bundle" border="0"></a>

**Option B: Via Command Line**

```bash
# Pull a model
docker exec -it ollama ollama pull llama2

# List available models
docker exec -it ollama ollama list

# Remove a model
docker exec -it ollama ollama rm llama2
```

Popular models:
- `llama2` - Meta's general-purpose model
- `mistral` - Fast and efficient
- `codellama` - Optimized for code
- `phi` - Microsoft's small but capable model

## 🔧 Management

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

## Project Structure

```
ollama-bundle/
├── install.sh             # Main installer
├── functions.sh           # Core functions
├── menus.sh               # User interaction
├── generate-compose.sh    # Docker Compose generator
├── post_install.sh        # Verification checks
├── conf.d/                # Nginx configuration
├── ssl/                   # SSL certificates (advanced mode)
└── docker-compose.yml     # Generated compose file
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
- GitHub: [@sypher93](https://github.com/sypher93)

---

⭐ **Star this repo** if you find it useful!