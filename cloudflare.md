# Deploying Promtok to Cloudflare

## Overview

This guide explores multiple strategies for deploying the Promtok application to Cloudflare. The application consists of a FastAPI backend, React frontend, PostgreSQL database, and AI/ML components.

## Application Architecture Analysis

### Current Components
- **Backend**: FastAPI with 10+ API endpoints (`/api/auth`, `/api/missions`, `/api/chat`, etc.)
- **Frontend**: React/Vite application with routing
- **Database**: PostgreSQL with pgvector for embeddings
- **Background Processing**: Document processing workers
- **AI/ML**: HuggingFace models, vector search, LLM integrations

### Cloudflare Compatibility
- ✅ **Frontend**: Perfect for Cloudflare Pages
- ⚠️ **Backend**: Requires Workers or alternative hosting
- ❌ **PostgreSQL**: Not directly supported (use D1 or external DB)
- ⚠️ **Background Processing**: Limited options
- ✅ **AI/ML**: Cloudflare Workers AI available

## Deployment Strategies

### Strategy 1: Hybrid Approach (Recommended)

**Best for**: Production deployment with optimal performance/cost balance

#### Architecture
```
Internet → Cloudflare Pages (Frontend)
           ↓
Cloudflare Workers (API Gateway)
           ↓
External PostgreSQL + Cloudflare R2 (Storage)
           ↓
Cloudflare Queues (Background Processing)
```

#### Components Mapping
| Component | Cloudflare Service | Alternative |
|-----------|-------------------|-------------|
| Frontend | Cloudflare Pages | Vercel, Netlify |
| API Gateway | Cloudflare Workers | Railway, Render |
| Database | External PostgreSQL | Cloudflare D1 (limited) |
| File Storage | Cloudflare R2 | AWS S3, Google Cloud |
| Background Jobs | Cloudflare Queues | Railway, Render |
| AI/ML | Cloudflare Workers AI | OpenAI, Anthropic |

#### Implementation Steps

1. **Deploy Frontend to Cloudflare Pages**
```bash
# Install Wrangler
npm install -g wrangler

# Login to Cloudflare
wrangler auth login

# Create pages project
cd promtok_frontend
wrangler pages project create promtok-frontend

# Deploy
wrangler pages deploy dist
```

2. **Create API Gateway with Workers**
```javascript
// functions/api/[[path]].js
export async function onRequest(context) {
  const { request, env } = context;
  const url = new URL(request.url);

  // Route to external backend
  const backendUrl = `https://your-backend.railway.app${url.pathname}${url.search}`;

  return fetch(backendUrl, {
    method: request.method,
    headers: request.headers,
    body: request.body
  });
}
```

3. **Database Setup**
```sql
-- Use external PostgreSQL (Railway, Neon, Supabase)
-- Or migrate to Cloudflare D1 (limited SQL support)

-- For D1 migration, you'd need to:
-- 1. Remove pgvector dependencies
-- 2. Convert to D1-compatible SQL
-- 3. Update all queries
```

4. **File Storage with R2**
```javascript
// Upload to R2
const uploadToR2 = async (file, env) => {
  const bucket = env.MY_BUCKET;
  await bucket.put(`uploads/${file.name}`, file);
};
```

### Strategy 2: Full Cloudflare Stack

**Best for**: Serverless-first approach, maximum scalability

#### Architecture
```
Internet → Cloudflare Pages (Frontend)
           ↓
Cloudflare Workers (Backend APIs)
           ↓
Cloudflare D1 (Database) + R2 (Storage)
           ↓
Cloudflare Queues (Background Processing)
```

#### Required Modifications

1. **Convert FastAPI to Workers**
```javascript
// api/auth.js
export async function onRequestPost({ request, env }) {
  const { email, password } = await request.json();

  // Use D1 for user storage
  const { results } = await env.DB.prepare(
    "SELECT * FROM users WHERE email = ?"
  ).bind(email).run();

  // Authentication logic here
  return new Response(JSON.stringify({ token: "..." }));
}
```

2. **Database Migration to D1**
```sql
-- Create D1 tables (simplified, no pgvector)
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  email TEXT UNIQUE,
  password_hash TEXT,
  created_at INTEGER
);

CREATE TABLE documents (
  id INTEGER PRIMARY KEY,
  title TEXT,
  content TEXT,
  user_id INTEGER,
  created_at INTEGER
);
```

3. **Workers AI Integration**
```javascript
// Use Cloudflare Workers AI instead of local models
const response = await env.AI.run('@cf/meta/llama-2-7b-chat-int8', {
  messages: [{ role: 'user', content: prompt }]
});
```

### Strategy 3: Minimal Cloudflare (Pages Only)

**Best for**: Quick deployment, development/demo

#### Architecture
```
Internet → Cloudflare Pages (Frontend + API Proxy)
           ↓
External Backend (Railway/Render)
           ↓
External Database
```

#### Quick Setup
```bash
# Deploy only frontend
cd promtok_frontend
npm run build
wrangler pages deploy dist --project-name promtok-demo

# Configure environment variables
wrangler pages deployment tail
```

### Strategy 4: Cloudflare Tunnel (Development)

**Best for**: Local development with Cloudflare edge

```bash
# Install cloudflared
# Connect local app to Cloudflare
cloudflared tunnel --url http://localhost:8080

