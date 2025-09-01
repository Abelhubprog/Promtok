# Multi-stage build for React frontend
FROM node:20-alpine as build

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Accept build-time configuration for API endpoints (used by Vite at build time)
ARG VITE_API_HTTP_URL
ARG VITE_API_WS_URL
# Expose as env so Vite can read import.meta.env during build
ENV VITE_API_HTTP_URL=${VITE_API_HTTP_URL}
ENV VITE_API_WS_URL=${VITE_API_WS_URL}

# Install dependencies (including dev dependencies for build)
RUN npm install

# Copy source code
COPY . .

# Build the application (Vite will inline VITE_* values if provided)
RUN npm run build

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
