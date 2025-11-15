#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy SRT Clarity Search to Kubernetes

.DESCRIPTION
    Deploys the SRT Clarity Search (Perplexity.ai clone) to SRT-HQ Kubernetes cluster

.PARAMETER Build
    Build Docker image before deploying

.PARAMETER Push
    Push Docker image to Docker Hub (requires authentication)

.PARAMETER Uninstall
    Remove deployment from cluster

.EXAMPLE
    .\deploy.ps1
    Deploy using existing Docker Hub image

.EXAMPLE
    .\deploy.ps1 -Build -Push
    Build, push, and deploy

.EXAMPLE
    .\deploy.ps1 -Uninstall
    Remove from cluster
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Build,

    [Parameter(Mandatory = $false)]
    [switch]$Push,

    [Parameter(Mandatory = $false)]
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

#region Configuration

$APP_NAME = "srt-clarity-search"
$NAMESPACE = "srt-clarity-search"
$IMAGE = "suparious/srt-clarity-search:latest"
$K8S_DIR = "k8s"

# Color formatting
$colors = @{
    Header = 'Cyan'
    Success = 'Green'
    Warning = 'Yellow'
    Error = 'Red'
    Info = 'White'
}

#endregion

#region Functions

function Write-ColorOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-ColorOutput "===========================================" $colors.Header
    Write-ColorOutput " $Message" $colors.Header
    Write-ColorOutput "===========================================" $colors.Header
    Write-Host ""
}

#endregion

#region Main Script

# Handle uninstall
if ($Uninstall) {
    Write-Header "Uninstalling $APP_NAME from Kubernetes"

    Write-ColorOutput "Deleting Kubernetes resources..." $colors.Info
    kubectl delete -f "$K8S_DIR/05-ingress.yaml" --ignore-not-found
    kubectl delete -f "$K8S_DIR/04-service.yaml" --ignore-not-found
    kubectl delete -f "$K8S_DIR/03-deployment.yaml" --ignore-not-found
    kubectl delete -f "$K8S_DIR/02-configmap.yaml" --ignore-not-found
    kubectl delete -f "$K8S_DIR/01-namespace.yaml" --ignore-not-found

    Write-ColorOutput "✅ Uninstallation complete" $colors.Success
    exit 0
}

Write-Header "Deploying $APP_NAME to Kubernetes"

# Build and push if requested
if ($Build) {
    Write-ColorOutput "Building Docker image..." $colors.Info

    if ($Push) {
        & .\build-and-push.ps1 -Push
    }
    else {
        & .\build-and-push.ps1
    }

    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Build failed" $colors.Error
        exit 1
    }
    Write-Host ""
}

# Apply Kubernetes manifests
Write-ColorOutput "Applying Kubernetes manifests..." $colors.Header

Write-ColorOutput "  → Creating namespace..." $colors.Info
kubectl apply -f "$K8S_DIR/01-namespace.yaml"

Write-ColorOutput "  → Creating configmap..." $colors.Info
kubectl apply -f "$K8S_DIR/02-configmap.yaml"

Write-ColorOutput "  → Creating deployment..." $colors.Info
kubectl apply -f "$K8S_DIR/03-deployment.yaml"

Write-ColorOutput "  → Creating service..." $colors.Info
kubectl apply -f "$K8S_DIR/04-service.yaml"

Write-ColorOutput "  → Creating ingress..." $colors.Info
kubectl apply -f "$K8S_DIR/05-ingress.yaml"

Write-ColorOutput "✅ Manifests applied" $colors.Success

# Force rollout restart if we pushed new images (using :latest tag)
if ($Push) {
    Write-Host ""
    Write-ColorOutput "Forcing rollout restart to pull new image..." $colors.Info
    kubectl rollout restart deployment/$APP_NAME -n $NAMESPACE
    Write-ColorOutput "✅ Rollout restart triggered" $colors.Success
}

# Wait for rollout
Write-Host ""
Write-ColorOutput "Waiting for deployment rollout..." $colors.Info
kubectl rollout status deployment/$APP_NAME -n $NAMESPACE --timeout=180s

if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "Deployment rollout failed" $colors.Error
    Write-Host ""
    Write-ColorOutput "Check logs with:" $colors.Info
    Write-Host "  kubectl logs -n $NAMESPACE -l app=$APP_NAME --tail=50"
    exit 1
}

Write-ColorOutput "✅ Deployment successful" $colors.Success

# Show status
Write-Header "Deployment Status"

Write-ColorOutput "Pods:" $colors.Info
kubectl get pods -n $NAMESPACE

Write-Host ""
Write-ColorOutput "Service:" $colors.Info
kubectl get svc -n $NAMESPACE

Write-Host ""
Write-ColorOutput "Ingress:" $colors.Info
kubectl get ingress -n $NAMESPACE

Write-Host ""
Write-ColorOutput "Certificate:" $colors.Info
kubectl get certificate -n $NAMESPACE

# Summary
Write-Host ""
Write-ColorOutput "✅ Deployment complete!" $colors.Success
Write-Host ""
Write-ColorOutput "Access the application at: https://clarity.lab.hq.solidrust.net" 'Yellow'
Write-Host ""
Write-ColorOutput "Configuration:" $colors.Header
Write-Host "  vLLM Internal: http://vllm.inference.svc.cluster.local:8000/v1"
Write-Host "  vLLM Public:   https://vllm.lab.hq.solidrust.net/v1"
Write-Host ""
Write-ColorOutput "Useful commands:" $colors.Header
Write-Host "  kubectl get all -n $NAMESPACE"
Write-Host "  kubectl logs -n $NAMESPACE -l app=$APP_NAME -f"
Write-Host "  kubectl describe ingress -n $NAMESPACE"
Write-Host "  kubectl describe certificate -n $NAMESPACE"
Write-Host "  kubectl get configmap -n $NAMESPACE"
Write-Host ""

#endregion
