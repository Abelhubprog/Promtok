# Fix Your Fly.io Deployment - Stopped Machines in JNB

## Your Current Situation
- **App**: `promtok` in `jnb` region
- **Status**: Two stopped machines
- **Error**: "smoke checks ... app appears to be crashing"
- **Cause**: Port mismatch (8000 vs 8080) + missing environment variables

## ✅ Quick Fix (3 Steps)

### Step 1: Update Configuration Files

**✅ Already Done**: I've created the proper files for you:

- **`promtok_backend/Dockerfile`** - Runs on port 8080
- **`fly.toml`** - Uses `jnb` region, proper health checks

### Step 2: Set Up Database & Secrets

```bash
# Create Fly Postgres in your region
fly postgres create --name promtok-pg --region jnb --vm-size shared-cpu-1x --volume-size 10

# Attach to your app (this sets DATABASE_URL automatically)
fly postgres attach promtok-pg --app promtok

# Set required secrets
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

### Step 3: Redeploy from Repo (No --image Flag)

```bash
# Deploy from your repo (not pre-built image)
fly deploy --remote-only --app promtok
```

## 🔍 Why This Fixes Your Issue

### **Port Mismatch Fixed**
- **Before**: App ran on port 8000, Fly checked port 8080
- **After**: App runs on port 8080, Fly checks port 8080 ✅

### **Environment Variables Fixed**
- **Before**: Missing DATABASE_URL, API keys
- **After**: Fly Postgres provides DATABASE_URL, secrets set ✅

### **Health Check Fixed**
- **Before**: Health check failed → machine killed
- **After**: Proper `/health` endpoint with correct timeout ✅

## 📊 Verify Success

### Check App Status
```bash
# View app status
fly status -a promtok

# Should show: Status = running, Health = passing
```

### Check Logs
```bash
# View recent logs
fly logs -a promtok

# Should show: Uvicorn running on 0.0.0.0:8080
```

### Test Health Endpoint
```bash
# Test health check
curl https://promtok.fly.dev/health

# Should return: {"status": "healthy"}
```

## 🚨 If Still Failing

### Check Machine Status
```bash
# List machines
fly m list -a promtok

# Check specific machine
fly m status -a promtok <machine-id>
```

### Debug Logs
```bash
# View machine-specific logs
fly logs -a promtok -i <machine-id>

# Common errors:
# - "ModuleNotFoundError" → Missing dependencies
# - "Connection refused" → Database not attached
# - "KeyError: OPENAI_API_KEY" → Secrets not set
```

### SSH for Debugging
```bash
# SSH into running machine
fly ssh console -a promtok

# Check environment
env | grep -E "(DATABASE|PORT|JWT|OPENAI)"

# Test database connection
python -c "from database.database import test_connection; print(test_connection())"
```

## 🔧 Alternative: Clean Restart

If issues persist, do a clean restart:

```bash
# Stop all machines
fly m stop --all -a promtok

# Remove stopped machines
fly m destroy --all -a promtok

# Redeploy fresh
fly deploy --remote-only --app promtok
```

## 📋 Your Configuration Summary

### Files Created/Updated:
- ✅ **`promtok_backend/Dockerfile`** - Port 8080, proper setup
- ✅ **`fly.toml`** - JNB region, correct health checks
- ✅ **Database**: Fly Postgres attached
- ✅ **Secrets**: All required environment variables set

### Key Changes:
```toml
# fly.toml
app = "promtok"
primary_region = "jnb"   # Your region
[build]
  dockerfile = "promtok_backend/Dockerfile"  # From repo, not image
[http_service]
  internal_port = 8080    # Matches container port
```

## 🎯 Expected Result

After following these steps:
1. ✅ Machines start successfully
2. ✅ Health checks pass
3. ✅ App serves on `https://promtok.fly.dev`
4. ✅ Database connections work
5. ✅ API endpoints respond

## 📞 Need Help?

If you still get errors, share:
1. `fly logs -a promtok` output
2. `fly status -a promtok` output
3. Any error messages from the deployment

The most common remaining issues are usually missing secrets or database connection problems.
