# Module: Dockerfile Generation

## Purpose

Generate production-ready Dockerfile based on analysis results.

## Input

Project analysis from `analyze.md` module.

## Generation Rules

### Rule 1: Select Base Template

Based on `analysis.framework`:

| Framework | Template |
|-----------|----------|
| express / koa / nestjs | [templates/nodejs-express.dockerfile](../templates/nodejs-express.dockerfile) |
| nextjs | [templates/nodejs-nextjs.dockerfile](../templates/nodejs-nextjs.dockerfile) |
| nuxt | [templates/nodejs-nuxt.dockerfile](../templates/nodejs-nuxt.dockerfile) |
| fastapi / flask | [templates/python-fastapi.dockerfile](../templates/python-fastapi.dockerfile) |
| django | [templates/python-django.dockerfile](../templates/python-django.dockerfile) |
| go (any) | [templates/golang.dockerfile](../templates/golang.dockerfile) |
| springboot | [templates/java-springboot.dockerfile](../templates/java-springboot.dockerfile) |

### Rule 2: Apply Best Practices

Every generated Dockerfile MUST include:

1. **Fixed version tags** (NEVER use `latest`)
   ```dockerfile
   # Good
   FROM node:20.11.1-slim

   # Bad
   FROM node:latest
   FROM node:lts
   ```

2. **Multi-stage build** (when applicable)
   ```dockerfile
   FROM node:20-slim AS deps
   FROM deps AS build
   FROM node:20-slim AS runtime
   ```

3. **Cache optimization**
   ```dockerfile
   # Copy dependency files first
   COPY package.json package-lock.json ./
   RUN npm ci

   # Then copy source
   COPY . .
   ```

4. **BuildKit cache mounts** (for package managers)
   ```dockerfile
   RUN --mount=type=cache,target=/root/.npm npm ci
   RUN --mount=type=cache,target=/root/.cache/pip pip install -r requirements.txt
   RUN --mount=type=cache,target=/go/pkg/mod go build
   ```

5. **Non-root user**
   ```dockerfile
   USER node          # Node.js
   USER appuser       # Python (create first)
   USER nobody        # Go (statically compiled)
   ```

6. **Minimal runtime image**
   - Node.js: `node:XX-slim` (not alpine, better compatibility)
   - Python: `python:3.XX-slim`
   - Go: `alpine` or `scratch`
   - Java: `eclipse-temurin:XX-jre-alpine`

7. **Clean package manager cache**
   ```dockerfile
   RUN apt-get update && apt-get install -y ... \
       && rm -rf /var/lib/apt/lists/*
   ```

8. **HEALTHCHECK** (without installing curl)
   ```dockerfile
   # Node.js
   HEALTHCHECK CMD node -e "require('http').get('http://127.0.0.1:3000/health')"

   # Python
   HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
   ```

### Rule 3: Handle System Dependencies

If `analysis.dependencies.system_libs` is not empty:

```dockerfile
# Build stage - install build tools
FROM node:20-slim AS deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Runtime stage - minimal packages only
FROM node:20-slim AS runtime
# Only install runtime libs if needed (e.g., libvips for sharp)
```

### Rule 4: Handle External Services

If `analysis.dependencies.external_services` is not empty:

1. Generate `docker-compose.yml` with required services
2. Document required environment variables
3. Add health checks for dependent services

### Rule 5: Framework-Specific Handling

#### Next.js Special Rules

1. Check for `output: 'standalone'` in next.config
2. If standalone mode:
   ```dockerfile
   COPY --from=build /app/.next/standalone ./
   COPY --from=build /app/.next/static ./.next/static
   COPY --from=build /app/public ./public
   CMD ["node", "server.js"]
   ```

3. If NOT standalone:
   ```dockerfile
   COPY --from=build /app/.next ./.next
   COPY --from=build /app/node_modules ./node_modules
   CMD ["npm", "start"]
   ```

#### Monorepo Special Rules (L3)

1. For Turborepo:
   ```dockerfile
   RUN npx turbo prune --scope=<target-app> --docker
   ```

2. For pnpm workspace:
   ```dockerfile
   COPY pnpm-lock.yaml pnpm-workspace.yaml ./
   COPY packages/*/package.json ./packages/
   RUN pnpm install --frozen-lockfile
   ```

## Output Files

### 1. Dockerfile

Generated based on template + rules above.

### 2. .dockerignore

```
# VCS
.git
.github
.gitignore

# Dependencies (will be installed in container)
node_modules
__pycache__
.venv
vendor

# Build outputs
.next
dist
build
coverage

# Local environment
.env
.env.*
*.local

# IDE
.vscode
.idea

# Logs
*.log
npm-debug.log*

# OS
.DS_Store
Thumbs.db
```

### 3. docker-compose.yml (if external services)

```yaml
services:
  app:
    build: .
    ports:
      - "${PORT:-3000}:${PORT:-3000}"
    environment:
      - DATABASE_URL=postgres://postgres:postgres@db:5432/app
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: app
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  pgdata:
```

### 4. Environment Documentation

Output a summary of required environment variables:

```
## Required Environment Variables

### Build Time
(none required)

### Runtime
- DATABASE_URL: PostgreSQL connection string
- REDIS_URL: Redis connection string (optional)
- PORT: Server port (default: 3000)
```

## Validation Checklist

Before proceeding to build phase, verify:

- [ ] Base image version is fixed (not `latest`)
- [ ] Multi-stage build is used (if build step exists)
- [ ] Non-root user is configured
- [ ] EXPOSE matches detected port
- [ ] CMD/ENTRYPOINT is correct
- [ ] .dockerignore excludes sensitive files
