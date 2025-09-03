# Docker Troubleshooting Lessons Learned

## Overview
This document captures key lessons from debugging a complex Docker Compose stack with FastAPI backend, nginx proxy, and PostgreSQL database. The main issue was a "Waiting for application startup" state that persisted despite the backend appearing to run.

## 1. Useful Docker Commands

### Essential Troubleshooting Commands

```bash
# Check service status
docker compose ps

# View logs for all services
docker compose logs

# View logs for specific service
docker compose logs -f backend

# Check running processes inside container
docker compose exec backend sh -lc 'tr "\0" " " </proc/1/cmdline'

# Test TCP connectivity inside container
docker compose exec backend python -c "import socket; s=socket.socket(); s.settimeout(3); s.connect(('127.0.0.1',8000)); print('TCP OK'); s.close()"

# Test HTTP from inside container
docker compose exec backend python -c "import urllib.request; print(urllib.request.urlopen('http://127.0.0.1:8000/health').read())"

# Test from host machine
curl -v http://localhost:8000/health
curl -v http://localhost:8080/health

# Stop and remove all containers
docker compose down

# Rebuild and restart
docker compose up -d --build

# Validate compose configuration
docker compose config

# Clean up unused resources
docker system prune -a
```

### Windows PowerShell Equivalents

```powershell
# Check service status
docker compose ps

# View logs (use Select-String for filtering)
docker compose logs -f backend | Select-String -Pattern 'ERROR|Traceback'

# Execute commands in container
docker compose exec backend sh -lc 'command here'

# Test connectivity with PowerShell-friendly syntax
docker compose exec backend python -c "import socket; s=socket.socket(); s.settimeout(3); s.connect(('127.0.0.1',8000)); print('TCP OK'); s.close()"

# HTTP test from host
curl.exe -v http://localhost:8000/health
```

## 2. Windows CPU-Only Setup Cheatsheet

### Prerequisites
- Windows 10/11 Pro or Enterprise
- WSL2 installed and configured
- Docker Desktop for Windows
- At least 8GB RAM, 4 CPU cores recommended

### Quick Setup Commands

```powershell
# 1. Clone repository
git clone <repository-url>
cd promtok

# 2. Set up environment (CPU mode)
cp .env.example .env
# Edit .env file with your settings

# 3. Start services (CPU mode)
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml up -d --build

# 4. Check status
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml ps

# 5. View logs
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml logs -f

# 6. Access application
start http://localhost:8080
```

### Environment Variables for CPU Mode

```powershell
# .env file configuration
POSTGRES_USER=promtok_user
POSTGRES_PASSWORD=promtok_password
POSTGRES_DB=promtok_db
POSTGRES_HOST=postgres

ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123

JWT_SECRET_KEY=your-secret-key-change-this

# CPU-specific settings
FORCE_CPU_MODE=true
PREFERRED_DEVICE_TYPE=cpu
MAX_WORKER_THREADS=4

# CORS settings
CORS_ALLOWED_ORIGINS=*
ALLOW_CORS_WILDCARD=true
```

### Troubleshooting CPU Setup

```powershell
# Check if services are healthy
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml ps

# Test backend health
curl http://localhost:8000/health

# Test nginx proxy
curl http://localhost:8080/health

# View backend logs
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml logs -f backend

# Check resource usage
docker stats

# Reset if needed
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml down
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml up -d --build
```

### Common Windows Issues & Solutions

```powershell
# Issue: Port already in use
netstat -ano | findstr :8080
# Kill process using port
taskkill /PID <PID> /F

# Issue: Docker daemon not running
# Start Docker Desktop application

# Issue: WSL2 integration issues
wsl --list --verbose
wsl --shutdown
wsl --start

# Issue: Memory/CPU limits
# Docker Desktop -> Settings -> Resources
# Increase RAM to 8GB+, CPUs to 4+
```

### Performance Optimization for Windows

```powershell
# Use WSL2 backend (faster than Hyper-V)
# Docker Desktop -> Settings -> General -> Use WSL2

# Enable file system caching
# Docker Desktop -> Settings -> Experimental -> Enable file system cache

# Allocate more resources
# Docker Desktop -> Settings -> Resources:
# - CPUs: 4-6
# - RAM: 8-16GB
# - Swap: 2-4GB
```

### Backup & Recovery

```powershell
# Backup database
docker compose -f docker-compose.cpu.yml exec postgres pg_dump -U promtok_user promtok_db > backup.sql

# Backup volumes
docker run --rm -v promtok_promtok-data:/data -v ${PWD}:/backup alpine tar czf /backup/data-backup.tar.gz -C /data .

# Restore database
docker compose -f docker-compose.cpu.yml exec -T postgres psql -U promtok_user promtok_db < backup.sql
```

## 3. Healthcheck Configuration

### Problem
HTTP healthchecks can fail even when the application is running if:
- The health endpoint itself has bugs
- Network connectivity issues during startup
- Lifespan events block the health endpoint

### Solution
Use TCP healthchecks for more reliable startup detection:

```yaml
healthcheck:
  test: ["CMD-SHELL", "python -c \"import socket,sys; s=socket.socket(); s.settimeout(2); "
                           "s.connect(('127.0.0.1',8000)); s.close(); sys.exit(0)\""]
  interval: 10s
  timeout: 5s
  retries: 30
  start_period: 30s
```

**Lesson**: TCP healthchecks are more reliable than HTTP healthchecks during application startup because they only verify network connectivity, not application logic.

## 4. Uvicorn/FastAPI Startup Issues

### Problem
The backend was stuck in "Waiting for application startup" with "Empty reply from server" errors.

