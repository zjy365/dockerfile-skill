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

### Step 8: Determine Complexity Level

**L1 (Simple)**:
- Single language
- No build step OR simple build (just `npm install`)
- No external service dependencies
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
- Examples: Dify, Affine, large enterprise apps

## Output Format

```yaml
analysis:
  language: "typescript"
  framework: "nextjs"
  framework_version: "14.x"
  package_manager: "pnpm"

  build:
    command: "pnpm build"
    output_dir: ".next"
    env_required: []          # Env vars REQUIRED at build time

  run:
    command: "node server.js"
    port: 3000
    env_required: []          # Env vars REQUIRED at runtime

  dependencies:
    external_services:
      - type: postgres
        env_var: DATABASE_URL
      - type: redis
        env_var: REDIS_URL
    system_libs:
      - name: sharp
        packages: ["libvips-dev"]

  existing_docker:
    has_dockerfile: true
    has_compose: true
    key_decisions:
      - "Uses multi-stage build"
      - "Has custom entrypoint.sh"

  complexity: "L2"
  max_iterations: 3
```
