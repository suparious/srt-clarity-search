# SRT Clarity Search - Kubernetes Deployment Guide

AI-powered search engine (Perplexity.ai clone) deployed on SRT-HQ Kubernetes platform with vLLM integration.

---

## Quick Start

### Development

```bash
npm install
npm run dev
# Access: http://localhost:3000
```

### Docker

```bash
# Build and test locally
.\build-and-push.ps1
docker run --rm -p 3000:3000 suparious/srt-clarity-search:latest
# Access: http://localhost:3000
```

### Kubernetes

```powershell
# Build, push, and deploy
.\deploy.ps1 -Build -Push

# Deploy only (uses existing image)
.\deploy.ps1

# Uninstall
.\deploy.ps1 -Uninstall
```

**Production URL**: https://clarity.lab.hq.solidrust.net

---

## Maintenance

### Update Application

```powershell
# After making code changes
.\deploy.ps1 -Build -Push
```

### View Logs

```bash
kubectl logs -n srt-clarity-search -l app=srt-clarity-search -f
```

### Restart Deployment

```bash
kubectl rollout restart deployment/srt-clarity-search -n srt-clarity-search
```

### Update vLLM Configuration

```bash
# Edit ConfigMap
kubectl edit configmap srt-clarity-search-config -n srt-clarity-search

# Restart to apply changes
kubectl rollout restart deployment/srt-clarity-search -n srt-clarity-search
```

### Troubleshooting

```bash
# Check all resources
kubectl get all,certificate,ingress,configmap -n srt-clarity-search

# Describe pod for events
kubectl describe pod -n srt-clarity-search <pod-name>

# Test vLLM connectivity
kubectl exec -it -n srt-clarity-search <pod-name> -- \
  wget -O- http://vllm.inference.svc.cluster.local:8000/v1/models
```

---

## Architecture

### Tech Stack

- **Frontend**: React 18 + TypeScript + TailwindCSS
- **Backend**: Next.js 14 API routes (Edge runtime)
- **AI Integration**: vLLM inference service (OpenAI-compatible)
- **Web Scraping**: Cheerio + JSDOM + Mozilla Readability
- **Runtime**: Node.js 24 Alpine
- **Port**: 3000

### Resource Allocation

**Per Pod**:
- Requests: 200m CPU, 256Mi memory
- Limits: 1000m CPU, 512Mi memory

**Deployment**:
- Replicas: 2 (HA)
- Strategy: RollingUpdate

### Networking

**Ingress**:
- Host: `clarity.lab.hq.solidrust.net`
- TLS: Let's Encrypt DNS-01 (automatic)
- Timeout: 300s (for streaming)

**vLLM Integration**:
- Internal: `http://vllm.inference.svc.cluster.local:8000`
- Public: `https://vllm.lab.hq.solidrust.net`
- API: `/v1/chat/completions` (OpenAI-compatible)

---

## Features

- **AI-Powered Search**: Ask questions, get AI-generated answers with sources
- **Web Scraping**: Automatically fetches and parses relevant webpages
- **Streaming Responses**: Real-time AI answer generation
- **Source Citations**: Links to original sources used for answers
- **Clean UI**: Modern, responsive design with Tabler icons
- **Self-Hosted AI**: Uses platform vLLM service ($0 per token)

**How it works**:
1. User enters search query
2. App scrapes Google for relevant webpages
3. Parses webpage content
4. Sends context + query to vLLM
5. Streams AI-generated answer back to user

---

## Files Overview

### Kubernetes Manifests (`k8s/`)

- `01-namespace.yaml` - Namespace definition
- `02-configmap.yaml` - vLLM endpoint configuration
- `03-deployment.yaml` - Application deployment (2 replicas)
- `04-service.yaml` - ClusterIP service (port 80)
- `05-ingress.yaml` - HTTPS ingress with SSL

### Deployment Scripts

- `build-and-push.ps1` - Docker image build and push
- `deploy.ps1` - Kubernetes deployment automation

### Application Files

- `Dockerfile` - Multi-stage build (deps → builder → runner)
- `.dockerignore` - Files excluded from image
- `next.config.js` - Next.js configuration
- `package.json` - Dependencies and scripts

### Documentation

- `CLAUDE.md` - Complete agent context
- `README-K8S.md` - This file (deployment guide)
- `README.md` - Original project documentation

---

## Useful Commands

### Status

```bash
# All resources
kubectl get all -n srt-clarity-search

# Pods
kubectl get pods -n srt-clarity-search -o wide

# Certificate
kubectl get certificate -n srt-clarity-search

# Ingress
kubectl get ingress -n srt-clarity-search

# ConfigMap
kubectl get configmap -n srt-clarity-search -o yaml
```

### Logs

```bash
# Follow logs (all pods)
kubectl logs -n srt-clarity-search -l app=srt-clarity-search -f

# Specific pod
kubectl logs -n srt-clarity-search <pod-name> -f

# Previous pod (if crashed)
kubectl logs -n srt-clarity-search <pod-name> -p
```

### Debugging

```bash
# Shell into pod
kubectl exec -it -n srt-clarity-search <pod-name> -- sh

# Test vLLM from pod
kubectl exec -it -n srt-clarity-search <pod-name> -- \
  wget -qO- http://vllm.inference.svc.cluster.local:8000/v1/models

# Port-forward for local access
kubectl port-forward -n srt-clarity-search svc/srt-clarity-search 3000:80
# Access: http://localhost:3000
```

---

## Links

- **Production**: https://clarity.lab.hq.solidrust.net
- **Docker Hub**: https://hub.docker.com/r/suparious/srt-clarity-search
- **GitHub**: https://github.com/suparious/srt-clarity-search
- **vLLM Service**: https://vllm.lab.hq.solidrust.net

---

**Last Updated**: 2025-11-13
**Platform**: SRT-HQ Kubernetes
**Namespace**: srt-clarity-search
