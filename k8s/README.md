# Kubernetes Deployment - Container Health Monitor

Complete Kubernetes manifests for deploying the Container Health Monitor project (CSE 363 - Cloud Computing).

## 📋 File Structure

### Core Manifests (Required)
- **01-namespace.yaml** - Kubernetes namespace for isolation
- **02-configmap.yaml** - Configuration data (Prometheus config, DB init script)
- **03-secret.yaml** - Sensitive data (DB password, API URLs)
- **04-pvc.yaml** - PersistentVolumeClaims for database, Prometheus, Grafana

### Deployments (Required)
- **05-db-deployment.yaml** - PostgreSQL database
- **06-backend-deployment.yaml** - FastAPI backend + ServiceAccount
- **07-frontend-deployment.yaml** - React + Nginx frontend
- **08-prometheus-deployment.yaml** - Prometheus monitoring
- **09-grafana-deployment.yaml** - Grafana dashboards

### Services (Required)
- **10-services.yaml** - ClusterIP, NodePort services

### Advanced Features (Optional)
- **11-ingress.yaml** - Ingress controller for routing (requires nginx-ingress)
- **12-hpa.yaml** - Horizontal Pod Autoscaler for auto-scaling

## 🚀 Quick Start

### Prerequisites
- Kubernetes cluster (Minikube, Docker Desktop K8s, or Cloud)
- kubectl CLI installed
- Docker images built

### Option 1: PowerShell Script (Windows)
\\\powershell
cd k8s
.\Deploy-K8s.ps1 -platform minikube -build
\\\

### Option 2: Manual kubectl
\\\ash
# Apply all manifests in order
kubectl apply -f 01-namespace.yaml
kubectl apply -f 02-configmap.yaml
kubectl apply -f 03-secret.yaml
kubectl apply -f 04-pvc.yaml
kubectl apply -f 05-db-deployment.yaml
kubectl apply -f 06-backend-deployment.yaml
kubectl apply -f 07-frontend-deployment.yaml
kubectl apply -f 08-prometheus-deployment.yaml
kubectl apply -f 09-grafana-deployment.yaml
kubectl apply -f 10-services.yaml

# Or apply all at once:
kubectl apply -f .
\\\

## 🎯 Kubernetes Architecture

\\\
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (chm namespace)         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Frontend Deployment (2 replicas)                       │
│  ├─ Nginx Pod 1 ───────┐                              │
│  └─ Nginx Pod 2 ───────┼──→ Frontend Service (NodePort) │
│                        │    :3000                       │
│                        │                                │
│  Backend Deployment (2 replicas)                        │
│  ├─ FastAPI Pod 1 ─────┼──→ Backend Service (ClusterIP)│
│  └─ FastAPI Pod 2 ─────┘    :8000                      │
│         ↓                                               │
│    [ConfigMap] [Secret] [ServiceAccount]               │
│         ↓                                               │
│  DB Deployment (1 replica)                             │
│  └─ PostgreSQL Pod ────────→ DB Service (Headless)     │
│         ↓                    :5432                      │
│    [db-pvc: 5Gi]                                        │
│                                                         │
│  Prometheus Deployment (1 replica)                      │
│  └─ Prometheus Pod ────────→ Prometheus Service        │
│         ↓                    (NodePort) :9090           │
│    [prometheus-pvc: 5Gi]                               │
│                                                         │
│  Grafana Deployment (1 replica)                         │
│  └─ Grafana Pod ───────────→ Grafana Service           │
│         ↓                    (NodePort) :3001           │
│    [grafana-pvc: 2Gi]                                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
\\\

## 📊 Service Access

### Minikube
\\\ash
minikube service frontend -n chm      # Frontend
minikube service prometheus -n chm    # Prometheus
minikube service grafana -n chm       # Grafana
\\\

### Docker Desktop / Cloud
\\\ash
kubectl port-forward -n chm svc/frontend 3000:80
kubectl port-forward -n chm svc/backend 8000:8000
kubectl port-forward -n chm svc/prometheus 9090:9090
kubectl port-forward -n chm svc/grafana 3000:3000
\\\

## 🔧 Common Operations

### View Resources
\\\ash
kubectl get all -n chm
kubectl get pods -n chm -o wide
kubectl get svc -n chm
kubectl get pvc -n chm
\\\

### Pod Management
\\\ash
# View logs
kubectl logs -n chm deployment/backend -f

# Exec into pod
kubectl exec -it -n chm deployment/backend -- /bin/bash

# Describe pod
kubectl describe pod -n chm <pod-name>
\\\

### Scaling
\\\ash
kubectl scale deployment backend -n chm --replicas=3
kubectl scale deployment frontend -n chm --replicas=2
\\\

### Resource Monitoring
\\\ash
kubectl top nodes
kubectl top pods -n chm
kubectl describe nodes
\\\

## 🐛 Troubleshooting

### Pod not starting
\\\ash
kubectl describe pod -n chm <pod-name>
kubectl logs -n chm <pod-name>
\\\

### Database connection issues
\\\ash
# Check DB service
kubectl get svc db -n chm

# Test DB connectivity
kubectl run -it --rm debug --image=postgres:15-alpine --restart=Never -n chm \
  -- psql -h db -U postgres -d monitor
\\\

### Storage issues
\\\ash
# Check PVCs
kubectl get pvc -n chm

# Check PV
kubectl get pv

# Describe PVC
kubectl describe pvc -n chm <pvc-name>
\\\

## 🔌 Networking

- **Service DNS**: \<service>.<namespace>.svc.cluster.local\
- **Examples**:
  - \db:5432\ (within same namespace)
  - \db.chm.svc.cluster.local:5432\ (from other namespaces)
  - \ackend:8000\
  - \prometheus:9090\

## 🔐 Security Notes

⚠️ **Development Only Configuration**
- Secrets stored in plain YAML (not production-ready)
- Images use \imagePullPolicy: Never\ (development)
- CORS set to "*" (insecure)

**For Production:**
- Use Secret Encryption at Rest
- Use external Secret management (Vault, AWS Secrets Manager)
- Use private container registries
- Implement Network Policies
- Add RBAC policies
- Use TLS/SSL certificates

## 📈 Scaling & Advanced Features

### Enable Horizontal Pod Autoscaling
\\\ash
kubectl apply -f 12-hpa.yaml

# Check HPA status
kubectl get hpa -n chm
kubectl describe hpa -n chm backend-hpa
\\\

### Enable Ingress
\\\ash
# Install nginx-ingress controller first
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx

# Apply ingress manifest
kubectl apply -f 11-ingress.yaml
\\\

## 🗑️ Cleanup

\\\ash
# Delete entire namespace and all resources
kubectl delete namespace chm

# Or use the PowerShell script
.\Deploy-K8s.ps1 -delete
\\\

## 📚 Reference

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/)
- [Docker Desktop Kubernetes](https://docs.docker.com/desktop/kubernetes/)

## ✅ Verification Checklist

- [ ] Kubernetes cluster running
- [ ] kubectl configured and accessible
- [ ] Docker images built locally
- [ ] \kubectl apply -f k8s/\ executed successfully
- [ ] All pods running: \kubectl get pods -n chm\
- [ ] All services ready: \kubectl get svc -n chm\
- [ ] Frontend accessible via NodePort
- [ ] Database initialized successfully
- [ ] Prometheus scraping metrics
- [ ] Grafana connected to Prometheus
