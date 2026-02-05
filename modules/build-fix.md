# Module: Build Validation & Fix

## Purpose

Execute docker build, capture errors, and automatically fix Dockerfile issues through iterative refinement.

## Execution Flow

```
┌─────────────────────┐
│   docker build      │
└──────────┬──────────┘
           │
    ┌──────┴──────┐
    │             │
  SUCCESS       FAILURE
    │             │
    ▼             ▼
  OUTPUT     ┌─────────────┐
  FINAL      │ Parse Error │
  FILES      └──────┬──────┘
                    │
                    ▼
             ┌─────────────┐
             │ Match Pattern│
             └──────┬──────┘
                    │
                    ▼
             ┌─────────────┐
             │ Apply Fix   │
             └──────┬──────┘
                    │
                    ▼
             ┌─────────────┐
             │ iteration++ │
             │ < max?      │
             └──────┬──────┘
                    │
           ┌───────┴───────┐
           │               │
          YES              NO
           │               │
           ▼               ▼
        RETRY          OUTPUT BEST
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
            break  # One fix per iteration
    else:
        # No matching pattern found
        return FAIL_WITH_LOG

return PARTIAL_SUCCESS  # Max iterations reached
```

## Output on Success

```
## Build Results

✅ Build successful!

### Generated Files
- Dockerfile
- .dockerignore
- docker-compose.yml

### Build Command
docker build -t your-app:latest .

### Run Command
docker run -d -p 3000:3000 your-app:latest

### Image Size
~250MB
```

## Output on Failure

```
## Build Results

⚠️ Build completed with issues after 3 iterations.

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
