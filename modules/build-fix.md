# Module: Build Validation & Fix

## Purpose

Execute docker build, capture errors, and automatically fix Dockerfile issues through iterative refinement.

## Execution Flow

```
┌─────────────────────┐
│  docker build   │
└──────────┬──────────┘
      │
  ┌──────┴──────┐
  │       │
 SUCCESS    FAILURE
  │       │
  ▼       ▼
 OUTPUT   ┌─────────────┐
 FINAL   │ Parse Error │
 FILES   └──────┬──────┘
          │
          ▼
       ┌─────────────┐
       │ Match Pattern│
       └──────┬──────┘
          │
          ▼
       ┌─────────────┐
       │ Apply Fix  │
       └──────┬──────┘
          │
          ▼
       ┌─────────────┐
       │ iteration++ │
       │ < max?   │
       └──────┬──────┘
          │
      ┌───────┴───────┐
      │        │
     YES       NO
      │        │
      ▼        ▼
    RETRY     OUTPUT BEST
            + WARN USER
```

## Build Command

```bash
DOCKER_BUILDKIT=1 docker build -t test-build:latest . 2>&1
```

**Important**: Capture both stdout and stderr for error analysis.

## Error Pattern Matching

See [knowledge/error-patterns.md](../knowledge/error-patterns.md) for the full pattern database.

### Priority 1: File/Directory Not Found

**Pattern**:
```
ENOENT: no such file or directory, open '...'
Error: Cannot find module '...'
FileNotFoundError: [Errno 2] No such file or directory: '...'
```

**Fix Actions**:
1. Extract the missing path from error message
2. If it's a config file (*.json, *.yaml, *.toml):
  ```dockerfile
  RUN mkdir -p /app/data && echo '{}' > /app/data/config.json
  ```
3. If it's a directory:
  ```dockerfile
  RUN mkdir -p /app/missing-dir
  ```

### Priority 2: Environment Variable Missing

**Pattern**:
```
`XXX` is not set
Error: XXX environment variable is required
KeyError: 'XXX'
```

**Fix Actions**:
1. Extract variable name
2. Add to build stage with placeholder:
  ```dockerfile
  ARG XXX=placeholder_for_build
  ENV XXX=$XXX
  ```

### Priority 3: Out of Memory

**Pattern**:
```
Killed
Exit code: 137
JavaScript heap out of memory
FATAL ERROR: CALL_AND_RETRY_LAST Allocation failed
```

**Fix Actions**:
1. Add memory options:
  ```dockerfile
  ENV NODE_OPTIONS="--max-old-space-size=4096"
  ```
2. If still failing, increase to 8192

### Priority 4: Native Module Build Failed

**Pattern**:
```
gyp ERR!
node-gyp rebuild
error: command 'gcc' failed
ModuleNotFoundError: No module named 'distutils'
```

**Fix Actions**:
1. Add build tools to deps stage:
  ```dockerfile
  RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*
  ```

### Priority 5: Package-Specific Errors

**Pattern**: `sharp`, `vips`, `canvas` related errors

**Fix Actions**:
```dockerfile
# For sharp
RUN apt-get update && apt-get install -y --no-install-recommends \
  libvips-dev \
  && rm -rf /var/lib/apt/lists/*

# For canvas
RUN apt-get update && apt-get install -y --no-install-recommends \
  libcairo2-dev \
  libpango1.0-dev \
  libjpeg-dev \
  libgif-dev \
  librsvg2-dev \
  && rm -rf /var/lib/apt/lists/*
```

### Priority 6: Permission Denied

**Pattern**:
```
EACCES: permission denied
PermissionError: [Errno 13]
```

**Fix Actions**:
1. Check if file operations happen before USER switch
2. Add ownership change:
  ```dockerfile
  RUN chown -R node:node /app
  USER node
  ```

### Priority 7: Network/Download Errors

**Pattern**:
```
ETIMEDOUT
ECONNREFUSED
npm ERR! network
Could not resolve host
```

**Fix Actions**:
1. Add retry logic or timeout increase:
  ```dockerfile
  RUN npm ci --network-timeout 600000
  ```
2. Consider adding mirror/proxy if consistently failing

### Priority 8: Shell Syntax Error

**Pattern**:
```
/bin/sh: syntax error
unexpected EOF
```

**Fix Actions**:
1. Check for unescaped special characters
2. Avoid complex shell substitutions in RUN
3. Use heredoc syntax for multi-line scripts:
  ```dockerfile
  RUN <<EOF
  set -e
  echo "line 1"
  echo "line 2"
  EOF
  ```

## Iteration Control

