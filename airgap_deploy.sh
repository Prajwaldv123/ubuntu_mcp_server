#!/usr/bin/env bash
# =============================================================
# airgap_deploy.sh
# Helper script for building the ubuntu-mcp-server image on an
# internet-connected machine and transferring it to an airgapped host.
#
# Usage:
#   On the BUILD machine (has internet):
#     bash airgap_deploy.sh build
#
#   On the AIRGAPPED machine (no internet):
#     bash airgap_deploy.sh load
#     bash airgap_deploy.sh run
# =============================================================

set -euo pipefail

IMAGE_NAME="ubuntu-mcp-server"
IMAGE_TAG="latest"
TARBALL="${IMAGE_NAME}.tar.gz"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

# ── STEP 1: Build (run on internet-connected machine) ─────────
build() {
  echo "==> [BUILD] Cloning repository..."
  if [ ! -d "ubuntu_mcp_server" ]; then
    git clone https://github.com/Prajwaldv123/ubuntu_mcp_server.git
  fi
  cd ubuntu_mcp_server

  echo "==> [BUILD] Copying Docker files into repo..."
  cp ../Dockerfile .
  cp ../docker-compose.yml .
  cp ../.dockerignore .

  echo "==> [BUILD] Building Docker image: ${FULL_IMAGE}"
  docker build -t "${FULL_IMAGE}" .

  echo "==> [BUILD] Saving image to tarball: ${TARBALL}"
  cd ..
  docker save "${FULL_IMAGE}" | gzip > "${TARBALL}"

  echo ""
  echo "✅ Done! Transfer these files to your airgapped machine:"
  echo "   • ${TARBALL}"
  echo "   • ubuntu_mcp_server/config.json  (optional – to customise policy)"
  echo "   • docker-compose.yml             (optional – for compose usage)"
}

# ── STEP 2: Load image on airgapped machine ───────────────────
load() {
  if [ ! -f "${TARBALL}" ]; then
    echo "❌ Tarball '${TARBALL}' not found in current directory."
    exit 1
  fi

  echo "==> [LOAD] Importing image from ${TARBALL}..."
  docker load < "${TARBALL}"
  echo "✅ Image loaded: ${FULL_IMAGE}"
  docker images | grep "${IMAGE_NAME}"
}

# ── STEP 3: Run on airgapped machine ─────────────────────────
run() {
  echo "==> [RUN] Starting MCP server container (stdio mode)..."

  # Claude Desktop / MCP client will launch this via its config.
  # For a manual stdio test:
  docker run --rm -i \
    --name ubuntu_mcp_server \
    -e MCP_LOG_LEVEL=INFO \
    -e MCP_POLICY=secure \
    -v mcp_audit_logs:/tmp/mcp_logs \
    "${FULL_IMAGE}" --policy secure
}

# ── Dispatch ──────────────────────────────────────────────────
case "${1:-help}" in
  build) build ;;
  load)  load  ;;
  run)   run   ;;
  *)
    echo "Usage: $0 {build|load|run}"
    echo ""
    echo "  build  – (internet machine) clone repo, build image, export tarball"
    echo "  load   – (airgapped machine) import tarball into Docker"
    echo "  run    – (airgapped machine) start the MCP server container"
    ;;
esac
