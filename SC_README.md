# Secure Ubuntu MCP Server Installation Steps


### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/secure-ubuntu-mcp.git
cd secure-ubuntu-mcp

docker buildx build \
  --platform linux/amd64 \
  -t ubuntu_mcp_server:latest \
  --load .

then 
docker save ubuntu_mcp_server:latest | gzip > ubuntu-mcp-server.tar.gz


then scp to remote SC server using ssh 

scp -r ubuntu-mcp-server.tar.gz onprem_shell@<IP Adress>:/tmp