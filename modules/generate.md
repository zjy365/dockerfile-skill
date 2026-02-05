# Module: Dockerfile Generation

## Purpose

Generate production-ready Dockerfile based on analysis results.

## Input

Project analysis from `analyze.md` module.

## Generation Rules

### Rule 1: Select Base Template

Based on `analysis.framework` and `analysis.package_manager`:

| Framework | Package Manager | Template |
|-----------|-----------------|----------|
| express / koa / nestjs | npm/yarn/pnpm | [templates/nodejs-express.dockerfile](../templates/nodejs-express.dockerfile) |
| nextjs | npm/yarn/pnpm | [templates/nodejs-nextjs.dockerfile](../templates/nodejs-nextjs.dockerfile) |
| nextjs | bun | [templates/nodejs-nextjs-bun.dockerfile](../templates/nodejs-nextjs-bun.dockerfile) |
| nuxt | any | [templates/nodejs-nuxt.dockerfile](../templates/nodejs-nuxt.dockerfile) |
| fastapi / flask | any | [templates/python-fastapi.dockerfile](../templates/python-fastapi.dockerfile) |
| django | any | [templates/python-django.dockerfile](../templates/python-django.dockerfile) |
| go (any) | any | [templates/golang.dockerfile](../templates/golang.dockerfile) |
| springboot | any | [templates/java-springboot.dockerfile](../templates/java-springboot.dockerfile) |

**Package Manager Detection**:
- `bun.lockb` → Bun
- `pnpm-lock.yaml` → pnpm
- `yarn.lock` → Yarn
- `package-lock.json` → npm

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

**Rule 1: Always Enable Standalone Output (Recommended)**

Standalone mode can reduce image size by 80-90% (e.g., from 3GB to 350MB).

1. **Check next.config.{js,mjs,ts}** for existing `output: 'standalone'`
2. **If not present, automatically add it**:
   ```javascript
   // next.config.mjs
   const nextConfig = {
     output: 'standalone',  // Add this line
     // ... other config
   }
   ```

3. **Standalone Mode Dockerfile**:
   ```dockerfile
   # Only copy standalone output, no full node_modules needed
   COPY --from=builder /app/public ./public
   COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
   COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
   CMD ["node", "server.js"]
   ```

4. **Non-Standalone Mode** (not recommended, large image):
   ```dockerfile
   COPY --from=build /app/.next ./.next
   COPY --from=build /app/node_modules ./node_modules
   CMD ["npm", "start"]
   ```

**Rule 2: Detect SDK Initialization in API Routes**

Next.js statically analyzes all routes during build. If an API route has top-level SDK initialization:
```typescript
// app/api/mail/route.ts
const resend = new Resend(process.env.RESEND_API_KEY);  // Executes at build time!
```

**Detection Method**:
```bash
# Scan for process.env usage in API routes
grep -r "process\.env\.\w\+" app/api/ --include="*.ts" --include="*.tsx"
```

**Fix**: Add placeholder environment variables in build stage
```dockerfile
# Build stage - add placeholders (only for passing static analysis)
ARG RESEND_API_KEY=re_placeholder_key
ARG NOTION_SECRET=placeholder_secret
ENV RESEND_API_KEY=${RESEND_API_KEY}
ENV NOTION_SECRET=${NOTION_SECRET}
# Actual values are injected at runtime via docker run -e or compose
```

**Common SDKs Requiring Placeholders**:
- Resend: `RESEND_API_KEY`
- Stripe: `STRIPE_SECRET_KEY`
- Notion: `NOTION_SECRET`, `NOTION_DB`
- Upstash: `UPSTASH_REDIS_REST_URL`, `UPSTASH_REDIS_REST_TOKEN`
- Supabase: `SUPABASE_URL`, `SUPABASE_KEY`

#### Monorepo Special Rules (L3)

1. For Turborepo:
   ```dockerfile
   RUN npx turbo prune --scope=<target-app> --docker
   ```

2. For pnpm workspace:
   ```dockerfile
   # Copy workspace configuration
   COPY package.json pnpm-workspace.yaml .npmrc ./

   # Copy all workspace package.json files
   COPY packages ./packages
   COPY patches ./patches
   COPY e2e/package.json ./e2e/
   COPY apps/desktop/src/main/package.json ./apps/desktop/src/main/

   # Install - check if lockfile is disabled
   # If lockfile=false in .npmrc:
   RUN pnpm install --ignore-scripts
   # Otherwise:
   RUN pnpm install --frozen-lockfile --ignore-scripts
   ```

