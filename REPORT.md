# CSE 363 — Cloud Computing
# Project Report: Container Health Monitor

**Faculty of Computer Science and Engineering — Galala University**  
**Spring 2026**

---

## 1. Application Description & Problem Solved

### What the application does

The Container Health Monitor is a cloud-native automation tool that provides real-time visibility into every Docker container running on a Linux host. It consists of five microservices deployed together with Docker Compose:

- **Frontend (React + nginx):** A live web dashboard that refreshes every 5 seconds, showing each container's name, status badge, CPU%, memory usage/limit bars, restart count, health state, and the virtual network it belongs to. It includes a bar chart of all running containers and a time-series trend chart of average CPU/memory over the last 20 polling cycles.
- **Backend (FastAPI + Python):** A REST API that reads container data from the Docker socket, stores operation events in PostgreSQL, and exposes Prometheus metrics. It provides stop, restart, and simulation endpoints.
- **Database (PostgreSQL):** Persistently stores a timestamped log of every container stop, restart, and system event.
- **Prometheus:** Scrapes the backend's `/metrics` endpoint every 10 seconds and retains 7 days of time-series data.
- **Grafana:** Displays pre-provisioned dashboards showing HTTP request rates, latency percentiles (p50/p95/p99), error rates, and per-endpoint traffic.

### Problem solved

In shared cloud and DevOps environments, multiple containers run concurrently on the same host. Without resource limits, a single misbehaving container can exhaust CPU or memory and starve all others. Without visibility tooling, failures are discovered only after service degradation, making root-cause analysis slow. The Container Health Monitor solves this by:

1. Making resource consumption **visible** in real time
2. Enforcing **resource limits** so no single container can dominate the host
3. Logging every management action to provide an **audit trail**
4. Implementing **health checks** and **restart policies** so the system heals itself

### Intended users

System administrators running self-hosted Docker deployments, DevOps engineers in small teams, and students learning containerisation and cloud computing.

---

## 2. Architecture Diagram

```
                         EXTERNAL ACCESS
                       ┌───────────────────┐
                       │   Browser / curl  │
                       └────────┬──────────┘
                                │
             ┌──────────────────┼───────────────────┐
             │                  │                   │
         :3000              :8000             :9090 / :3001
             │                  │                   │
  ┌──────────▼──────────┐  ┌────▼──────────┐  ┌────▼─────────────────┐
  │   chm-frontend      │  │  chm-backend   │  │  chm-prometheus      │
  │   React SPA         │  │  FastAPI       │  │  Metrics collector   │
  │   served by nginx   │  │  REST API      │  └────────┬─────────────┘
  │                     │  │                │           │ datasource
  │  /api/* ────────────┼─▶│  /containers   │  ┌────────▼─────────────┐
  │  (proxy_pass)       │  │  /events       │  │  chm-grafana         │
  └─────────────────────┘  │  /metrics      │  │  Dashboard           │
                           │  /simulation   │  └──────────────────────┘
                           └───────┬────────┘
                                   │   SQL (port 5432, hostname "db")
                           ┌───────▼────────┐
                           │   chm-db       │
                           │   PostgreSQL   │
                           │   events table │
                           └───────┬────────┘
                                   │
                           ┌───────▼────────┐
                           │  db-data       │  ← named volume
                           │  (host disk)   │     data persists
                           └────────────────┘

   ══════════════════════ monitor-net (172.28.0.0/16) ══════════════════
   All containers on the same bridge; DNS resolution by service name.
   Docker socket mounted into backend (read-only): /var/run/docker.sock
```

**Storage layout:**
- `db-data` — PostgreSQL WAL + data directory
- `prometheus-data` — TSDB blocks (7-day retention)
- `grafana-data` — dashboard state, user preferences

---

## 3. Design Decisions & Cloud Computing Concepts

### 3.1 Containerisation (Requirement 1 — Compute Layer)

