# Container Health Monitor

**CSE 363 — Cloud Computing | Galala University | Faculty of Computer Science and Engineering**

A real-time Docker container monitoring dashboard built as a cloud-native application. The system collects live CPU and memory metrics, logs every operation to PostgreSQL, exposes Prometheus metrics for Grafana, and provides stop/restart controls through a React dashboard.

---

## Architecture Overview

```
Browser
   │
   ▼
┌──────────────┐  :3000
│  chm-frontend │  (React + nginx)
│              │
└──────┬───────┘
       │ /api/* → proxy
       ▼
┌──────────────┐  :8000          ┌───────────────┐  :5432
│  chm-backend  │────────────────▶│   chm-db      │
│  (FastAPI)   │ DATABASE_URL    │ (PostgreSQL)  │
│              │                 └───────────────┘
│  /metrics    │
└──────┬───────┘
       │ scrape (10 s)
       ▼
┌──────────────┐  :9090
│chm-prometheus│
│              │
└──────┬───────┘
       │ datasource
       ▼
┌──────────────┐  :3001
│  chm-grafana │
└──────────────┘

All services → monitor-net (172.28.0.0/16 bridge network)
```

---

## Services

| Container | Image | Role | Port |
|-----------|-------|------|------|
| `chm-frontend` | Custom (React + nginx) | UI dashboard | 3000 |
| `chm-backend` | Custom (FastAPI + Python) | REST API, Docker socket | 8000 |
| `chm-db` | postgres:15-alpine | Persistent event store | 5432 (internal) |
| `chm-prometheus` | prom/prometheus:v2.53.0 | Metrics collection | 9090 |
| `chm-grafana` | grafana/grafana:11.2.0 | Metrics visualization | 3001 |

---

## Quick Start

### Requirements
- Ubuntu 22.04+ VM **or** WSL2 with Docker Desktop  
- Docker Engine + Compose plugin  
- ≥ 2 GB free RAM

### Install Docker (Ubuntu)

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y docker.io docker-compose-plugin curl
sudo usermod -aG docker $USER
newgrp docker
docker --version && docker compose version
```

### Run the project

```bash
# From the project root:
bash setup.sh

# Or manually:
docker compose up --build -d
docker compose ps
```

### Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Dashboard | http://localhost:3000 | — |
| API (Swagger) | http://localhost:8000/docs | — |
| Grafana | http://localhost:3001 | admin / admin |
| Prometheus | http://localhost:9090 | — |

From another machine on the same network, replace `localhost` with your VM's IP (`ip addr show`).

---

## Course Requirements — How Each Is Satisfied

### 1. Compute Layer ✅
Five containers run in isolated Linux namespaces enforced by Docker's use of kernel cgroups and namespaces. Each service (frontend, backend, db, prometheus, grafana) has its own PID, network, and filesystem namespace.

```bash
docker compose ps          # see all 5 containers
docker compose top         # see processes per container
```

### 2. Network Virtualization ✅
All services communicate exclusively via the `monitor-net` bridge network (subnet `172.28.0.0/16`). Services are addressed by **hostname** (e.g. `http://backend:8000`, `postgresql://postgres:secret@db:5432`). No hardcoded IPs anywhere.

```bash
docker network inspect container-health-monitor_monitor-net
docker compose exec backend ping -c 3 db
docker compose exec backend ping -c 3 prometheus
```

### 3. Data Persistence ✅
PostgreSQL data is stored in the `db-data` named volume. Prometheus time-series in `prometheus-data`. Grafana settings in `grafana-data`. Data survives service restarts.

```bash
# Demonstrate:
docker compose stop db
docker compose start db
# → events table still has all rows
docker compose exec db psql -U postgres -d monitor -c "SELECT count(*) FROM events;"
```

### 4. Resource Management ✅
All five services have explicit CPU and memory limits configured via `deploy.resources.limits` in `docker-compose.yml`:

| Service | CPU Limit | Memory Limit |
|---------|-----------|--------------|
| frontend | 0.50 | 128 MB |
| **backend** | **1.00** | **512 MB** |
| **db** | **0.75** | **512 MB** |
| prometheus | 0.50 | 256 MB |
| grafana | 0.50 | 256 MB |

```bash
docker stats --no-stream
docker inspect chm-backend --format '{{.HostConfig.Memory}}'
```

Without these limits, a single runaway container could starve all others on the host — exactly the problem resource pooling in cloud computing solves.

### 5. High Availability — Option B ✅
Every service has `restart: always` and a Docker healthcheck. If a container crashes or fails its healthcheck, Docker automatically detects and restarts it.

```bash
# Demonstrate auto-recovery:
docker compose stop backend
sleep 15
docker compose ps backend         # should show "restarting" then "running"
curl http://localhost:8000/health  # returns {"status":"ok",...}
```

### 6. Cloud Deployment ✅
All ports are bound to `0.0.0.0`, making every service reachable from any machine on the same network. For internet access, use ngrok:

```bash
# LAN access:
ip addr show   # note your VM IP
# → http://<VM-IP>:3000  accessible from any device on the same network

# Internet access (optional):
ngrok http 3000
```

---

## Bonus: Live Monitoring Dashboard ✅
Grafana (port 3001) shows:
- **HTTP request rate** (req/s) — live line chart
- **Latency p50, p95, p99** — from Prometheus histograms
- **Error rate** (4xx + 5xx) — with threshold alerting colours
- **Active in-flight requests**
- **Requests per endpoint** — bar gauge

---

## Demo Script

```bash
bash demo.sh
```
Walks through all 6 requirements with live terminal output.

---

## API Reference (key endpoints)

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness probe — used by Docker healthcheck |
| GET | `/containers` | All containers with CPU/mem stats |
| POST | `/containers/{name}/stop` | Stop a container (logged to DB) |
| POST | `/containers/{name}/restart` | Restart a container (logged to DB) |
| GET | `/events` | Last 100 operation log entries |
| POST | `/simulation/start` | Launch 3 load generators for demo |
| POST | `/simulation/stop` | Stop load generators |
| GET | `/metrics` | Prometheus metrics exposition |
| GET | `/docs` | OpenAPI / Swagger UI |

---

## Packaging for Submission (Windows)

```powershell
# From the parent folder:
Compress-Archive -Path .\container-health-monitor -DestinationPath .\container-health-monitor.zip
```

---

## Project Team

| Name | Student ID |
|------|------------|
| *(add your name)* | *(add your ID)* |
| *(add your name)* | *(add your ID)* |
| *(add your name)* | *(add your ID)* |
| *(add your name)* | *(add your ID)* |

**Course:** CSE 363 — Cloud Computing  
**Faculty:** Faculty of Computer Science and Engineering  
**University:** Galala University
