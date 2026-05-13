# Kubernetes Deployment Guide for Container Health Monitor
# Supports: Minikube, Docker Desktop Kubernetes, and Cloud (EKS/GKE/AKS)

## Prerequisites
# 1. Kubernetes cluster running (Minikube or Docker Desktop Kubernetes)
# 2. kubectl CLI installed and configured
# 3. Docker images built locally

## Quick Start - Minikube

### Step 1: Start Minikube
minikube start --cpus=4 --memory=8192 --disk-size=40g

### Step 2: Point Docker to Minikube
eval  (on Linux/macOS)
# On Windows PowerShell:
# minikube docker-env | Invoke-Expression

### Step 3: Build Docker Images in Minikube
docker-compose build

### Step 4: Deploy to Kubernetes
kubectl apply -f k8s/

### Step 5: Verify Deployment
kubectl get pods -n chm
kubectl get svc -n chm

### Step 6: Access Services
minikube service frontend -n chm    # Opens http://frontend
minikube service prometheus -n chm  # Opens http://prometheus:9090
minikube service grafana -n chm     # Opens http://grafana:3000

## Docker Desktop Kubernetes

### Step 1: Enable Kubernetes
# Go to Docker Desktop > Settings > Kubernetes > Enable Kubernetes

### Step 2: Build Images Locally
docker-compose build

### Step 3: Deploy
kubectl apply -f k8s/

### Step 4: Port Forward
kubectl port-forward -n chm svc/frontend 3000:80
kubectl port-forward -n chm svc/prometheus 9090:9090
kubectl port-forward -n chm svc/grafana 3000:3000

## Common Commands

# View all resources
kubectl get all -n chm

# View pod logs
kubectl logs -n chm -f deployment/backend

# Describe pod
kubectl describe pod -n chm <pod-name>

# Scale deployment
kubectl scale deployment backend -n chm --replicas=3

# Delete all resources
kubectl delete namespace chm

# Port forward specific service
kubectl port-forward -n chm svc/backend 8000:8000

## Troubleshooting

# Check pod status
kubectl get pods -n chm -o wide

# Check events
kubectl describe namespace chm

# View container logs
kubectl logs -n chm <pod-name> <container-name>

# Get detailed pod info
kubectl get pods -n chm -o yaml

# Check resource usage
kubectl top nodes
kubectl top pods -n chm
