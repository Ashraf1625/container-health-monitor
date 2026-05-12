#!/usr/bin/env bash
# =============================================================================
# setup.sh — Container Health Monitor — One-command startup
# Usage: bash setup.sh
# =============================================================================

set -euo pipefail

echo "=== Container Health Monitor — CSE 363, Galala University ==="
echo ""

# Check docker is available
if ! command -v docker &> /dev/null; then
  echo "ERROR: docker not found. Install Docker first."
  exit 1
fi

if ! docker compose version &> /dev/null; then
  echo "ERROR: docker compose plugin not found."
  exit 1
fi

echo "[1/4] Pulling base images..."
docker compose pull --ignore-pull-failures 2>/dev/null || true

echo "[2/4] Building custom images (frontend + backend)..."
docker compose build --no-cache

echo "[3/4] Starting all services in detached mode..."
docker compose up -d

echo "[4/4] Waiting for backend health check..."
TRIES=0
until curl -fsS http://localhost:8000/health > /dev/null 2>&1; do
  TRIES=$((TRIES + 1))
  if [ "$TRIES" -gt 40 ]; then
    echo "ERROR: Backend did not become healthy. Check: docker compose logs backend"
    exit 1
  fi
  echo "  ... waiting ($TRIES/40)"
  sleep 3
done

echo ""
echo "=== All services are UP ==="
docker compose ps
echo ""
HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
echo "  Dashboard  : http://${HOST_IP}:3000"
echo "  API docs   : http://${HOST_IP}:8000/docs"
echo "  Grafana    : http://${HOST_IP}:3001  (admin / admin)"
echo "  Prometheus : http://${HOST_IP}:9090"
echo ""
echo "Run 'bash demo.sh' to walk through all course requirements."
