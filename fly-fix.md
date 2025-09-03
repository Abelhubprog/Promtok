# Quick Fix for Your Fly.io Deployment

## The Problem
Your deployment is failing with "the app appears to be crashing" because:
1. Missing database connection
2. Missing required environment variables
3. App trying to connect to localhost database instead of Fly Postgres

## Immediate Fix (3 Steps)

### Step 1: Set Up Database
```bash
# Create Fly Postgres database
fly postgres create --name promtok-pg --region ams --vm-size shared-cpu-1x --volume-size 10

# Attach it to your app
fly postgres attach promtok-pg --app promtok
```

### Step 2: Set Required Secrets
```bash
# Set all required environment variables
fly secrets set --app promtok \
  JWT_SECRET=your-super-secret-jwt-key-change-this \
  OPENAI_API_KEY=your-openai-api-key \
  OPENROUTER_API_KEY=your-openrouter-api-key \
  STABLELINK_API_KEY=your-stablelink-api-key \
  STABLELINK_MERCHANT_ID=your-merchant-id \
  STABLELINK_WEBHOOK_SECRET=your-webhook-secret \
  FORCE_CPU_MODE=true \
  PREFERRED_DEVICE_TYPE=cpu
```

### Step 3: Redeploy
```bash
# Redeploy with the new configuration
fly deploy --app promtok
```

## Why This Fixes It

1. **Database Connection**: Fly Postgres automatically sets `DATABASE_URL`
2. **Environment Variables**: Your app needs these secrets to start properly
3. **CPU Mode**: Forces CPU-only operation (no GPU dependencies)

## Verify the Fix

After deployment, check:
```bash
# Check app status
fly status -a promtok

# View logs
fly logs -a promtok

# Test health endpoint
curl https://promtok.fly.dev/health
```

## If Still Failing

Check the logs for specific errors:
```bash
fly logs -a promtok
```

Common issues:
- **"Can't connect to database"**: Database not attached properly
- **"Missing OPENAI_API_KEY"**: Secrets not set
- **"CUDA not available"**: GPU mode enabled without GPU

## Alternative: Use the Two-App Setup

If the single-app setup continues to fail, use the two-app architecture I created:

```bash
# Deploy backend separately
cd promtok_backend
fly apps create promtok-backend
fly postgres create --name promtok-pg --region ams
fly postgres attach promtok-pg --app promtok-backend
fly secrets set JWT_SECRET=... OPENAI_API_KEY=... -a promtok-backend
fly deploy --app promtok-backend

# Deploy frontend separately
cd ../promtok_frontend
fly apps create promtok-frontend
fly deploy --app promtok-frontend --build-arg VITE_API_HTTP_URL=https://promtok-backend.fly.dev
```

This approach is more reliable and easier to debug.