3. For pnpm workspace with `lockfile=false`:
   ```dockerfile
   # IMPORTANT: Do NOT use --frozen-lockfile
   # Check .npmrc for lockfile=false
   RUN pnpm install --ignore-scripts
   ```

4. Handle custom entry points:
   ```dockerfile
   # If project has custom startServer.js or similar
   COPY --from=builder /app/scripts/serverLauncher/startServer.js ./startServer.js
   COPY --from=builder /app/scripts/_shared ./scripts/_shared

   # Handle database migrations
   COPY --from=builder /app/scripts/migrateServerDB/docker.cjs ./docker.cjs
   COPY --from=builder /app/packages/database/migrations ./migrations
   ```

5. Handle build-time environment variables:
   ```dockerfile
   # For Next.js apps that require env vars at build time
   # Use ARG for build-time only (more secure than ENV)
   ARG KEY_VAULTS_SECRET_PLACEHOLDER="build-placeholder-key-32chars"
   ARG DATABASE_URL_PLACEHOLDER="postgres://placeholder:placeholder@localhost:5432/placeholder"

   ENV KEY_VAULTS_SECRET=${KEY_VAULTS_SECRET_PLACEHOLDER}
   ENV DATABASE_URL=${DATABASE_URL_PLACEHOLDER}
   ENV AUTH_SECRET=${KEY_VAULTS_SECRET_PLACEHOLDER}
   ENV DATABASE_DRIVER=""
   ```

6. Handle Node.js path compatibility:
   ```dockerfile
   # Some scripts hardcode /bin/node but node:slim has it in /usr/local/bin
   RUN ln -sf /usr/local/bin/node /bin/node
   ```

## Output Files

### 1. Dockerfile

Generated based on template + rules above.

### 2. .dockerignore

**IMPORTANT**: For workspace/monorepo projects, .dockerignore must be carefully crafted to:
1. Exclude unnecessary files for smaller context
2. BUT include all workspace package.json files
3. BUT include patches directory
4. BUT include required build scripts

**Smart .dockerignore Generation Rules**:

1. Check `analysis.workspace.required_copy_files` - these MUST NOT be excluded
2. Check `analysis.required_files` - these MUST NOT be excluded
3. Use negation patterns (`!`) to re-include specific files

```
# VCS
.git
.gitignore
.gitattributes

# Dependencies (will be installed in container)
node_modules
**/node_modules
.pnpm-store

# Build outputs (will be regenerated)
.next
out
dist
build
coverage
*.tsbuildinfo

# Local environment
.env
.env.local
.env.*.local
# Keep example files for reference
!.env.example
!.env.docker.example

# IDE
.vscode
.idea
*.swp
*.swo

# Documentation (not needed for runtime)
docs
*.md
!README.md

# Tests (for workspace, keep package.json only)
# IMPORTANT: Use e2e/* not e2e to allow !e2e/package.json
e2e/*
!e2e/package.json
tests
**/*.test.ts
**/*.test.tsx
**/*.spec.ts
**/*.spec.tsx

# Desktop app (keep package.json for workspace)
apps/desktop/node_modules
apps/desktop/dist
apps/desktop/out
# Note: Do NOT exclude apps/desktop entirely if it's a workspace package

# CI/CD
.github
.gitlab
.circleci

# Docker files (avoid recursion)
Dockerfile*
docker-compose*.yml
!docker-compose/

# Misc
.DS_Store
Thumbs.db
*.log
npm-debug.log*
.pnpm-debug.log*

# Cache
.cache
.turbo
.eslintcache
.stylelintcache

# Source maps (optional, may want for debugging)
# *.map

# Scripts not needed for runtime
# IMPORTANT: Do NOT exclude scripts needed for build/start
# scripts/prebuild.mts    # Needed for build
# scripts/serverLauncher  # Needed for start
scripts/cdnWorkflow
scripts/changelogWorkflow
scripts/docsWorkflow
scripts/i18nWorkflow
scripts/mdxWorkflow
scripts/readmeWorkflow
```

**Validation Checklist for .dockerignore**:

- [ ] All workspace package.json files are NOT excluded
- [ ] patches/ directory is NOT excluded (if pnpm patches used)
- [ ] .npmrc is NOT excluded (needed for pnpm config)
- [ ] Build scripts are NOT excluded (prebuild.mts, etc.)
- [ ] Server launcher scripts are NOT excluded
- [ ] Migration scripts are NOT excluded

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
