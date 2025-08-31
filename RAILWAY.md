Deploying PROMTOK on Railway

This guide explains how to deploy PROMTOK’s backend and frontend to Railway using the provided Railway-specific Dockerfiles.

Services
- Backend: Python/FastAPI (CPU-only) using `promtok_backend/Dockerfile.railway`
- Frontend: Vite build served by `serve` using `promtok_frontend/Dockerfile.railway`
- Database: Railway PostgreSQL (managed). Set `DATABASE_URL` in the backend environment.

Steps
1) Create a Railway project and add a PostgreSQL plugin.
2) Add a new service → Deploy from GitHub repo (or from folder) and set:
   - Service name: promtok-backend
   - Root directory: `promtok`
   - Dockerfile path: `promtok_backend/Dockerfile.railway`
3) Set backend environment variables:
   - `DATABASE_URL` (from Railway Postgres plugin)
   - `ADMIN_USERNAME` and `ADMIN_PASSWORD`
   - `JWT_SECRET_KEY` (use a strong random value)
   - `LOG_LEVEL=ERROR`
   - Optional CORS: `CORS_ALLOWED_ORIGINS` to your frontend domain, or `*` for testing
4) Add another service for the frontend:
   - Service name: promtok-frontend
   - Root directory: `promtok`
   - Dockerfile path: `promtok_frontend/Dockerfile.railway`
5) Frontend environment variables (build-time):
   - `VITE_API_HTTP_URL` set to your backend public URL (e.g., `https://<backend-domain>`)
   - `VITE_API_WS_URL` set to backend websocket base (e.g., `wss://<backend-domain>`) if using websockets directly
   - `VITE_SERVER_TIMEZONE` as needed (defaults to `America/Chicago` if unset)
6) Deploy both services. Railway assigns a public URL to each.

Notes
- Backend binds to `$PORT` automatically via `start.sh`.
- GPU is not available on Railway; backend runs in CPU mode.
- For local development, prefer `docker compose -f docker-compose.cpu.yml up -d`.
- To serve frontend and backend from one domain, configure a custom domain for the frontend and point API envs to the backend domain.

Health checks
- Backend: `GET /health` should return `{ "status": "healthy" }`
