# CSE 363 — Cloud Computing  
# Project Proposal: Container Health Monitor

---

## 1. Project Title & Description

**Title:** Container Health Monitor

**Description:**  
A cloud-native automation tool that continuously monitors all Docker containers running on a host. The system collects real-time CPU and memory metrics, exposes them through a React web dashboard and a Grafana monitoring panel, and persists every management action (stop, restart) in a PostgreSQL database. Operators can stop and restart containers directly from the browser, with every action timestamped and logged.

---

## 2. Problem Statement & Target Audience

**Problem:**  
In cloud and DevOps environments, multiple containerised services run simultaneously on shared infrastructure. Without visibility into resource consumption and container health, a single misbehaving service can exhaust host resources, degrade all other services, and cause downtime that is difficult to diagnose after the fact.

**Target Audience:**  
- System administrators managing self-hosted Docker deployments  
- DevOps engineers in small teams without access to paid cloud monitoring tools  
- Students and instructors learning cloud computing and containerisation concepts

---

## 3. Compute Approach

**Choice:** Containers (Docker + Docker Compose)

**Rationale:**  
Containers provide lightweight, fast-starting isolation through Linux namespaces and cgroups — exactly the mechanism taught in the virtualization lectures. Using Docker Compose lets us declare five services, their resource limits, network attachments, and restart policies in a single reproducible file. Virtual machines would add unnecessary overhead (full OS per service) for a tightly-coupled monitoring stack where all services run on the same physical or virtual host.

---

## 4. Scalability / High Availability Choice

**Choice: Option B — High Availability**

**Rationale:**  
The Container Health Monitor is a monitoring tool — it must remain available even when individual services fail. Option B (restart policies + healthchecks) is a better fit than load balancing (Option A) because:

1. **The application is stateful** — the backend holds a Docker client connection and the database holds operation logs. Distributing these across replicas would require session synchronisation.  
2. **The failure domain is single-host** — load balancing adds network infrastructure that is unnecessary at this scale.  
3. **Healthchecks directly implement the "self-healing" cloud property** — a core concept from the lectures on cloud characteristics.

---

## 5. Architecture Overview

```
                    ┌─────────────────────────────────┐
                    │         monitor-net              │
                    │       172.28.0.0/16 bridge       │
                    │                                  │
  :3000  ┌──────────┤ chm-frontend (React + nginx)    │
  ──────▶│          │   • Serves React SPA             │
         │          │   • Proxies /api → backend:8000  │
         │          └──────────────┬──────────────────-┘
         │                         │
         │          ┌──────────────▼──────────────────-┐
  :8000  │          │ chm-backend (FastAPI + Python)   │
  ──────▶│          │   • REST API (containers, events)│
         │          │   • Reads Docker socket           │
         │          │   • Writes events → PostgreSQL    │
         │          │   • Exposes /metrics (Prometheus)│
         │          └─────────────┬────────────────────┘
         │                        │
         │          ┌─────────────▼────────────────────┐
  :5432  │          │ chm-db (PostgreSQL 15)           │
  ───────│          │   • events table                  │
  (int.) │          │   • db-data named volume          │
         │          └──────────────────────────────────┘
         │
         │          ┌──────────────────────────────────┐
  :9090  │          │ chm-prometheus                   │
  ──────▶│          │   • Scrapes backend every 10 s   │
         │          │   • prometheus-data volume        │
         │          └─────────────┬────────────────────┘
         │                        │
         │          ┌─────────────▼────────────────────┐
  :3001  │          │ chm-grafana                      │
  ──────▶│          │   • Visualises Prometheus data    │
         │          │   • Pre-provisioned dashboard     │
         │          └──────────────────────────────────┘
```

**Network:** Single `monitor-net` bridge. All inter-service traffic uses hostnames. Only the four ports (3000, 8000, 9090, 3001) are published to the host.

---

## 6. Group Members

| Name | Student ID |
|------|------------|
| *(Member 1)* | *(ID)* |
| *(Member 2)* | *(ID)* |
| *(Member 3)* | *(ID)* |
| *(Member 4)* | *(ID)* |

**Course:** CSE 363 — Cloud Computing  
**Faculty:** Computer Science and Engineering, Galala University  
**Submission Term:** Spring 2026