### Root Causes Identified
1. **Reload loops**: Uvicorn's auto-reload was causing worker processes to restart continuously
2. **Lifespan events**: FastAPI lifespan events were hanging during startup
3. **Bind mounts**: File system watching on bind mounts triggered unnecessary reloads

### Solutions Applied
1. **Disable reload in production/dev**:
```yaml
entrypoint: ["python","-m","uvicorn","main:app",
             "--host","0.0.0.0","--port","8000",
             "--log-level","debug",
             "--lifespan","off"]
```

2. **Remove problematic bind mounts**:
```yaml
volumes: []  # Clear inherited bind mounts
```

3. **Add init process**:
```yaml
init: true  # Reaps zombie processes
```

**Lesson**: In containerized environments, disable development features like auto-reload that can cause instability. Use `--lifespan off` to bypass startup hooks that might hang.

## 5. Nginx Proxy Configuration

### Problem
Nginx was returning 502 errors when the backend wasn't ready.

### Solution
Configure nginx to depend on services but not require them to be healthy:

```yaml
services:
  nginx:
    depends_on:
      - backend  # Don't use 'service_healthy'
    ports:
      - "8080:80"
```

**Lesson**: Use `depends_on` for startup ordering, but don't gate on `service_healthy` unless absolutely necessary. This allows nginx to start and serve error pages while the backend is still initializing.

## 6. PYTHONPATH and Import Issues

### Problem
`ModuleNotFoundError: No module named 'ai_researcher'` in doc-processor service.

### Solution
Ensure PYTHONPATH is set in all Python services:

```yaml
environment:
  PYTHONPATH: /app
```

**Lesson**: PYTHONPATH must be explicitly set in Docker containers since the default Python path discovery doesn't work the same as in development environments.

## 7. YAML Syntax Pitfalls

### Problem
Nested quotes in healthcheck commands caused YAML parsing errors.

### Solution
Use proper YAML quoting strategies:
- Single quotes for simple strings
- Double quotes with escaped inner quotes
- Multi-line strings with `|` for complex commands

**Lesson**: Test YAML syntax with `docker compose config` before deploying. Complex CMD-SHELL commands often need careful quote escaping.

## 8. Service Dependencies

### Problem
Circular dependencies and incorrect service naming in depends_on.

### Solution
- Use service names (not container names) in depends_on
- Avoid circular dependencies
- Use depends_on for ordering, healthchecks for readiness

**Lesson**: Docker Compose depends_on uses service names from the compose file, not container names. Always verify service names match exactly.

## 9. Environment Variables

### Problem
Missing or incorrect environment variables causing startup failures.

### Solution
Centralize environment configuration:

```yaml
environment:
  PYTHONUNBUFFERED: "1"      # Ensure stdout/stderr are not buffered
  PYTHONPATH: /app          # Fix import paths
  FORCE_CPU_MODE: "true"    # Force CPU-only mode
  OPENROUTER_API_KEY: dev-placeholder  # Prevent provider init errors
```

**Lesson**: Use `PYTHONUNBUFFERED: "1"` to ensure log output appears immediately in Docker logs, making debugging much easier.

## 10. Volume Configuration

### Problem
Bind mounts were triggering unnecessary reloads and causing instability.

### Solution
- Use named volumes for data persistence
- Avoid bind mounts in production-like environments
- Clear inherited volumes when needed: `volumes: []`

**Lesson**: Bind mounts are great for development but can cause issues in containerized environments. Use named volumes for data that needs to persist.

## 11. Best Practices Established

### Docker Compose Best Practices
1. **Use TCP healthchecks** for network services
2. **Disable development features** in containers (reload, debug)
3. **Set PYTHONUNBUFFERED** for immediate log output
4. **Use init: true** to prevent zombie processes
5. **Test configurations** with `docker compose config`
6. **Use depends_on** for ordering, not gating

### Debugging Workflow
1. Check `docker compose ps` for service status
2. Review logs with `docker compose logs`
3. Test connectivity at TCP level first
4. Test HTTP endpoints from inside container
5. Test from host machine
6. Check running processes with `/proc/1/cmdline`

### Configuration Management
1. **Override files** for environment-specific settings
2. **Named volumes** for data persistence
3. **Environment variables** for configuration
4. **Consistent PYTHONPATH** across all Python services

## 12. Common Anti-Patterns Avoided

1. **Don't use HTTP healthchecks during startup** - they can fail due to application logic issues
2. **Don't rely on auto-reload in containers** - it causes instability
3. **Don't use bind mounts for production data** - use named volumes
4. **Don't forget PYTHONPATH** - import errors are hard to debug
5. **Don't use container names in depends_on** - use service names
6. **Don't buffer logs** - use PYTHONUNBUFFERED

## 13. Monitoring and Observability

### Key Metrics to Monitor
- Container health status
- Service startup time
- Healthcheck response times
- Error rates in logs
- Resource usage (CPU, memory)

### Log Analysis
- Look for "reloader" messages indicating reload loops
- Check for "lifespan" errors
- Monitor for "ModuleNotFoundError"
- Watch for connection timeouts

## Conclusion

This troubleshooting experience demonstrated that Docker issues often stem from configuration rather than code problems. The key is systematic debugging:

1. **Start with the basics**: Check service status and logs
2. **Isolate the problem**: Test at different layers (TCP, HTTP, inside/outside container)
3. **Fix configuration**: Address environment variables, paths, and startup settings
4. **Use appropriate healthchecks**: TCP for network services, HTTP only when application is stable
5. **Document solutions**: Create runbooks for common issues

The most important lesson: **When in doubt, simplify**. Remove development features, disable complex startup hooks, and use the simplest possible configuration that works.
