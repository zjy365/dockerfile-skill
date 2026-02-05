# Module: Project Analysis

## Purpose

Analyze a project to extract all information needed for Dockerfile generation.

## Execution Steps

### Step 1: Detect Language and Framework

Check for these files in order:

```
package.json        → Node.js (check for next/nuxt/express/koa/nest)
requirements.txt    → Python (check for django/flask/fastapi)
pyproject.toml      → Python (modern)
go.mod              → Go
pom.xml             → Java (Maven)
build.gradle        → Java (Gradle)
Cargo.toml          → Rust
composer.json       → PHP
Gemfile             → Ruby
```

For Node.js, additionally check:
- `next.config.*` → Next.js
- `nuxt.config.*` → Nuxt
- `nest-cli.json` → NestJS

### Step 2: Detect Package Manager

```
package-lock.json   → npm
yarn.lock           → yarn
pnpm-lock.yaml      → pnpm
bun.lockb           → bun
```

### Step 3: Extract Build and Run Commands

**Node.js**: Read `package.json` scripts:
```json
{
  "scripts": {
    "build": "...",        // Build command
    "start": "...",        // Production run command
    "dev": "..."           // Development (ignore)
  }
}
```

**Python**: Check for:
- `Makefile` with build targets
- `setup.py` / `pyproject.toml` entry points
- Common patterns: `uvicorn`, `gunicorn`, `python app.py`

**Go**: Standard `go build` → binary execution

### Step 4: Detect Port

Search patterns in source code:

```bash
# Node.js
grep -rE "listen\s*\(\s*[0-9]+" --include="*.js" --include="*.ts"
grep -rE "PORT.*[0-9]+" --include="*.js" --include="*.ts"

# Python
grep -rE "uvicorn.*port|flask.*port|run\(.*port" --include="*.py"

# Go
grep -rE "ListenAndServe.*:" --include="*.go"
```

Common defaults:
- Express/Koa/Nest: 3000
- Next.js: 3000
- FastAPI/Django: 8000
- Go: 8080
- Spring Boot: 8080

### Step 5: Detect External Services

Search for environment variable patterns:

```bash
# Database
grep -rE "DATABASE_URL|POSTGRES_|MYSQL_|MONGODB_URI" .

# Redis
grep -rE "REDIS_URL|REDIS_HOST" .

# S3/Object Storage
grep -rE "S3_|AWS_|MINIO_" .

# Message Queue
grep -rE "RABBITMQ_|KAFKA_|AMQP_" .
```

### Step 6: Detect System Library Requirements

Check `package.json` dependencies for known native modules:

| NPM Package | Requires |
|-------------|----------|
| sharp | libvips-dev |
| canvas / @napi-rs/canvas | build-essential, libcairo2-dev, libpango1.0-dev |
| better-sqlite3 | python3, make, g++ |
| bcrypt | python3, make, g++ |
| node-gyp (any) | python3, make, g++ |

Check `requirements.txt` for Python:

| Pip Package | Requires |
|-------------|----------|
| psycopg2 | libpq-dev |
| Pillow | libjpeg-dev, libpng-dev |
| cryptography | libssl-dev, libffi-dev |
| lxml | libxml2-dev, libxslt-dev |

### Step 7: Check for Existing Docker Configuration

Look for:
- `Dockerfile` / `Dockerfile.*`
- `docker-compose.yml` / `docker-compose.yaml`
- `.dockerignore`

If found, extract key decisions for reference (DO NOT blindly copy).

### Step 8: Detect Workspace/Monorepo Configuration

**For pnpm workspaces**:
```bash
# Check for pnpm-workspace.yaml
if [ -f "pnpm-workspace.yaml" ]; then
  # Parse workspace packages
  grep -E "^\s*-\s+" pnpm-workspace.yaml
fi

# Check for patches directory (pnpm patch feature)
if [ -d "patches" ]; then
  PATCHES_DIR="patches"
fi
```

**For npm/yarn workspaces**:
```bash
# Check package.json workspaces field
grep -A 20 '"workspaces"' package.json
```

**For Turborepo**:
```bash
# Check for turbo.json
if [ -f "turbo.json" ]; then
  MONOREPO_TYPE="turborepo"
fi
```

**Output for workspace analysis**:
```yaml
workspace:
  enabled: true
  type: "pnpm"                    # pnpm | npm | yarn | turborepo | nx
  config_file: "pnpm-workspace.yaml"
  packages:
    - "packages/**"
    - "apps/desktop/src/main"
    - "e2e"
  patches_dir: "patches"          # pnpm patched dependencies
  required_files:                 # Files that MUST be copied for workspace to work
    - "pnpm-workspace.yaml"
    - "patches/**"
    - "packages/*/package.json"
    - "apps/desktop/src/main/package.json"
    - "e2e/package.json"
```

### Step 9: Detect Package Manager Configuration

**Check .npmrc / .yarnrc.yml**:
```bash
# Check for lockfile=false (common in some projects)
if grep -q "lockfile=false" .npmrc 2>/dev/null; then
  LOCKFILE_DISABLED=true
fi

# Check for other important settings
grep -E "^(resolution-mode|public-hoist-pattern|shamefully-hoist)" .npmrc
```

**Output**:
```yaml
package_manager_config:
  lockfile_disabled: true         # If lockfile=false in .npmrc
  config_file: ".npmrc"
  special_settings:
    - "lockfile=false"
    - "resolution-mode=highest"
```

### Step 10: Detect Build-Time Environment Variables

