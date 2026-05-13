# Deploy-K8s.ps1 - Kubernetes Deployment Script for Container Health Monitor

param(
    [ValidateSet('minikube', 'docker-desktop', 'cloud')]
    [string]$platform = 'minikube',
    
    [switch]$build,
    [switch]$delete
)

Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Kubernetes Deployment Script - CHM   ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Cyan

# Helper functions
function Show-Message {
    param([string]$message, [string]$status = 'INFO')
    $color = @{
        'INFO' = 'Cyan'
        'OK' = 'Green'
        'ERROR' = 'Red'
        'WARN' = 'Yellow'
    }
    Write-Host "[] " -ForegroundColor $color[$status] -NoNewline
    Write-Host $message
}

# Delete resources
if ($delete) {
    Show-Message "Deleting Kubernetes namespace and all resources..." 'WARN'
    kubectl delete namespace chm
    Show-Message "Namespace deleted" 'OK'
    exit 0
}

# Build Docker images
if ($build) {
    Show-Message "Building Docker images..." 'INFO'
    Push-Location ..
    docker-compose build
    Pop-Location
    Show-Message "Docker images built" 'OK'
}

# Platform-specific setup
switch ($platform) {
    'minikube' {
        Show-Message "Setting up Minikube environment..." 'INFO'
        $env:MINIKUBE_STATUS = (minikube status --format='{{.Host}}' 2>&1)
        
        if ($LASTEXITCODE -ne 0) {
            Show-Message "Starting Minikube..." 'INFO'
            minikube start --cpus=4 --memory=8192 --disk-size=40g
            Show-Message "Minikube started" 'OK'
        } else {
            Show-Message "Minikube already running" 'OK'
        }
        
        Show-Message "Configuring Docker to use Minikube..." 'INFO'
        minikube docker-env | Invoke-Expression
    }
    
    'docker-desktop' {
        Show-Message "Using Docker Desktop Kubernetes" 'INFO'
        Show-Message "Ensure Kubernetes is enabled in Docker Desktop Settings" 'WARN'
    }
    
    'cloud' {
        Show-Message "Using cloud Kubernetes (ensure kubectl is configured)" 'INFO'
    }
}

# Apply Kubernetes manifests
Show-Message "Applying Kubernetes manifests..." 'INFO'
kubectl apply -f .

# Wait for deployments
Show-Message "Waiting for deployments to be ready..." 'INFO'
kubectl wait --for=condition=available --timeout=300s deployment --all -n chm

# Show status
Show-Message "Deployment complete! Checking status..." 'OK'
kubectl get all -n chm

# Show access information
Write-Host ""
Write-Host "╔════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  Access Information                   ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════╝" -ForegroundColor Green

if ($platform -eq 'minikube') {
    Show-Message "Run these commands to access services:" 'INFO'
    Write-Host ""
    Write-Host "  Frontend:    minikube service frontend -n chm" -ForegroundColor Yellow
    Write-Host "  Prometheus:  minikube service prometheus -n chm" -ForegroundColor Yellow
    Write-Host "  Grafana:     minikube service grafana -n chm" -ForegroundColor Yellow
} else {
    Show-Message "Port forward services:" 'INFO'
    Write-Host ""
    Write-Host "  kubectl port-forward -n chm svc/frontend 3000:80" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward -n chm svc/prometheus 9090:9090" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward -n chm svc/grafana 3000:3000" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✓ Deployment ready!" -ForegroundColor Green