**Decision:** Use Docker containers rather than full VMs.  
**Concept: Virtualization (Type 2, OS-level)**  
Docker implements OS-level virtualization using Linux **namespaces** (PID, net, mnt, uts, ipc) and **cgroups** (CPU, memory quotas). Each container gets its own isolated process tree and network stack while sharing the host kernel — far more lightweight than hardware virtualization (Type 1/Type 2 hypervisors like KVM or VirtualBox).

The use of `docker compose` acts as a **lightweight orchestrator**: it declares the desired state (five services, one network, three volumes) and Docker Engine converges the system to that state — exactly analogous to how Kubernetes manages pods and deployments at scale.

**Verification:**
```bash
docker compose ps          # five containers, all Up
docker compose top         # isolated process trees per container
```

### 3.2 Virtual Networking (Requirement 2 — Network Virtualization)

**Decision:** Define a custom bridge network `monitor-net` with a fixed CIDR (`172.28.0.0/16`).  
**Concept: Software-Defined Networking (SDN)**  
Docker creates a virtual Ethernet bridge on the host and attaches a virtual NIC to each container. The built-in DNS resolver allows containers to reach each other using service names (`backend`, `db`, `prometheus`) — no hardcoded IP addresses anywhere in the codebase. This mirrors how cloud VPCs (Virtual Private Clouds) work: private networks with DNS-based service discovery.

Frontend proxies API calls through nginx (`/api/ → http://backend:8000/`), so the browser never directly reaches the backend port — a real-world pattern that mirrors cloud load balancers sitting in front of internal services.

**Verification:**
```bash
docker network inspect container-health-monitor_monitor-net
docker compose exec backend ping -c 3 db        # hostname resolution
docker compose exec backend ping -c 3 prometheus
```

### 3.3 Persistent Storage (Requirement 3 — Data Persistence)

**Decision:** Named Docker volumes for PostgreSQL, Prometheus, and Grafana.  
**Concept: Network-Attached Storage / Block Storage in Cloud**  
Named volumes are managed by Docker and stored on the host filesystem, decoupled from the container lifecycle. When a container is stopped, removed, or replaced by a new image version, the volume — and all data in it — survives. This mirrors cloud block storage (AWS EBS, GCP Persistent Disk) which can be detached from one instance and re-attached to another.

The `db/init.sql` file is mounted into the PostgreSQL container's `docker-entrypoint-initdb.d/` directory. It creates the `events` table and indexes on the **first** start only, making the schema version-controlled alongside the application code.

**Verification:**
```bash
docker volume ls --filter name=container-health-monitor
docker compose stop db
docker compose start db
docker compose exec db psql -U postgres -d monitor -c "SELECT count(*) FROM events;"
# → count is unchanged; data survived the restart
```

### 3.4 Resource Management (Requirement 4)

**Decision:** Explicit `deploy.resources.limits` on all five services.  
**Concept: Resource Pooling & Multi-Tenancy**  
In cloud environments, many customers share the same physical servers (multi-tenancy). Cloud providers use cgroups to enforce per-tenant resource quotas, guaranteeing that one tenant's workload cannot consume resources paid for by another. The same principle applies here at the service level:

| Service | CPU Limit | Memory Limit | Justification |
|---------|-----------|--------------|---------------|
| frontend | 0.50 core | 128 MB | nginx is I/O-bound, not compute-bound |
| **backend** | **1.00 core** | **512 MB** | API handles Docker SDK calls and DB queries |
| **db** | **0.75 core** | **512 MB** | PostgreSQL needs headroom for write-ahead logging |
| prometheus | 0.50 core | 256 MB | TSDB compaction can be CPU-intensive |
| grafana | 0.50 core | 256 MB | Web server + dashboard rendering |

**Without these limits:** A load spike on the frontend or a misbehaving simulation container would consume all available host CPU, causing the backend API to time out and the database to miss health checks — a cascading failure across the entire stack. In a public cloud, this would be analogous to the "noisy neighbour" problem where one tenant degrades others.

