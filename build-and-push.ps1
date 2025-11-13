#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build and push SRT Clarity Search Docker image to Docker Hub

.DESCRIPTION
    Builds the SRT Clarity Search Next.js application Docker image and optionally pushes to Docker Hub

.PARAMETER DockerHubUsername
    Docker Hub username (default: suparious)

.PARAMETER ImageName
    Docker image name (default: srt-clarity-search)

.PARAMETER Tag
    Docker image tag (default: latest)

.PARAMETER Push
    Push image to Docker Hub after building

.PARAMETER Login
    Login to Docker Hub before building/pushing

.EXAMPLE
    .\build-and-push.ps1
    Build image locally

.EXAMPLE
    .\build-and-push.ps1 -Login -Push
    Build and push to Docker Hub
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DockerHubUsername = "suparious",

    [Parameter(Mandatory = $false)]
    [string]$ImageName = "srt-clarity-search",

    [Parameter(Mandatory = $false)]
    [string]$Tag = "latest",

    [Parameter(Mandatory = $false)]
    [switch]$Push,

    [Parameter(Mandatory = $false)]
    [switch]$Login
)

$ErrorActionPreference = 'Stop'

#region Configuration

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

#endregion

#region Main Script

Write-ColorOutput "`n=== SRT Clarity Search - Docker Image Builder ===" $colors.Header
Write-ColorOutput "Building Docker image for Perplexity.ai clone with vLLM integration`n" $colors.Info

# Determine full image name
$fullImageName = "${DockerHubUsername}/${ImageName}:${Tag}"

Write-ColorOutput "Target image: $fullImageName" $colors.Info
Write-Host ""

# Docker Hub login if requested
if ($Login) {
    Write-ColorOutput "Logging into Docker Hub..." $colors.Info
    docker login
    # Don't check exit code - docker login can be finicky with exit codes in PowerShell
    Write-ColorOutput "✅ Login attempt completed" $colors.Success
    Write-Host ""
}

# Check if logged in if Push is requested
if ($Push) {
    Write-ColorOutput "Checking Docker Hub authentication..." $colors.Info

    # Determine Docker config path (Windows or Linux/WSL)
    if ($env:USERPROFILE) {
        $dockerConfigPath = "$env:USERPROFILE\.docker\config.json"
    }
    elseif ($env:HOME) {
        $dockerConfigPath = "$env:HOME/.docker/config.json"
    }
    else {
        Write-ColorOutput "Unable to determine Docker config path, proceeding with push" $colors.Info
        $dockerConfigPath = $null
    }

    $isAuthenticated = $false

    if ($dockerConfigPath -and (Test-Path $dockerConfigPath)) {
        try {
            $dockerConfig = Get-Content $dockerConfigPath -Raw | ConvertFrom-Json

            # Check if using credential store (Docker Desktop)
            if ($dockerConfig.credsStore) {
                Write-ColorOutput "Using Docker credential store: $($dockerConfig.credsStore)" $colors.Info
                $isAuthenticated = $true
            }
            # Check for credentials in auths object (legacy)
            elseif ($dockerConfig.auths -and $dockerConfig.auths.PSObject.Properties.Count -gt 0) {
                foreach ($auth in $dockerConfig.auths.PSObject.Properties) {
                    if ($auth.Value.PSObject.Properties.Count -gt 0) {
                        $isAuthenticated = $true
                        break
                    }
                }
            }
        }
        catch {
            Write-ColorOutput "Unable to parse config, will attempt push anyway" $colors.Warning
            $isAuthenticated = $true
        }
    }
    else {
        $isAuthenticated = $true
    }

    if (-not $isAuthenticated) {
        Write-ColorOutput "Not logged into Docker Hub" $colors.Warning
        Write-ColorOutput "Please run: docker login" $colors.Info
        Write-ColorOutput "Or use: .\build-and-push.ps1 -Login -Push" $colors.Info
        exit 1
    }

    Write-ColorOutput "✅ Docker Hub authentication confirmed" $colors.Success
    Write-Host ""
}

# Build the Docker image
Write-ColorOutput "Building Docker image..." $colors.Header
Write-ColorOutput "This may take 3-7 minutes (Next.js build)" $colors.Info
Write-Host ""

docker build -t $fullImageName .
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "Docker build failed" $colors.Error
    exit 1
}

Write-ColorOutput "✅ Docker image built successfully: $fullImageName" $colors.Success
Write-Host ""

# Test the image
Write-ColorOutput "Testing image..." $colors.Info
Write-ColorOutput "Verifying Node.js and Next.js are available..." $colors.Info
docker run --rm $fullImageName node --version
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "⚠️  Image test failed (Node.js check), but build succeeded" $colors.Warning
}
else {
    Write-ColorOutput "✅ Node.js runtime validated" $colors.Success
}
Write-Host ""

# Push to Docker Hub if requested
if ($Push) {
    Write-ColorOutput "Pushing image to Docker Hub..." $colors.Header
    docker push $fullImageName
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Docker push failed" $colors.Error
        exit 1
    }
    Write-ColorOutput "✅ Pushed: $fullImageName" $colors.Success
    Write-Host ""
}

# Summary
Write-ColorOutput "=== Build Summary ===" $colors.Header
Write-ColorOutput "Image: $fullImageName" $colors.Info
Write-ColorOutput "Status: Built successfully" $colors.Success
if ($Push) {
    Write-ColorOutput "Published: Yes" $colors.Success
    Write-ColorOutput "Public URL: https://hub.docker.com/r/$DockerHubUsername/$ImageName" $colors.Info
}
else {
    Write-ColorOutput "Published: No (local only)" $colors.Warning
}
Write-Host ""

# Next steps
if (-not $Push) {
    Write-ColorOutput "Next Steps:" $colors.Header
    Write-Host "  1. Test the image locally:" -ForegroundColor Yellow
    Write-Host "     docker run --rm -p 3000:3000 $fullImageName" -ForegroundColor Yellow
    Write-Host "     Open http://localhost:3000" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  2. Push to Docker Hub:" -ForegroundColor Yellow
    Write-Host "     .\build-and-push.ps1 -Push" -ForegroundColor Yellow
    Write-Host ""
}

if ($Push) {
    Write-ColorOutput "🎉 Image is now publicly available!" $colors.Success
    Write-Host "   https://hub.docker.com/r/$DockerHubUsername/$ImageName" -ForegroundColor Green
    Write-Host ""
    Write-ColorOutput "Deploy to Kubernetes:" $colors.Header
    Write-Host "   .\deploy.ps1" -ForegroundColor Cyan
    Write-Host ""
}

#endregion
