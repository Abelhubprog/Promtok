#!/bin/bash

# Promtok startup script with automatic GPU detection

set -e

echo "[START] Starting Promtok..."

# Source GPU detection
source ./detect_gpu.sh

# Export GPU availability for docker-compose
if [ "$GPU_SUPPORT" = "nvidia" ]; then
    export GPU_AVAILABLE=true
    echo "[GPU] NVIDIA GPU detected - enabling GPU support"
    COMPOSE_FILES="-f docker-compose.yml -f docker-compose.gpu.yml"
else
    export GPU_AVAILABLE=false
    if [ "$GPU_SUPPORT" = "mac" ]; then
        echo "[INFO] macOS detected - running in CPU mode"
    else
        echo "[INFO] No GPU detected - running in CPU mode"
    fi
    COMPOSE_FILES="-f docker-compose.yml"
fi

# Check if .env file exists
if [ ! -f .env ]; then
    echo "[WARN] No .env file found. Creating from .env.example..."
    if [ -f .env.example ]; then
        cp .env.example .env
        echo "[OK] Created .env file. Please review and update the settings."
    else
        echo "[ERROR] No .env.example file found. Please create a .env file."
        exit 1
    fi
fi

# Source environment variables
export $(grep -v '^#' .env | xargs)

# Check if images exist, build if needed
echo "[CHECK] Checking Docker images..."
if ! docker images | grep -q "maestro-backend"; then
    echo "[BUILD] Building Docker images for first time setup..."
    docker compose $COMPOSE_FILES build
    echo "[BUILD] Building CLI image..."
    docker compose build cli
else
    # Check if CLI image exists
    if ! docker images | grep -q "maestro-cli"; then
        echo "[BUILD] Building CLI image..."
        docker compose build cli
    fi
fi

# Start services
echo "[DOCKER] Starting Docker services..."
docker compose $COMPOSE_FILES up -d

# Check if services are running
sleep 5
if docker compose ps | grep -q "Up"; then
    echo "[OK] Promtok is running!"
    echo ""
    echo "[ACCESS] Access PROMTOK at:"
    # Use the new nginx proxy port if available, fallback to old config for backward compatibility
    if [ -n "${PROMTOK_PORT}" ]; then
        if [ "${MAESTRO_PORT}" = "80" ]; then
            echo "         http://localhost"
        else
            echo "         http://localhost:${MAESTRO_PORT}"
        fi
    else
        # Backward compatibility
        echo "         Frontend: http://${FRONTEND_HOST:-localhost}:${FRONTEND_PORT:-3030}"
        echo "         Backend API: http://${BACKEND_HOST:-localhost}:${BACKEND_PORT:-8001}"
    fi
    echo ""
    echo "[STATUS] GPU Available: ${GPU_AVAILABLE}"
    echo ""
    echo "[NOTE] IMPORTANT - First Run:"
    echo "       Initial startup takes 5-10 minutes to download AI models"
    echo "       Monitor progress with: docker compose logs -f promtok-backend"
    echo "       Wait for message: Application startup complete"
else
    echo "[ERROR] Failed to start services. Check logs with: docker compose logs"
    exit 1
fi