```python
max_iterations = {
  "L1": 1,
  "L2": 3,
  "L3": 5
}

for i in range(max_iterations[complexity]):
  result = docker_build()
  if result.success:
    return SUCCESS

  errors = parse_errors(result.stderr)
  if not errors:
    # Unknown error, cannot auto-fix
    return FAIL_WITH_LOG

  for error in errors:
    fix = match_pattern(error)
    if fix:
      apply_fix(dockerfile, fix)
      break # One fix per iteration
  else:
    # No matching pattern found
    return FAIL_WITH_LOG

return PARTIAL_SUCCESS # Max iterations reached
```

## Post-Build Validation

After successful build, perform comprehensive validation:

### Step 1: Container Startup Validation

```bash
# Start container with docker-compose
docker-compose up -d

# Wait for startup (adjust based on app)
sleep 30

# Check container status
docker-compose ps
```

### Step 2: Database Migration Validation

If `migration_system.detected == true` from analysis:

```bash
# Verify database tables exist
docker-compose exec postgres psql -U <user> -d <db> -c "\dt"

# Expected output: List of tables (users, sessions, messages, etc.)
# If "Did not find any relations" → MIGRATIONS FAILED

# Check migration status table
docker-compose exec postgres psql -U <user> -d <db> -c "SELECT * FROM drizzle_migrations LIMIT 5;"

# Verify migration count
MIGRATION_COUNT=$(docker-compose exec postgres psql -U <user> -d <db> -t -c "SELECT COUNT(*) FROM drizzle_migrations;")
EXPECTED_COUNT=76 # From analysis phase

if [ "$MIGRATION_COUNT" -ne "$EXPECTED_COUNT" ]; then
 echo "CRITICAL: Only $MIGRATION_COUNT of $EXPECTED_COUNT migrations ran"
fi
```

### Step 3: Application Health Validation

```bash
# Test HTTP response
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3210)

# Acceptable codes: 200 (OK), 302 (Redirect to login), 401 (Auth required)
# Unacceptable: 500 (Internal error), 502 (Bad gateway)

if [ "$HTTP_CODE" = "500" ]; then
 echo "CRITICAL: Application returning 500 error"
 docker-compose logs app
fi

# Test specific API endpoint
curl -v http://localhost:3210/api/health
```

### Step 4: Log Analysis

```bash
# Check for common error patterns
docker-compose logs app | grep -E "error|Error|ERROR|failed|Failed|FAILED" | tail -20

# Check for migration-related errors
docker-compose logs app | grep -E "migration|migrate|schema|relation.*does not exist"

# Check for database connection
docker-compose logs app | grep -E "database|postgres|connection"
```

### Validation Checklist

Before declaring success:

**Build Phase**:
- [ ] Image builds successfully (`docker build` exits 0)
- [ ] Image size reasonable (< 2GB for most apps)

**Startup Phase**:
- [ ] Container starts without crash
- [ ] All ports accessible
- [ ] Database connection successful

**Migration Phase** - CRITICAL:
- [ ] Database tables exist (verify with `\dt`)
- [ ] Migration count matches expected (e.g., 76/76)
- [ ] Migration status table populated
- [ ] No "relation does not exist" errors

**Runtime Phase** :
- [ ] App returns 200/302/401, not 500
- [ ] Health check endpoint works
- [ ] Core API endpoint accessible
- [ ] No runtime errors in logs

**Failure Conditions** → Don't declare success if:
- Database tables missing
- App returns 500 errors
- Logs show "relation does not exist"
- Migration count mismatch
- Container crashes on startup

## Output on Success

```
## Build Results

Build successful!
Container started successfully!
Database migrations completed (76/76)
Application health check passed

### Generated Files
- Dockerfile
- .dockerignore
- docker-compose.yml
- .env.docker.local (auto-generated with test secrets)
- docker-entrypoint.sh
- DOCKER.md (deployment guide)

### Validation Results
- Image size: ~1.4GB
- Container status: UP (healthy)
- Database tables: 23 tables created
- HTTP response: 302 (redirecting to /signin)
- Migrations: 76/76 completed

### Quick Start
cd /path/to/project
docker-compose up -d

# Access application
open http://localhost:3210

### Build Command
docker build -t your-app:latest .

### Run Command
docker run -d -p 3000:3000 your-app:latest

### Next Steps
1. Application is ready to use
2. Set real API keys in .env.docker.local for production
3. Review DOCKER.md for production deployment guide
```

## Output on Failure

```
## Build Results

Build completed with issues after 3 iterations.

### Last Error
[error message]

### Attempted Fixes
1. Added missing directory /app/data
2. Injected environment variable XXX
3. Added memory limit increase

### Manual Steps Required
- Review the error above
- The generated Dockerfile may need manual adjustment for: [specific issue]

### Partial Output
The best version of Dockerfile is saved. It may work with additional configuration.
```
