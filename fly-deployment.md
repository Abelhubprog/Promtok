# Deploying Promtok to Fly.io

## Overview

This guide provides a complete setup for deploying the Promtok application to Fly.io. The deployment uses a **two-app architecture** (recommended) with separate backend and frontend apps for better scalability, monitoring, and troubleshooting.

## Why Your Previous Deployment Failed

Your deployment failed because:
1. **Port mismatch**: App was listening on port 8000, but Fly checks port 8080 by default
2. **Missing environment variables**: DATABASE_URL and other secrets weren't set
3. **No Fly configuration**: Missing `fly.toml` and proper Dockerfile

## Architecture

```
Internet → Fly Load Balancer
           ↓
Frontend App (promtok-frontend.fly.dev)
           ↓
Backend App (promtok-backend.fly.dev)
           ↓
Fly Postgres Database
```

## Prerequisites

- Fly.io account and CLI installed
- GitHub repository access
- Basic knowledge of Docker and Fly.io

## Quick Start (Two-App Setup)

### 1. Install Fly CLI
```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Login to Fly
fly auth login
```

### 2. Backend Deployment

**Create the backend app:**
```bash
cd promtok_backend
fly apps create promtok-backend
```

**Create and attach PostgreSQL database:**
```bash
# Create Fly Postgres (choose your region)
fly postgres create --name promtok-pg --region ams --vm-size shared-cpu-1x --volume-size 10

# Attach to backend app
fly postgres attach promtok-pg --app promtok-backend
```

**Set required secrets:**
```bash
fly secrets set --app promtok-backend \
  JWT_SECRET=your-super-secret-jwt-key-change-this \
  OPENAI_API_KEY=your-openai-api-key \
  OPENROUTER_API_KEY=your-openrouter-api-key \
  STABLELINK_API_KEY=your-stablelink-api-key \
  STABLELINK_MERCHANT_ID=your-merchant-id \
  STABLELINK_WEBHOOK_SECRET=your-webhook-secret
```

**Deploy backend:**
```bash
fly deploy --remote-only --app promtok-backend
```

### 3. Frontend Deployment

**Create the frontend app:**
```bash
cd ../promtok_frontend
fly apps create promtok-frontend
```

**Deploy frontend with API URL:**
```bash
fly deploy --remote-only --build-arg VITE_API_HTTP_URL=https://promtok-backend.fly.dev
```

### 4. Update Backend CORS

**Update backend to allow frontend origin:**
```bash
fly secrets set FRONTEND_URL=https://promtok-frontend.fly.dev CORS_ALLOWED_ORIGINS=https://promtok-frontend.fly.dev -a promtok-backend
fly deploy --remote-only -a promtok-backend
```

## Configuration Files Created

### Backend Files

**`promtok_backend/Dockerfile.fly`:**
```dockerfile
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=on

WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends build-essential && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /app/requirements.txt
RUN pip install -r /app/requirements.txt

COPY . /app

# Fly health checks default to port 8080; run uvicorn there
ENV PORT=8080
EXPOSE 8080

CMD ["python","-m","uvicorn","main:app","--host","0.0.0.0","--port","8080","--log-level","info"]
```

**`promtok_backend/fly.toml`:**
```toml
app = "promtok-backend"
primary_region = "ams"

[build]
  dockerfile = "Dockerfile.fly"

[env]
  FRONTEND_URL = "https://promtok-frontend.fly.dev"
  CORS_ALLOWED_ORIGINS = "https://promtok-frontend.fly.dev"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "suspend"
  auto_start_machines = true
  min_machines_running = 0
  processes = ["app"]
  [http_service.concurrency]
    type = "connections"
    soft_limit = 80
    hard_limit = 100
  [[http_service.checks]]
    grace_period = "8s"
    interval = "15s"
    method = "get"
    path = "/health"
    timeout = "2s"
```

### Frontend Files

**`promtok_frontend/Dockerfile.fly`:**
```dockerfile
# Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . ./
ARG VITE_API_HTTP_URL
ENV VITE_API_HTTP_URL=${VITE_API_HTTP_URL}
RUN npm run build

# Serve
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
RUN printf "server { \
  listen 8080; \
  server_name _; \
  root /usr/share/nginx/html; \
  location / { try_files \$uri /index.html; } \
}\n" > /etc/nginx/conf.d/default.conf
ENV PORT=8080
EXPOSE 8080
CMD ["nginx","-g","daemon off;"]
```

**`promtok_frontend/fly.toml`:**
```toml
app = "promtok-frontend"
primary_region = "ams"

[build]
  dockerfile = "Dockerfile.fly"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = "suspend"
  auto_start_machines = true
  min_machines_running = 0
  processes = ["app"]
  [http_service.concurrency]
    type = "connections"
    soft_limit = 200
    hard_limit = 250
  [[http_service.checks]]
    grace_period = "5s"
    interval = "15s"
    method = "get"
    path = "/"
    timeout = "2s"
```

## GitHub Actions CI/CD

