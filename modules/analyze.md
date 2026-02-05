# Module: Project Analysis

## Purpose

Analyze a project to extract all information needed for Dockerfile generation.

## Execution Steps

### Step 1: Detect Language and Framework

Check for these files in order:

```
package.json    → Node.js (check for next/nuxt/express/koa/nest)
requirements.txt  → Python (check for django/flask/fastapi)
pyproject.toml   → Python (modern)
go.mod       → Go
pom.xml       → Java (Maven)
build.gradle    → Java (Gradle)
Cargo.toml     → Rust
composer.json    → PHP
Gemfile       → Ruby
```

For Node.js, additionally check:
- `next.config.*` → Next.js
- `nuxt.config.*` → Nuxt
- `nest-cli.json` → NestJS

### Step 2: Detect Package Manager

```
package-lock.json  → npm
yarn.lock      → yarn
pnpm-lock.yaml   → pnpm
bun.lockb      → bun
```

### Step 3: Extract Build and Run Commands

**Node.js**: Read `package.json` scripts:
```json
{
 "scripts": {
  "build": "...",    // Build command
  "start": "...",    // Production run command
  "dev": "..."      // Development (ignore)
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
 type: "pnpm"          # pnpm | npm | yarn | turborepo | nx
 config_file: "pnpm-workspace.yaml"
 packages:
  - "packages/**"
  - "apps/desktop/src/main"
  - "e2e"
 patches_dir: "patches"     # pnpm patched dependencies
 required_files:         # Files that MUST be copied for workspace to work
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
 lockfile_disabled: true     # If lockfile=false in .npmrc
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
 build: "npm run build:docker"      # Prefer docker-specific if exists
 start: "node startServer.js"
 entry_point: "scripts/serverLauncher/startServer.js"
 migrations: "scripts/migrateServerDB/docker.cjs"
```

### Step 12: Detect Database Migration System

**Purpose**: Critical to detect migrations BEFORE Dockerfile generation to prevent runtime failures.

**Detection Checklist**:
```bash
# 1. Check for migration directories
MIGRATION_DIRS=(
 "packages/database/migrations"
 "prisma/migrations"
 "drizzle"
 "migrations"
 "db/migrations"
 "database/migrations"
)

for dir in "${MIGRATION_DIRS[@]}"; do
 if [ -d "$dir" ]; then
  MIGRATION_DIR="$dir"
  MIGRATION_COUNT=$(find "$dir" -name "*.sql" -o -name "*.ts" -o -name "*.js" | wc -l)
  break
 fi
done

# 2. Detect ORM type
if [ -f "prisma/schema.prisma" ]; then
 ORM="prisma"
 MIGRATION_CMD="npx prisma migrate deploy"
elif [ -f "drizzle.config.ts" ]; then
 ORM="drizzle"
 MIGRATION_CMD="npx drizzle-kit migrate"
elif grep -q "typeorm" package.json; then
 ORM="typeorm"
 MIGRATION_CMD="npx typeorm migration:run"
else
 ORM="unknown"
fi

# 3. Check if migrations run at build time or runtime
if grep -q "build-migrate" package.json; then
 MIGRATION_TIME="build"
elif grep -q "MIGRATION_DB" .env.example 2>/dev/null; then
 MIGRATION_TIME="runtime"
 MIGRATION_ENV_VAR="MIGRATION_DB=1"
else
 MIGRATION_TIME="none" # CRITICAL WARNING
fi

# 4. Check for Next.js Standalone mode + ORM combination
if grep -q "output.*standalone" next.config.* 2>/dev/null && [ "$ORM" != "unknown" ]; then
 # CRITICAL: Standalone mode doesn't include all node_modules
 # ORM dependencies must be installed separately
 STANDALONE_WITH_ORM=true
fi
```

**Output**:
```yaml
migration_system:
 detected: true
 orm: "drizzle"            # prisma | drizzle | typeorm | unknown
 migration_dir: "packages/database/migrations"
 migration_count: 76
 migration_files:
  - "0000_init.sql"
  - "0049_better_auth.sql"
  - "...76 files total"

 execution_timing: "runtime"      # build | runtime | none
 execution_command: "npx drizzle-kit migrate"
 execution_env_var: "MIGRATION_DB=1"

 # Critical pattern detection
 standalone_with_orm: true
 requires_separate_deps: true     # If true, must install ORM separately

 warnings:
  - "Next.js standalone mode + ORM detected - ORM must be installed separately"
  - "76 migration files found - ensure they run before first request"
  - "No automatic migration detected - must add runtime migration"
```

**Warning Conditions**:
- `migration_count > 0` AND `migration_time == "none"` → **CRITICAL: Migrations will never run**
- `standalone_with_orm == true` AND `requires_separate_deps == false` → **Migrations will fail silently**
- `orm == "unknown"` AND `migration_count > 0` → **Cannot determine migration method**

### Step 13: Analyze Build Script Complexity

**Purpose**: Detect memory-intensive or unnecessary build steps to prevent OOM failures.

