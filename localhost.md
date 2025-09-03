# How to Run Promtok on Localhost

## Prerequisites
- Windows 10/11 Pro or Enterprise
- WSL2 installed and configured
- Docker Desktop for Windows installed and running
- At least 8GB RAM recommended

## Step 1: Clone the Repository
```bash
git clone <repository-url>
cd promtok
```

## Step 2: Set Up Environment Variables
```bash
cp .env.example .env
```

Edit the `.env` file with your configuration:
```bash
POSTGRES_USER=promtok_user
POSTGRES_PASSWORD=promtok_password
POSTGRES_DB=promtok_db
POSTGRES_HOST=postgres

ADMIN_USERNAME=admin
ADMIN_PASSWORD=admin123

JWT_SECRET_KEY=your-secret-key-change-this

FORCE_CPU_MODE=true
PREFERRED_DEVICE_TYPE=cpu
MAX_WORKER_THREADS=4

CORS_ALLOWED_ORIGINS=*
ALLOW_CORS_WILDCARD=true
```

## Step 3: Start the Application (CPU Mode)
```bash
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml up -d --build
```

## Step 4: Check Service Status
```bash
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml ps
```

Expected output should show all services as "Up":
```
NAME                    STATUS
promtok-backend         Up (healthy)
promtok-frontend        Up
promtok-nginx           Up
promtok-postgres        Up (healthy)
promtok-doc-processor   Up
promtok-cli             Up
```

## Step 5: Verify Health Check
```bash
curl http://localhost:8080/health
```

Expected response:
```json
{"status":"healthy"}
```

## Step 6: Access the Application
Open your web browser and navigate to:
```
http://localhost:8080
```

## Step 7: View Application Logs (Optional)
```bash
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml logs -f
```

## Step 8: Stop the Application
```bash
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml down
```

## Troubleshooting Commands

### Check Individual Service Logs
```bash
# Backend logs
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml logs -f backend

# Nginx logs
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml logs -f nginx

# Database logs
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml logs -f postgres
```

### Restart Services
```bash
# Restart all services
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml restart

# Restart specific service
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml restart nginx
```

### Clean Restart
```bash
# Stop and remove all containers
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml down

# Remove volumes (WARNING: This deletes database data)
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml down -v

# Start fresh
docker compose -f docker-compose.cpu.yml -f docker-compose.cpu.override.yml up -d --build
```

## Service URLs

- **Main Application**: http://localhost:8080
- **Backend API**: http://localhost:8000
- **Frontend Dev Server**: http://localhost:3000
- **Database**: localhost:5432

## Default Credentials

- **Username**: admin
- **Password**: admin123

## Performance Notes

- The application uses CPU-only mode by default
- For GPU support, use `docker-compose.gpu.yml` instead
- Minimum 8GB RAM recommended
- First startup may take several minutes due to model downloads

## Common Issues

### Port Already in Use
```bash
# Find process using port 8080
netstat -ano | findstr :8080

# Kill the process
taskkill /PID <PID> /F
```

### Docker Not Running
- Start Docker Desktop application
- Ensure WSL2 backend is enabled

### Memory Issues
- Increase Docker Desktop memory allocation to 8GB+
- Close other memory-intensive applications