**Scan for build-time required env vars**:
```bash
# Check for env validation in config files
grep -rE "process\.env\.\w+" src/ --include="*.ts" --include="*.js" | \
  grep -E "(throw|required|must be set)" | \
  grep -oE "process\.env\.\w+" | sort -u

# Check for @t3-oss/env-nextjs or similar
grep -rE "createEnv|z\.string\(\)" src/env* 2>/dev/null
```

**Common build-time required vars for Next.js**:
- `KEY_VAULTS_SECRET` - Database encryption
- `DATABASE_URL` - For static page generation with DB access
- `AUTH_SECRET` - Authentication

**Output**:
```yaml
build_time_env:
  required:
    - name: KEY_VAULTS_SECRET
      source: "src/libs/server-config/db.ts"
      placeholder: "build-placeholder-32chars"
    - name: DATABASE_URL
      source: "src/libs/server-config/db.ts"
      placeholder: "postgres://placeholder:placeholder@localhost:5432/placeholder"
  optional:
    - name: NEXT_PUBLIC_API_URL
      default: "http://localhost:3000"
```

### Step 11: Detect Custom Scripts and Entry Points

**Check for docker-specific scripts**:
```bash
# Look for docker-specific build scripts
grep -E '"build:docker"|"start:docker"|"docker"' package.json

# Check for custom server entry points
ls -la scripts/serverLauncher/*.js 2>/dev/null
ls -la scripts/*/startServer.js 2>/dev/null
```

**Output**:
```yaml
custom_scripts:
  build: "npm run build:docker"           # Prefer docker-specific if exists
  start: "node startServer.js"
  entry_point: "scripts/serverLauncher/startServer.js"
  migrations: "scripts/migrateServerDB/docker.cjs"
```

### Step 12: Determine Complexity Level

**L1 (Simple)**:
- Single language
- No build step OR simple build (just `npm install`)
- No external service dependencies
- No workspace
- Examples: Express API, simple Python script

**L2 (Medium)**:
- Has build step (Next.js, TypeScript compilation, etc.)
- Has external services (Database, Redis)
- May have environment variable requirements at build time
- Examples: Next.js app, Django with PostgreSQL

**L3 (Complex)**:
- Monorepo structure (pnpm-workspace, turborepo, nx)
- Multi-language (Python backend + Node frontend)
- Complex build pipeline
- Many external dependencies
- Has build-time env var requirements
- Custom entry points / server launchers
- Examples: Dify, Affine, LobeChat, large enterprise apps

## Output Format

```yaml
analysis:
  language: "typescript"
  framework: "nextjs"
  framework_version: "16.x"
  package_manager: "pnpm"
  package_manager_version: "10.20.0"

  # Package manager configuration
  package_manager_config:
    lockfile_disabled: true           # lockfile=false in .npmrc
    config_file: ".npmrc"
    install_command: "pnpm install"   # NOT --frozen-lockfile if lockfile disabled

  # Workspace / Monorepo configuration
  workspace:
    enabled: true
    type: "pnpm"
    config_file: "pnpm-workspace.yaml"
    packages:
      - "packages/**"
      - "apps/desktop/src/main"
      - "e2e"
    patches_dir: "patches"
    required_copy_files:              # Files MUST be copied for workspace
      - path: "pnpm-workspace.yaml"
        dest: "./"
      - path: "patches"
        dest: "./patches"
      - path: "packages"
        dest: "./packages"
      - path: "e2e/package.json"
        dest: "./e2e/"
      - path: "apps/desktop/src/main/package.json"
        dest: "./apps/desktop/src/main/"

  # Build configuration
  build:
    command: "npm run build:docker"   # Prefer docker-specific script
    fallback_command: "npm run build"
    output_dir: ".next"
    standalone_mode: true             # output: 'standalone' in next.config
    env_required:                     # Build-time required env vars
      - name: KEY_VAULTS_SECRET
        placeholder: "build-placeholder-32chars"
      - name: DATABASE_URL
        placeholder: "postgres://placeholder:placeholder@localhost:5432/placeholder"
      - name: AUTH_SECRET
        placeholder: "build-placeholder-auth-secret"

  # Runtime configuration
  run:
    command: "node startServer.js"
    entry_point: "scripts/serverLauncher/startServer.js"
    port: 3210
    env_required:
      - DATABASE_URL
      - KEY_VAULTS_SECRET
      - AUTH_SECRET

  # External dependencies
  dependencies:
    external_services:
      - type: postgres
        env_var: DATABASE_URL
        recommended_image: "pgvector/pgvector:pg16"
      - type: redis
        env_var: REDIS_URL
        optional: true
      - type: s3
        env_var: S3_ENDPOINT
        optional: true
    system_libs:
      - name: sharp
        packages: ["libvips-dev"]
      - name: "@napi-rs/canvas"
        packages: ["build-essential", "libcairo2-dev", "libpango1.0-dev"]

  # Files that must NOT be excluded from docker build context
  required_files:
    - ".npmrc"                        # Package manager config
    - "pnpm-workspace.yaml"
    - "patches/**"
    - "scripts/prebuild.mts"
    - "scripts/serverLauncher/**"
    - "scripts/migrateServerDB/**"
    - "scripts/_shared/**"
    - "packages/database/migrations/**"

  # Existing docker configuration analysis
  existing_docker:
    has_dockerfile: false
    has_compose: false
    key_decisions: []

  # Complexity assessment
  complexity: "L3"
  max_iterations: 5

  # Warnings / Notes
  warnings:
    - "Project uses lockfile=false - cannot use --frozen-lockfile"
    - "Workspace packages must be copied individually for Docker cache optimization"
    - "Build requires placeholder env vars for Next.js static generation"
```
