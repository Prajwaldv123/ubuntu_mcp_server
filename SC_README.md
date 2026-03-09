cat > /tmp/README.md << 'EOF'
# Secure Ubuntu MCP Server

An MCP (Model Context Protocol) server that gives AI agents like OpenCode secure, controlled access to Ubuntu system operations — including Docker and Kubernetes management.

---

## Architecture

```
OpenCode (Local Mac)
        │
        │ HTTP (direct or SSH tunnel)
        ▼
MCP Server Container (Remote Ubuntu VM :8080)
        │
        ├── Docker socket (/var/run/docker.sock)
        └── kubectl + kubeconfig
```

---

## Prerequisites

- Docker with buildx support (on build machine)
- SSH access to the remote Ubuntu VM
- OpenCode installed on local machine

---

## Installation

### Step 1 — Clone the Repository

```bash
git clone https://github.com/Prajwaldv123/ubuntu_mcp_server.git
cd ubuntu_mcp_server
```

### Step 2 — Build the Docker Image

Run this on an **internet-connected machine**:

```bash
docker buildx build \
  --platform linux/amd64 \
  -t ubuntu_mcp_server:latest \
  --load .
```

### Step 3 — Export the Image

```bash
docker save ubuntu_mcp_server:latest | gzip > ubuntu-mcp-server.tar.gz
```

### Step 4 — Transfer to the Remote VM

```bash
scp ubuntu-mcp-server.tar.gz onprem_shell@<VM_IP_ADDRESS>:/tmp
```

### Step 5 — Load the Image on the Remote VM

SSH into the remote VM and load the image:

```bash
ssh onprem_shell@<VM_IP_ADDRESS>

# On the remote VM:
docker load < /tmp/ubuntu-mcp-server.tar.gz
```

### Step 6 — Prepare kubeconfig

```bash
# Copy kubeconfig to a world-readable location
cp /root/.kube/config /tmp/kube-config
chmod 644 /tmp/kube-config
```

### Step 7 — Run the Container

```bash
docker run -d \
  --name ubuntu_mcp_server \
  --hostname onprem-node-mcp \
  -p 8080:8080 \
  -e MCP_POLICY=secure \
  -e MCP_LOG_LEVEL=INFO \
  -e MCP_PORT=8080 \
  -v mcp_audit_logs:/tmp/mcp_logs \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker \
  -v $(which kubectl):/usr/local/bin/kubectl \
  -v /tmp/kube-config:/tmp/kube-config:ro \
  -v /:/mnt/host:ro \
  -e KUBECONFIG=/tmp/kube-config \
  --restart unless-stopped \
  ubuntu_mcp_server:latest
```

---

## Validation

Verify the MCP server is running and responding correctly:

```bash
curl -s -X POST http://<VM_IP_ADDRESS>:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

Expected response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": { "tools": {} },
    "serverInfo": { "name": "Secure Ubuntu Controller", "version": "1.26.0" }
  }
}
```

---

## OpenCode Integration

### Step 1 — Install OpenCode

```bash
brew install anomalyco/tap/opencode
```

### Step 2 — Configure OpenCode

```bash
cat > ~/.config/opencode/opencode.json << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "model": "anthropic/claude-sonnet-4-5",
  "mcp": {
    "ubuntu-system": {
      "type": "remote",
      "url": "http://<VM_IP_ADDRESS>:8080/sse",
      "enabled": true
    }
  }
}
EOF
```

> Replace `<VM_IP_ADDRESS>` with your actual VM IP address.

### Step 3 — Set API Key

```bash
export ANTHROPIC_API_KEY="sk-ant-your-key-here"

# Make it permanent
echo 'export ANTHROPIC_API_KEY="sk-ant-your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

### Step 4 — Launch OpenCode

```bash
opencode
```

Verify MCP connection inside the TUI:
```
/mcp
```

You should see `ubuntu-system` listed as connected.

---

## Usage Examples

Once connected, type naturally in OpenCode:

```
list all kubernetes pods across all namespaces
list all docker containers on the host
check disk usage and memory on the system
what is the OS version of the connected server
show running processes on the remote system
```

---

## Security

The MCP server runs with a security policy that:

- **Allows** all standard system, Docker, and Kubernetes commands
- **Blocks** destructive commands: `rm`, `shutdown`, `reboot`, `chmod`, `kill`, etc.
- **Runs as non-root** (`mcpuser`) inside the container
- **Audit logging** enabled — all commands logged to `/tmp/mcp_logs`

To restrict access, bind the port to localhost and use an SSH tunnel instead:

```bash
# Run with localhost-only binding
-p 127.0.0.1:8080:8080

# Open SSH tunnel from your local machine
ssh -N -L 18080:127.0.0.1:8080 onprem_shell@<VM_IP_ADDRESS>

# Use tunnel URL in opencode.json
"url": "http://localhost:18080/sse"
```

---

## Troubleshooting

| Issue | Fix |
|---|---|
| `exec format error` | Rebuild with `--platform linux/amd64` |
| `No module named 'mcp'` | Rebuild image — pip install failed silently |
| `Command not whitelisted` | Set `command_whitelist_mode=False` in `main.py` |
| `permission denied` on kubeconfig | Run `chmod 644 /tmp/kube-config` on the VM |
| Empty docker output in OpenCode | Mount `/var/run/docker.sock` and `/usr/bin/docker` |
| MCP not connected in OpenCode | Check URL uses `/sse` endpoint, not `/mcp` |
| Port already in use (SSH tunnel) | Use a different local port e.g. `18080` |

---

## License

MIT
EOF

