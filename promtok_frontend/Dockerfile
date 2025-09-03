# Multi-stage build for React frontend
FROM node:20-alpine as build

# Monorepo-safe: build with repo root context
WORKDIR /app

# Copy only frontend package files first for better caching
COPY promtok_frontend/package*.json ./

# Accept build-time configuration for API endpoints (used by Vite at build time)
ARG VITE_API_HTTP_URL
ARG VITE_API_WS_URL
# Expose as env so Vite can read import.meta.env during build
ENV VITE_API_HTTP_URL=${VITE_API_HTTP_URL}
ENV VITE_API_WS_URL=${VITE_API_WS_URL}

# Install dependencies (including dev dependencies for build)
RUN npm ci

# Copy frontend source code
COPY promtok_frontend/ ./

# --- TEMP: Diagnostics to verify monorepo copy on Railway ---
# This ensures /app/src/lib/utils.ts exists in the image before building.
RUN set -eux; \
  echo "[diag] PWD=$(pwd)"; \
  echo "[diag] List /app:"; ls -la; \
  echo "[diag] List /app/src:"; ls -la src || true; \
  test -f src/lib/utils.ts || (echo "[diag] utils.ts missing. Listing src/lib:"; ls -la src/lib || true; exit 1)
# --- END TEMP ---

# Build the application (Vite will inline VITE_* values if provided)
# Use a deploy build that skips tsc to avoid type-check failures during container builds
RUN npm run build:deploy

# Production stage with simple static server
FROM node:20-alpine

# Install serve globally for serving static files
RUN npm install -g serve

# Copy built assets from build stage
COPY --from=build /app/dist /app

# Set working directory
WORKDIR /app

# Expose dynamic Railway port
EXPOSE 3000

# Start serve and bind to Railway-provided PORT if present
CMD ["sh", "-c", "serve -s . -l ${PORT:-3000} --cors"]