### Backend Workflow (`.github/workflows/fly-backend.yml`)
```yaml
name: Fly Deploy - Backend
on:
  push:
    paths:
      - "promtok_backend/**"
      - ".github/workflows/fly-backend.yml"
    branches: [ main ]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - run: flyctl deploy -c promtok_backend/fly.toml --remote-only --app promtok-backend
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### Frontend Workflow (`.github/workflows/fly-frontend.yml`)
```yaml
name: Fly Deploy - Frontend
on:
  push:
    paths:
      - "promtok_frontend/**"
      - ".github/workflows/fly-frontend.yml"
    branches: [ main ]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: superfly/flyctl-actions/setup-flyctl@master
      - run: flyctl deploy -c promtok_frontend/fly.toml --remote-only --app promtok-frontend --build-arg VITE_API_HTTP_URL=https://promtok-backend.fly.dev
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

### Setup GitHub Secrets
1. Go to your GitHub repository
2. Navigate to Settings → Secrets and variables → Actions
3. Add `FLY_API_TOKEN`:
   ```bash
   fly auth token
   ```
4. Copy the token and add it as a repository secret

## Database Management

### Database Migrations
If your app requires database migrations:
```bash
# SSH into the backend app
fly ssh console -a promtok-backend

# Run migrations (adjust command based on your migration tool)
alembic upgrade head
# or
python manage.py migrate
```

### Database Backup
```bash
# Create backup
fly postgres create --name promtok-pg-backup --region ams

# List databases
fly postgres list

# Connect to database
fly postgres connect -a promtok-pg
```

## Monitoring and Troubleshooting

### View Logs
```bash
# Backend logs
fly logs -a promtok-backend

# Frontend logs
fly logs -a promtok-frontend

# Database logs
fly postgres logs -a promtok-pg
```

### Check App Status
```bash
# List all apps
fly apps list

# Check app status
fly status -a promtok-backend
fly status -a promtok-frontend
```

### Debug Deployment Issues
```bash
# Check deployment status
fly releases -a promtok-backend

# View deployment logs
fly releases show <release-id> -a promtok-backend

# SSH into app for debugging
fly ssh console -a promtok-backend
```

### Common Issues

#### Port Issues
- **Problem**: "Connection refused" on health checks
- **Solution**: Ensure your app listens on port 8080 (Fly's default)
- **Check**: `fly logs -a your-app` and look for port binding

#### Environment Variables
- **Problem**: App crashes due to missing DATABASE_URL
- **Solution**: Set all required secrets before deployment
- **Check**: `fly secrets list -a your-app`

#### Database Connection
- **Problem**: "Can't connect to database"
- **Solution**: Ensure Postgres is attached and DATABASE_URL is set
- **Check**: `fly postgres attach --help`

#### CORS Issues
- **Problem**: Frontend can't communicate with backend
- **Solution**: Update CORS_ALLOWED_ORIGINS in backend secrets
- **Check**: Browser console for CORS errors

## Scaling and Performance

### Scale Apps
```bash
# Scale backend
fly scale count 2 -a promtok-backend

# Scale frontend
fly scale count 3 -a promtok-frontend

# Check scaling status
fly status -a promtok-backend
```

### Database Scaling
```bash
# Scale database
fly postgres update --vm-size shared-cpu-2x -a promtok-pg

# Check database status
fly postgres status -a promtok-pg
```

## Cost Estimation

### Free Tier
- **Backend**: ~$0 (shared CPU, auto-suspend)
- **Frontend**: ~$0 (shared CPU, auto-suspend)
- **Database**: ~$0 (shared CPU, 1GB storage)

### Paid Tier (Production)
- **Backend**: $15-30/month (dedicated CPU)
- **Frontend**: $5-15/month (dedicated CPU)
- **Database**: $20-50/month (dedicated CPU, more storage)

## URLs and Endpoints

After deployment, your app will be available at:
- **Frontend**: `https://promtok-frontend.fly.dev`
- **Backend API**: `https://promtok-backend.fly.dev`
- **Health Check**: `https://promtok-backend.fly.dev/health`

## Stablelink Integration

### Webhook Configuration
- **Webhook URL**: `https://promtok-backend.fly.dev/api/payments/stablelink/webhook`
- **Success URL**: `https://promtok-frontend.fly.dev/billing/success`
- **Cancel URL**: `https://promtok-frontend.fly.dev/billing`

### Required Secrets
```bash
fly secrets set STABLELINK_API_KEY=your-key STABLELINK_MERCHANT_ID=your-id STABLELINK_WEBHOOK_SECRET=your-secret -a promtok-backend
```

## Alternative: Single App Setup

If you prefer one app instead of two:

```bash
# Create single app
fly apps create promtok

# Attach database
fly postgres create --name promtok-pg --region ams
fly postgres attach promtok-pg --app promtok

# Set secrets
fly secrets set JWT_SECRET=... DATABASE_URL=... -a promtok

# Deploy
fly deploy --remote-only -a promtok
```

## Next Steps

1. **Test the deployment** by visiting your frontend URL
2. **Monitor logs** for any issues
3. **Set up monitoring** with Fly's built-in tools
4. **Configure custom domains** if needed
5. **Set up backups** for your database

## Support

- **Fly.io Documentation**: https://fly.io/docs
- **Community Forum**: https://community.fly.io
- **Status Page**: https://status.fly.io

This setup provides a production-ready deployment with proper separation of concerns, monitoring, and scalability options.
