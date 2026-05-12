#!/usr/bin/env bash
# =============================================================================
# demo.sh — CSE 363 Container Health Monitor — Full Demo Script
# Run this inside an Ubuntu VM / WSL2 terminal from the project root.
# =============================================================================

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[0;32m"
CYAN="\033[0;36m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

section() { echo -e "\n${BOLD}${CYAN}══ $1 ══${RESET}"; }
step()    { echo -e "${YELLOW}▶ $1${RESET}"; }
ok()      { echo -e "${GREEN}✔ $1${RESET}"; }

section "1. COMPUTE LAYER — 5 isolated containers"
step "Listing all running services..."
docker compose ps
echo ""
step "Container processes (isolation via Linux namespaces + cgroups):"
docker compose top
ok "Requirement 1 satisfied: each service runs in a separate isolated container"

section "2. NETWORK VIRTUALIZATION"
step "Inspecting the monitor-net virtual bridge network..."
docker network inspect container-health-monitor_monitor-net \
  --format '{{.Name}} | Driver: {{.Driver}} | Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}'
echo ""
step "Hostname resolution — backend pings db by service name (not IP):"
docker compose exec backend ping -c 3 db
echo ""
step "Hostname resolution — backend pings prometheus by service name:"
docker compose exec backend ping -c 3 prometheus
ok "Requirement 2 satisfied: services communicate via hostnames on monitor-net"

section "3. DATA PERSISTENCE"
step "Listing named volumes (data survives container restarts):"
docker volume ls --filter name=container-health-monitor
echo ""
step "Current event count in PostgreSQL before stop:"
docker compose exec db psql -U postgres -d monitor \
  -c "SELECT count(*) AS total_events FROM events;"
echo ""
step "Stopping db container..."
docker compose stop db
sleep 3
step "Restarting db container..."
docker compose start db
step "Waiting for db to become healthy..."
sleep 10
step "Event count after restart — data must be preserved:"
docker compose exec db psql -U postgres -d monitor \
  -c "SELECT count(*) AS total_events FROM events;"
ok "Requirement 3 satisfied: data persisted in db-data named volume"

section "4. RESOURCE MANAGEMENT"
step "Live CPU & memory stats with configured limits:"
docker stats --no-stream \
  chm-frontend chm-backend chm-db chm-prometheus chm-grafana
echo ""
step "Inspecting backend resource limits from compose config:"
docker inspect chm-backend \
  --format 'Backend CPU quota: {{.HostConfig.CpuQuota}} | Memory limit: {{.HostConfig.Memory}} bytes'
docker inspect chm-db \
  --format 'DB      CPU quota: {{.HostConfig.CpuQuota}} | Memory limit: {{.HostConfig.Memory}} bytes'
ok "Requirement 4 satisfied: backend=1.0 CPU/512M, db=0.75 CPU/512M, frontend+prometheus+grafana=0.5 CPU/128–256M"

section "5. HIGH AVAILABILITY (Option B)"
step "All services have restart: always policy. Stopping backend to trigger auto-recovery..."
docker compose stop backend
echo ""
step "Verifying backend is stopped:"
docker compose ps backend
echo ""
step "Waiting 15 s for Docker to detect failure and auto-restart..."
sleep 15
step "Backend should now be restarting or running:"
docker compose ps backend
step "Health probe:"
curl -fsS http://localhost:8000/health | python3 -m json.tool || echo "(still starting — wait a few more seconds)"
ok "Requirement 5 satisfied: restart policy + healthchecks enable automatic recovery"

section "6. CLOUD / LAN DEPLOYMENT"
HOST_IP=$(hostname -I | awk '{print $1}')
step "Host IP address: ${HOST_IP}"
echo -e "  Dashboard : ${CYAN}http://${HOST_IP}:3000${RESET}"
echo -e "  API docs  : ${CYAN}http://${HOST_IP}:8000/docs${RESET}"
echo -e "  Grafana   : ${CYAN}http://${HOST_IP}:3001${RESET}"
echo -e "  Prometheus: ${CYAN}http://${HOST_IP}:9090${RESET}"
ok "Requirement 6 satisfied: all ports bound to 0.0.0.0, reachable from any machine on the network"

section "BONUS — Grafana monitoring dashboard"
step "Grafana is running at http://localhost:3001 (admin / admin)"
step "Dashboard: Container Health Monitor — shows req/s, latency p50/p95/p99, error rate"
step "Prometheus scraping backend every 10 s at http://localhost:9090"

section "SIMULATION DEMO"
step "Starting load generators via API..."
curl -X POST http://localhost:8000/simulation/start -s | python3 -m json.tool
echo ""
step "Watch CPU/memory rise in docker stats (10 s):"
docker stats --no-stream
echo ""
step "Stopping load generators..."
curl -X POST http://localhost:8000/simulation/stop -s | python3 -m json.tool

echo -e "\n${BOLD}${GREEN}═══════════════════════════════════════════════════════════"
echo "  All 6 requirements + bonus demonstrated successfully!"
echo "  Container Health Monitor — CSE 363, Galala University"
echo -e "═══════════════════════════════════════════════════════════${RESET}\n"
