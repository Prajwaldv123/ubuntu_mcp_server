# ============================================================
# ubuntu_mcp_server - Airgapped Image (linux/amd64)
# Base: ubuntu:22.04 — single stage, system Python, no venv
# ============================================================

FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV MCP_LOG_LEVEL=INFO
ENV MCP_POLICY=secure
ENV MCP_PORT=8080

# Install Python + runtime OS tools, clean up in same layer
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        python3.11 \
        python3.11-dev \
        python3-pip \
        coreutils \
        findutils \
        grep \
        ca-certificates \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Point python3 → python3.11, then upgrade pip via itself (no flags needed inside Docker)
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
 && pip3 install --no-cache-dir --upgrade pip

WORKDIR /app

# Install ALL Python deps into system Python
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt \
 && pip3 install --no-cache-dir mcp-proxy \
 # Smoke-test: fail the build now if anything is missing
 && python3 -c "import mcp; import mcp_proxy; print('OK: mcp + mcp_proxy importable')"

# Copy only files needed at runtime
COPY main.py config.py config.json ./
COPY docker-entrypoint.sh ./
RUN chmod +x /app/docker-entrypoint.sh

RUN mkdir -p /tmp/mcp_logs \
 && useradd -m -s /bin/bash mcpuser \
 && chown -R mcpuser:mcpuser /app /tmp/mcp_logs

USER mcpuser

EXPOSE 8080

ENTRYPOINT ["/bin/bash", "/app/docker-entrypoint.sh"]
