#!/bin/bash
set -e

POLICY="${MCP_POLICY:-secure}"
PORT="${MCP_PORT:-8080}"

echo "[entrypoint] Python: $(python3 --version)"
echo "[entrypoint] mcp-proxy: $(mcp-proxy --version 2>&1)"
echo "[entrypoint] Starting MCP server — policy=${POLICY} port=${PORT}"

exec mcp-proxy \
  --host 0.0.0.0 \
  --port "${PORT}" \
  -- \
  python3 /app/main.py --policy "${POLICY}"