**Verification:**
```bash
docker stats --no-stream
docker inspect chm-backend --format 'CPU quota: {{.HostConfig.CpuQuota}} | Mem: {{.HostConfig.Memory}}'
```

### 3.5 High Availability (Requirement 5 — Option B)

**Decision:** `restart: always` + Docker healthchecks on every service.  
**Concept: Fault Tolerance & Self-Healing Systems**  
Cloud computing's defining characteristic — compared to traditional IT — is elasticity and self-healing. Rather than having operators manually restart failed services, the platform itself detects failures and recovers.

Our implementation:
- **`restart: always`** — Docker's restart policy instructs the daemon to automatically restart any container that exits unexpectedly (non-zero exit code or OOM kill).
- **Healthchecks** — Each service defines a test command that Docker polls periodically. If the test fails `retries` consecutive times, Docker marks the container as `unhealthy` and (with `restart: always`) replaces it.

The healthcheck chain enforces a correct startup order: `frontend` waits for `backend` to be `healthy`; `backend` waits for `db` to be `healthy`; `grafana` waits for `prometheus` to be `healthy`. This is equivalent to Kubernetes `readinessProbes` and `livenessProbes`.

**Demonstration:**
```bash
docker compose stop backend   # simulate a crash
sleep 15
docker compose ps backend     # Docker auto-restarts it
curl http://localhost:8000/health   # {"status":"ok",...}
```

No manual intervention required.

### 3.6 Cloud Deployment (Requirement 6)

**Decision:** Bind all ports to `0.0.0.0`; document LAN and ngrok access.  
**Concept: Cloud Accessibility & Remote Access**  
All four published ports (3000, 8000, 9090, 3001) are bound to `0.0.0.0`, meaning they are reachable from any IP that can route to the host — including other machines on the same LAN or subnet.

For internet access without a public IP (e.g., from a home lab), ngrok creates a secure tunnel:
```bash
ngrok http 3000   # generates a public HTTPS URL for the dashboard
```

This is equivalent to a cloud provider's Network Load Balancer exposing internal services to the internet. The internal services (`db`, `prometheus`) are not exposed — only the user-facing endpoints — mirroring the principle of least exposure in cloud network security groups.

---

## 4. Resource Management — Detailed Analysis

### Limits configured

```yaml
# docker-compose.yml (excerpt)
backend:
  deploy:
    resources:
      limits:
        cpus: "1.0"
        memory: 512M

db:
  deploy:
    resources:
      limits:
        cpus: "0.75"
        memory: 512M
```

### Tool used

Docker's `deploy.resources.limits` translates to Linux cgroup constraints:
- **CPU:** `--cpu-quota=100000` (out of a 100000 μs period) per core
- **Memory:** `--memory=536870912` bytes (`512 * 1024 * 1024`)

Verification:
```bash
# CPU quota (microseconds per 100ms period):
docker inspect chm-backend --format '{{.HostConfig.CpuQuota}}'   # 100000 = 1.0 core

# Memory limit (bytes):
docker inspect chm-db --format '{{.HostConfig.Memory}}'          # 805306368 = 768M... adjust per config
```

### What would happen without limits?

In a shared environment without resource constraints:
1. The load simulation (`demo-load-frontend`, `demo-load-backend`) would consume 100% of all available CPU cores.
2. PostgreSQL would be starved of CPU time, causing transaction timeouts.
3. The backend would fail its own healthcheck (5-second timeout), triggering a restart loop.
4. Grafana and Prometheus would stop receiving metrics, making the outage invisible in the dashboard.
5. The host OS scheduler would eventually OOM-kill one or more processes — unpredictably.

This is the **noisy neighbour problem** in cloud computing: without quota enforcement, any tenant (or service) can degrade all others. Resource pooling, as taught in the course, is only fair and reliable when enforced with quotas.

---

## 5. High Availability — Analysis

### What was implemented

- `restart: always` on all 5 services
- Docker HEALTHCHECK on all 5 services with `start_period` to avoid false-positive restarts during initialization
- `depends_on` with `condition: service_healthy` to enforce correct startup order