**Detection Method**:
```bash
# 1. Parse build script from package.json
BUILD_SCRIPT=$(jq -r '.scripts.build' package.json)

# 2. Check for heavy operations
HEAVY_OPS=()

if echo "$BUILD_SCRIPT" | grep -qE "lint|eslint"; then
 HEAVY_OPS+=("lint")
fi

if echo "$BUILD_SCRIPT" | grep -qE "type-check|tsc.*--noEmit"; then
 HEAVY_OPS+=("type-check")
fi

if echo "$BUILD_SCRIPT" | grep -qE "test|jest|vitest"; then
 HEAVY_OPS+=("test")
fi

if echo "$BUILD_SCRIPT" | grep -qE "sitemap|buildSitemap"; then
 HEAVY_OPS+=("sitemap")
fi

# 3. Check workspace package count (memory multiplier)
if [ -f "pnpm-workspace.yaml" ]; then
 WORKSPACE_COUNT=$(grep -E "^\s*-\s+" pnpm-workspace.yaml | wc -l)
 if [ "$WORKSPACE_COUNT" -gt 20 ]; then
  MEMORY_RISK="high"
 elif [ "$WORKSPACE_COUNT" -gt 10 ]; then
  MEMORY_RISK="medium"
 fi
fi
```

**Output**:
```yaml
build_complexity:
 build_script: "npm run prebuild && next build"
 heavy_operations:
  - name: "lint"
   location: "prebuild"
   essential: false
   memory_usage: "2-4GB"
   recommendation: "Skip in Docker build (run in CI)"
  - name: "type-check"
   location: "prebuild"
   essential: false
   memory_usage: "4-8GB"
   recommendation: "Skip in Docker build (run in CI)"
  - name: "sitemap"
   location: "build"
   essential: false
   memory_usage: "500MB"
   recommendation: "Skip in Docker (not needed for container)"

 workspace_package_count: 39
 memory_risk: "high"          # low | medium | high

 recommendations:
  optimized_build: "npx tsx scripts/prebuild.mts && npx next build --webpack"
  memory_limit: "NODE_OPTIONS=--max-old-space-size=8192"
  rationale: "Skip lint/type-check/sitemap to reduce memory from 12GB+ to 4GB"
```

### Step 14: Determine Complexity Level

**L1 (Simple)**:
- Single language
- No build step OR simple build (just `npm install`)
- No external service dependencies
- No workspace
- No migrations
- Examples: Express API, simple Python script

**L2 (Medium)**:
- Has build step (Next.js, TypeScript compilation, etc.)
- Has external services (Database, Redis)
- May have environment variable requirements at build time
- Simple migration system
- Examples: Next.js app, Django with PostgreSQL

**L3 (Complex)**:
- Monorepo structure (pnpm-workspace, turborepo, nx)
- Multi-language (Python backend + Node frontend)
- Complex build pipeline
- Many external dependencies
- Has build-time env var requirements
- Custom entry points / server launchers
- Complex migration system (76+ migrations, ORM dependencies)
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
  lockfile_disabled: true      # lockfile=false in .npmrc
  config_file: ".npmrc"
  install_command: "pnpm install"  # NOT --frozen-lockfile if lockfile disabled

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
  required_copy_files:       # Files MUST be copied for workspace
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
  command: "npm run build:docker"  # Prefer docker-specific script
  fallback_command: "npm run build"
  output_dir: ".next"
  standalone_mode: true       # output: 'standalone' in next.config
  env_required:           # Build-time required env vars
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
  - ".npmrc"            # Package manager config
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

 # Database migration system
 migration_system:
  detected: true
  orm: "drizzle"
  migration_dir: "packages/database/migrations"
  migration_count: 76
  execution_timing: "runtime"
  execution_env_var: "MIGRATION_DB=1"
  standalone_with_orm: true
  requires_separate_deps: true
  warnings:
   - "Next.js standalone mode + Drizzle ORM - must install drizzle-orm separately"
   - "76 migration files - ensure runtime execution before first request"

 # Build complexity analysis
 build_complexity:
  build_script: "npm run prebuild && next build"
  heavy_operations:
   - name: "lint"
    essential: false
    recommendation: "Skip in Docker (run in CI)"
   - name: "type-check"
    essential: false
    recommendation: "Skip in Docker (run in CI)"
  workspace_package_count: 39
  memory_risk: "high"
  optimized_build: "npx tsx scripts/prebuild.mts && npx next build --webpack"
  memory_limit: "NODE_OPTIONS=--max-old-space-size=8192"

 # Complexity assessment
 complexity: "L3"
 max_iterations: 5

 # Warnings / Notes
 warnings:
  - "Project uses lockfile=false - cannot use --frozen-lockfile"
  - "Workspace packages must be copied individually for Docker cache optimization"
  - "Build requires placeholder env vars for Next.js static generation"
  - "CRITICAL: Migration system detected - must handle ORM dependencies separately"
  - "Build script includes heavy operations - optimize to prevent OOM"
```