# Access via Cloudflare domain
# https://your-app.your-domain.pages.dev
```

## Detailed Implementation Guide

### Frontend Deployment (Cloudflare Pages)

1. **Build Configuration**
```javascript
// wrangler.toml
name = "promtok-frontend"
compatibility_date = "2024-01-01"

[env.production]
routes = [
  { pattern = "/*", zone_name = "yourdomain.com" }
]

[vars]
API_URL = "https://your-api.yourdomain.com"
```

2. **Environment Variables**
```bash
# Set in Cloudflare Dashboard or wrangler
API_BASE_URL=https://your-backend-api.com
VITE_API_URL=https://your-backend-api.com
```

### Backend Migration Strategies

#### Option A: Railway + Cloudflare (Easiest)
```bash
# Deploy to Railway (supports Docker)
railway login
railway link
railway up

# Get Railway URL
railway domain

# Configure Cloudflare DNS
# Point yourdomain.com to Railway
```

#### Option B: Workers Migration (Advanced)
```javascript
// Convert FastAPI routes to Workers
// /api/auth → functions/api/auth.js
// /api/missions → functions/api/missions.js
// etc.
```

### Database Migration

#### Option A: Keep PostgreSQL (Recommended)
```bash
# Use Railway PostgreSQL or Neon
DATABASE_URL=postgresql://user:pass@host:5432/db

# Configure connection pooling
# Use pgBouncer or similar
```

#### Option B: Migrate to D1 (Limited)
```sql
-- D1 doesn't support pgvector
-- Need to remove vector search features
-- Use alternative embedding storage
```

### File Storage Setup

```javascript
// R2 Configuration
const R2_BUCKET = {
  binding: 'MY_BUCKET',
  bucket_name: 'promtok-files'
};

// Upload function
export async function uploadFile(file, env) {
  const bucket = env.MY_BUCKET;
  const key = `uploads/${Date.now()}-${file.name}`;

  await bucket.put(key, file, {
    httpMetadata: {
      contentType: file.type,
    },
  });

  return `https://files.yourdomain.com/${key}`;
}
```

## Cost Analysis

### Strategy 1: Hybrid (Recommended)
| Service | Cost | Notes |
|---------|------|-------|
| Cloudflare Pages | Free | 100GB/month included |
| Cloudflare Workers | Free | 100k requests/day |
| Railway (Backend) | $5-10/month | Hobby plan |
| Railway PostgreSQL | $10-20/month | With pgvector |
| Cloudflare R2 | Free | First 10GB |
| **Total** | **$15-30/month** | Production ready |

### Strategy 2: Full Cloudflare
| Service | Cost | Notes |
|---------|------|-------|
| Cloudflare Pages | Free |  |
| Cloudflare Workers | Free | 100k requests/day |
| Cloudflare D1 | Free | 500MB included |
| Cloudflare R2 | Free | 10GB included |
| Cloudflare Queues | Free | 1M operations/month |
| **Total** | **Free** | Limited by D1 constraints |

### Strategy 3: Minimal
| Service | Cost | Notes |
|---------|------|-------|
| Cloudflare Pages | Free |  |
| Railway | $5-10/month | Backend only |
| **Total** | **$5-10/month** | Quick setup |

## Limitations & Considerations

### Cloudflare D1 Limitations
- No pgvector support (vector embeddings)
- Limited SQL features
- 500MB free storage
- No JOINs in some cases

### Workers Limitations
- 30-second execution limit
- 128MB memory limit
- No persistent file system
- Limited Python support (use JavaScript/TypeScript)

### Migration Challenges
- **AI/ML Models**: Local models won't work in Workers
- **Background Processing**: Limited to Queues (no long-running tasks)
- **File Processing**: Need to handle in Workers or external service
- **WebSockets**: Limited support in Workers

## Migration Checklist

### Phase 1: Frontend Only
- [ ] Deploy React app to Cloudflare Pages
- [ ] Configure environment variables
- [ ] Set up custom domain
- [ ] Test static deployment

### Phase 2: API Gateway
- [ ] Create Workers for API routing
- [ ] Set up CORS policies
- [ ] Configure authentication
- [ ] Test API endpoints

### Phase 3: Database Migration
- [ ] Choose database solution (Railway vs D1)
- [ ] Migrate schema and data
- [ ] Update connection strings
- [ ] Test database operations

### Phase 4: File Storage
- [ ] Set up R2 bucket
- [ ] Migrate existing files
- [ ] Update upload/download logic
- [ ] Test file operations

### Phase 5: Background Processing
- [ ] Implement with Cloudflare Queues
- [ ] Or use external service (Railway)
- [ ] Test document processing
- [ ] Monitor performance

## Quick Start Commands

```bash
# 1. Install Wrangler
npm install -g wrangler

# 2. Authenticate
wrangler auth login

# 3. Deploy frontend
cd promtok_frontend
npm run build
wrangler pages deploy dist

# 4. Get deployment URL
wrangler pages deployment list
```

## Next Steps

1. **Start with Strategy 3** (minimal) for quick deployment
2. **Migrate to Strategy 1** (hybrid) for production
3. **Consider Strategy 2** (full Cloudflare) for serverless architecture
4. **Use Cloudflare Tunnel** for development testing

## Resources

- [Cloudflare Pages Documentation](https://developers.cloudflare.com/pages/)
- [Cloudflare Workers Documentation](https://developers.cloudflare.com/workers/)
- [Cloudflare D1 Documentation](https://developers.cloudflare.com/d1/)
- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/)

This guide provides multiple deployment paths based on your needs, from simple static hosting to full serverless architecture.