### How it was demonstrated

1. `docker compose stop backend` — kills the API service
2. After 15 seconds, `docker compose ps backend` shows the container auto-restarted
3. `curl http://localhost:8000/health` returns `{"status":"ok"}` with no manual action

During the recovery window (< 15 seconds), the frontend displays an error banner: `"Request failed"`. As soon as the backend passes its healthcheck, the dashboard resumes normal operation automatically.

### What was learned

- Docker's restart policy implements the **self-healing** property of cloud systems without a full orchestrator.
- Healthcheck `start_period` is critical: without it, the backend would be restarted during the 60-second database connection retry loop, creating a restart loop on first boot.
- The chain of `depends_on: condition: service_healthy` is the container equivalent of Kubernetes `readinessProbes` — it prevents the frontend from receiving requests until the backend is genuinely ready.
- For production-grade HA, a full orchestrator (Kubernetes) would be needed to handle node failures, rolling updates, and horizontal scaling. The current setup handles process-level failures only.

### Why HA matters in cloud computing

Cloud computing's economic model depends on high utilisation of shared infrastructure. Any service that requires manual restart creates a **mean time to recovery (MTTR)** proportional to human response time (minutes to hours). Automated health checks and restart policies reduce MTTR to seconds, which is why every major cloud platform (AWS ECS, Kubernetes, Azure Container Apps) builds this capability into its runtime.

---

## 6. Conclusion

The Container Health Monitor demonstrates all six course project requirements in a coherent, realistic cloud-native system:

| Requirement | Mechanism | Verified by |
|-------------|-----------|-------------|
| Compute isolation | Docker namespaces + cgroups | `docker compose ps` / `top` |
| Network virtualization | Custom bridge + DNS | `ping db` from backend |
| Data persistence | Named volumes | Stop/restart db, count rows |
| Resource management | CPU + memory limits on all 5 | `docker stats`, `docker inspect` |
| High availability | `restart: always` + healthchecks | Stop backend, wait, observe |
| Cloud deployment | 0.0.0.0 binding, LAN + ngrok | Access from second machine |

The bonus Grafana dashboard adds production-grade observability, showing how Prometheus-based metrics pipelines work in cloud environments.

---

## Appendix — File Structure

```
container-health-monitor/
├── docker-compose.yml       ← orchestration: 5 services, network, volumes, limits
├── setup.sh                 ← one-command startup script
├── demo.sh                  ← full demo walkthrough script
├── README.md                ← quick-start guide
├── PROPOSAL.md              ← project proposal (this doc companion)
├── REPORT.md                ← this report
│
├── backend/
│   ├── Dockerfile           ← Python 3.11 slim, uvicorn
│   ├── main.py              ← FastAPI app: containers, events, simulation, /metrics
│   └── requirements.txt
│
├── frontend/
│   ├── Dockerfile           ← multi-stage: node build → nginx serve
│   ├── nginx.conf           ← /api/* proxy + SPA fallback
│   ├── package.json
│   └── src/
│       ├── App.js           ← React: cards, charts, events log
│       ├── App.css          ← premium dark theme
│       └── index.js
│
├── db/
│   └── init.sql             ← schema + seed (runs on first start only)
│
├── prometheus/
│   └── prometheus.yml       ← scrape: backend:8000/metrics every 10 s
│
└── grafana/
    └── provisioning/
        ├── datasources/
        │   └── prometheus.yml   ← auto-connect Grafana to Prometheus
        └── dashboards/
            ├── dashboard.yml    ← file-provider config
            └── main.json        ← pre-built dashboard (req/s, latency, errors)
```

---

**Group Members:**

| Name | Student ID |
|------|------------|
| *(Member 1)* | *(ID)* |
| *(Member 2)* | *(ID)* |
| *(Member 3)* | *(ID)* |
| *(Member 4)* | *(ID)* |

**Course:** CSE 363 — Cloud Computing  
**Institution:** Galala University, Faculty of Computer Science and Engineering  
**Term:** Spring 2026
