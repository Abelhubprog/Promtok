Deploying PROMTOK on Railway (Monorepo)

This repo is a monorepo with separate backend and frontend. Railway deploys each as its own service, with a managed PostgreSQL add‑on. Optionally, you can add an Nginx aggregator to serve UI and API under a single public domain.

Services
- Backend: FastAPI (CPU-only) using `promtok_backend/Dockerfile.railway`
- Frontend: Vite build served by `serve` using `promtok_frontend/Dockerfile.railway`
- Database: Railway PostgreSQL (managed). Set `DATABASE_URL` in the backend environment.
- Optional: Nginx aggregator using `nginx/Dockerfile.railway` (proxies `/` → frontend, `/api/*` & WebSockets → backend)

Monorepo deploy model on Railway
- Create multiple services within one Railway project; each service points to the same Git repo but uses its own Dockerfile path.
- For each service, set:
  - Repository: your GitHub repo (root is the monorepo root)
  - Build mode: Dockerfile
  - Dockerfile path: `promtok_backend/Dockerfile.railway`, `promtok_frontend/Dockerfile.railway`, or `nginx/Dockerfile.railway`
- The backend binds to `$PORT` automatically via `start.sh`. Frontend `serve` binds to `$PORT` as well.

Steps
1) Create a Railway project and add a PostgreSQL plugin.
2) Backend service → Deploy from GitHub repo and set:
   - Service name: promtok-backend
   - Dockerfile path: `promtok_backend/Dockerfile.railway`
3) Set backend environment variables:
   - `DATABASE_URL` (from Railway Postgres plugin)
   - `ADMIN_USERNAME` and `ADMIN_PASSWORD`
   - `JWT_SECRET_KEY` (use a strong random value)
   - `LOG_LEVEL=ERROR`
   - Optional CORS: `CORS_ALLOWED_ORIGINS` to your frontend domain, or `*` for testing
4) Frontend service:
   - Service name: promtok-frontend
   - Dockerfile path: `promtok_frontend/Dockerfile.railway`
5) Frontend environment variables (build-time):
   - `VITE_API_HTTP_URL` set to your backend public URL (e.g., `https://<backend-domain>`)
   - `VITE_API_WS_URL` set to backend websocket base (e.g., `wss://<backend-domain>`) if using websockets directly
   - `VITE_SERVER_TIMEZONE` as needed (defaults to `America/Chicago` if unset)
6) Deploy both services. Railway assigns a public URL to each. Use those in CORS and VITE build args accordingly.

Notes
- Backend binds to `$PORT` automatically via `start.sh`.
- GPU is not available on Railway; backend runs in CPU mode. The backend Dockerfile installs CPU-only PyTorch wheels.
- For local development, prefer `docker compose -f docker-compose.cpu.yml up -d`.
- To serve frontend and backend from one domain, deploy the optional Nginx aggregator and attach your custom domain to it.

Health checks
- Backend: `GET /health` should return `{ "status": "healthy" }`

Single-domain option via Nginx (optional)

If you prefer a single public domain that serves the frontend and proxies API/WebSocket traffic to the backend, you can deploy the provided Nginx service on Railway:

1) Add a new service with Dockerfile path: `nginx/Dockerfile.railway`
2) Set these variables on the Nginx service:
   - `FRONTEND_URL` = `https://<your-frontend>.railway.app`
   - `BACKEND_URL`  = `https://<your-backend>.railway.app`
   - Optional tuning: `CLIENT_MAX_BODY_SIZE` (default `500M`), `PROXY_READ_TIMEOUT`/`PROXY_SEND_TIMEOUT` (default `600s`), `PROXY_CONNECT_TIMEOUT` (default `60s`).
3) Deploy the service. Nginx listens on `$PORT` and proxies:
   - `/` → frontend
   - `/api/*` → backend
   - `/api/ws` and `/ws` → backend (WebSockets with Upgrade headers)

Advanced: If you want Nginx to serve the frontend static build instead of proxying `FRONTEND_URL`, build the frontend in a separate step and copy `dist` into an image derived from `nginx:alpine`. Then modify `nginx.conf.railway.template` root location to:

```
location / {
  root /usr/share/nginx/html;
  try_files $uri $uri/ /index.html;
}
```

and ensure the assets are copied to `/usr/share/nginx/html`.

Reference files
- `railway.backend.json`: backend variables and health check hints
- `railway.frontend.json`: frontend Dockerfile and build args
- `railway.nginx.json`: optional aggregator service variables
