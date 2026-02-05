# Error Pattern Knowledge Base

## Pattern Format

Each pattern includes:
- **regex**: Pattern to match in error output
- **category**: Error classification
- **fix**: Dockerfile modification to apply
- **confidence**: How reliably this fix works (high/medium/low)

---

## Category: File System

### ENOENT - File Not Found

```yaml
pattern: "ENOENT.*no such file or directory.*['\"](.+?)['\"]"
category: filesystem
confidence: high
extract: path from capture group 1
fix: |
  # Before the failing RUN command, add:
  RUN mkdir -p $(dirname {path}) && touch {path}
  # Or for JSON config:
  RUN mkdir -p $(dirname {path}) && echo '{}' > {path}
```

### ENOENT - Module Not Found

```yaml
pattern: "Cannot find module ['\"](.+?)['\"]"
category: filesystem
confidence: medium
extract: module name
fix: |
  # Check if it's a local file that wasn't copied
  # Add to COPY if needed:
  COPY {module_path} ./
```

### Directory Not Found

```yaml
pattern: "ENOTDIR|directory.*not found|No such file or directory: ['\"](.+?)['\"]"
category: filesystem
confidence: high
fix: |
  RUN mkdir -p {directory}
```

---

## Category: Environment Variables

### Required Env Not Set

```yaml
pattern: "`(.+?)` is not set|(.+?) environment variable is required|process\\.env\\.(.+?) is (not defined|undefined)"
category: environment
confidence: high
extract: variable name
fix: |
  # In build stage:
  ARG {VAR_NAME}=placeholder_for_build
  ENV {VAR_NAME}=${{VAR_NAME}}
```

### KeyError (Python)

```yaml
pattern: "KeyError: ['\"](.+?)['\"]"
category: environment
confidence: medium
extract: key name
fix: |
  # Check if it's an env var access
  ENV {KEY}=placeholder
```

---

## Category: Memory

### JavaScript Heap OOM

```yaml
pattern: "JavaScript heap out of memory|FATAL ERROR.*Allocation failed"
category: memory
confidence: high
fix: |
  ENV NODE_OPTIONS="--max-old-space-size=4096"
  # If already set to 4096, increase to 8192
```

### Process Killed (OOM Killer)

```yaml
pattern: "Killed|Exit code: 137|signal: SIGKILL"
category: memory
confidence: high
fix: |
  # For Node.js:
  ENV NODE_OPTIONS="--max-old-space-size=8192"
  # For general: suggest increasing Docker memory limit
```

---

## Category: Native Modules

### node-gyp Build Failed

```yaml
pattern: "gyp ERR!|node-gyp rebuild|Cannot find module.*node-gyp"
category: native_module
confidence: high
fix: |
  # Add to deps/build stage:
  RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 \
      make \
      g++ \
      && rm -rf /var/lib/apt/lists/*
```

### GCC/G++ Missing

```yaml
pattern: "command 'gcc' failed|g\\+\\+: command not found|cc: not found"
category: native_module
confidence: high
fix: |
  RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential \
      && rm -rf /var/lib/apt/lists/*
```

### Python distutils Missing

```yaml
pattern: "No module named 'distutils'|ModuleNotFoundError.*distutils"
category: native_module
confidence: high
fix: |
  RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 \
      python3-distutils \
      && rm -rf /var/lib/apt/lists/*
```

---

## Category: Package-Specific

### Sharp / libvips

```yaml
pattern: "sharp|vips|Something went wrong installing the \"sharp\" module"
category: package_specific
confidence: high
fix: |
  # In build stage:
  RUN apt-get update && apt-get install -y --no-install-recommends \
      libvips-dev \
      && rm -rf /var/lib/apt/lists/*
```

### Canvas / Cairo

```yaml
pattern: "canvas|cairo|pango|librsvg"
category: package_specific
confidence: high
fix: |
  RUN apt-get update && apt-get install -y --no-install-recommends \
      libcairo2-dev \
      libpango1.0-dev \
      libjpeg-dev \
      libgif-dev \
      librsvg2-dev \
      && rm -rf /var/lib/apt/lists/*
```

### better-sqlite3

```yaml
pattern: "better-sqlite3|Could not locate the bindings file"
category: package_specific
confidence: high
fix: |
  RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 \
      make \
      g++ \
      && rm -rf /var/lib/apt/lists/*
```

### bcrypt

```yaml
pattern: "bcrypt.*error|node_modules/bcrypt"
category: package_specific
confidence: high
fix: |
  RUN apt-get update && apt-get install -y --no-install-recommends \
      python3 \
      make \
      g++ \
      && rm -rf /var/lib/apt/lists/*
```

---

## Category: Permission

### EACCES Permission Denied

```yaml
pattern: "EACCES.*permission denied|PermissionError.*Errno 13"
category: permission
confidence: medium
fix: |
  # Before USER directive:
  RUN chown -R node:node /app
  # Or adjust the path in question
```

### npm/yarn EACCES

```yaml
pattern: "npm ERR! EACCES|yarn.*EACCES"
category: permission
confidence: high
fix: |
  # Ensure cache directory is writable:
  RUN mkdir -p /home/node/.npm && chown -R node:node /home/node
  USER node
```

---

## Category: Network

### Network Timeout

```yaml
pattern: "ETIMEDOUT|network timeout|request.*timed out"
category: network
confidence: medium
fix: |
  # For npm:
  RUN npm ci --network-timeout 600000
  # For yarn:
  RUN yarn install --network-timeout 600000
```

### Host Resolution Failed

```yaml
pattern: "ENOTFOUND|getaddrinfo.*failed|Could not resolve host"
category: network
confidence: low
fix: |
  # Usually a transient issue, retry may help
  # Or add DNS configuration if persistent
```

---

## Category: Shell Syntax

### Shell Syntax Error

```yaml
pattern: "/bin/sh.*syntax error|unexpected (EOF|token)"
category: shell
confidence: high
fix: |
  # Review RUN commands for:
  # - Unescaped special characters ($, ", ', `)
  # - Unclosed quotes
  # - Complex command substitution
  # Use heredoc for multi-line:
  RUN <<EOF
  command1
  command2
  EOF
```

### Escape Character Issues

```yaml
pattern: "command not found:|unexpected.*\\$"
category: shell
confidence: medium
fix: |
  # Check for proper escaping:
  # $VAR → \$VAR (if literal)
  # Or use single quotes
```

---

## Category: Lockfile

### Lockfile Mismatch

```yaml
pattern: "npm ci.*This command requires an existing lockfile|Your lock file needs to be updated"
category: lockfile
confidence: high
fix: |
  # Change from npm ci to npm install:
  RUN npm install
  # Or for pnpm:
  RUN pnpm install  # Instead of --frozen-lockfile
```

### Missing Lockfile

```yaml
pattern: "npm ci.*ENOENT.*package-lock.json|pnpm.*ERR_PNPM_NO_LOCKFILE"
category: lockfile
confidence: high
fix: |
  # Fallback to non-frozen install:
  RUN npm install
  # Or:
  RUN pnpm install
```

### Lockfile Disabled in Config

```yaml
pattern: "lockfile is set to false|Cannot generate.*lockfile.*because lockfile is set to false"
category: lockfile
confidence: high
fix: |
  # Project has lockfile=false in .npmrc
  # Do NOT use --frozen-lockfile
  RUN pnpm install --ignore-scripts
  # Instead of:
  # RUN pnpm install --frozen-lockfile
```

---

---

## Category: Workspace / Monorepo

### Workspace Package Not Found

```yaml
pattern: "ENOENT.*workspace.*package.json|pnpm.*ERR_PNPM_NO_IMPORTER"
category: workspace
confidence: high
fix: |
  # Ensure all workspace package.json files are copied
  COPY packages ./packages
  COPY e2e/package.json ./e2e/
  COPY apps/desktop/src/main/package.json ./apps/desktop/src/main/
```

### Patches Directory Missing

```yaml
pattern: "ENOENT.*patches/|Could not apply patch"
category: workspace
confidence: high
fix: |
  # pnpm patches require patches directory
  COPY patches ./patches
```

### .dockerignore Excludes Required Files

```yaml
pattern: "COPY failed.*not found|failed to calculate checksum.*not found"
category: workspace
confidence: high
fix: |
  # Check .dockerignore - likely excluding required workspace files
  # Use specific exclusions instead of directory-level:
  # Bad:  e2e
  # Good: e2e/*
  #       !e2e/package.json
```

---

## Category: Node.js Path / Runtime

### Node Binary Not Found

```yaml
pattern: "spawn /bin/node ENOENT|spawn node ENOENT|/bin/node.*not found"
category: runtime_path
confidence: high
fix: |
  # node:slim images have node at /usr/local/bin/node, not /bin/node
  # Some scripts hardcode /bin/node
  RUN ln -sf /usr/local/bin/node /bin/node
```

### Proxychains Not Found

```yaml
pattern: "/bin/proxychains.*not found|proxychains.*ENOENT"
category: runtime_deps
confidence: high
fix: |
  RUN apt-get update && apt-get install -y --no-install-recommends \
      proxychains4 \
      && rm -rf /var/lib/apt/lists/*
```

---

## Category: Build-Time Environment

### Build-Time Env Required (Next.js SSG)

```yaml
pattern: "`(.+?)` is not set.*build|Failed to collect page data.*(.+?) is not set"
category: build_env
confidence: high
extract: variable name from capture group
fix: |
  # Next.js SSG/ISR requires env vars at build time
  # Add placeholder values for build stage:
  ARG {VAR_NAME}_PLACEHOLDER="build-placeholder-value"
  ENV {VAR_NAME}=${{{VAR_NAME}_PLACEHOLDER}}
```

### Next.js API Route SDK Initialization (Resend, Stripe, etc.)

```yaml
pattern: "Missing API key.*Pass it to the constructor|error:.*API key|Failed to collect page data for /api/"
category: build_env
confidence: high
description: |
  Next.js statically analyzes API routes during build time and attempts to load modules,
  even if the code only runs at runtime. If an SDK is initialized at module top-level
  (e.g., `const resend = new Resend(process.env.KEY)`), the build will fail due to
  missing API key.
fix: |
  # Add placeholder values in build stage (these won't be used at runtime)
  ARG RESEND_API_KEY=re_placeholder_key
  ARG STRIPE_SECRET_KEY=sk_placeholder_key
  ARG NOTION_SECRET=placeholder_notion_secret
  # ... add corresponding variables based on error message

  ENV RESEND_API_KEY=${RESEND_API_KEY}
  ENV STRIPE_SECRET_KEY=${STRIPE_SECRET_KEY}
  ENV NOTION_SECRET=${NOTION_SECRET}
detection: |
  # Scan app/api/**/route.ts to detect required env vars:
  grep -r "new.*process\.env\." app/api/
  grep -r "process\.env\.\w\+" app/api/ | grep -v "process.env.NODE_ENV"
```

### Database URL Required at Build Time

```yaml
pattern: "DATABASE_URL.*is not set|You are try to use database.*DATABASE_URL"
category: build_env
confidence: high
fix: |
  # Some pages need DB access during build for static generation
  ARG DATABASE_URL_PLACEHOLDER="postgres://placeholder:placeholder@localhost:5432/placeholder"
  ENV DATABASE_URL=${DATABASE_URL_PLACEHOLDER}
  ENV DATABASE_DRIVER=""
```

### Auth Secret Required at Build Time

```yaml
pattern: "AUTH_SECRET.*is not set|KEY_VAULTS_SECRET.*is not set"
category: build_env
confidence: high
fix: |
  ARG KEY_VAULTS_SECRET_PLACEHOLDER="build-placeholder-key-vaults-secret-32chars"
  ENV KEY_VAULTS_SECRET=${KEY_VAULTS_SECRET_PLACEHOLDER}
  ENV AUTH_SECRET=${KEY_VAULTS_SECRET_PLACEHOLDER}
```

---

## Category: Script/Entry Point

### Build Script Missing

```yaml
pattern: "Cannot find module.*prebuild|ERR_MODULE_NOT_FOUND.*scripts/"
category: script_missing
confidence: high
fix: |
  # Build script excluded by .dockerignore
  # Remove from .dockerignore or ensure COPY includes it
  # Check if script path is in .dockerignore exclusions
```

### Server Entry Point Not Found

```yaml
pattern: "Cannot find module.*startServer|Cannot find module.*server.js"
category: script_missing
confidence: high
fix: |
  # Copy server entry point in production stage
  COPY --from=builder /app/scripts/serverLauncher/startServer.js ./startServer.js
  COPY --from=builder /app/scripts/_shared ./scripts/_shared
```

---

## Unknown Error Fallback

If no pattern matches:

1. Log the full error message
2. Check if error contains a file path → might be COPY issue or .dockerignore issue
3. Check if error contains package name → might be dependency issue
4. Check if error mentions env var → might need build-time placeholder
5. Check if error mentions workspace → might be missing workspace files
6. Return to user with error for manual review

### Debugging Checklist

When build fails with unknown error:

1. **File not found**: Check .dockerignore, ensure file is not excluded
2. **Module not found**: Check if it's a workspace package that wasn't copied
3. **Env var not set**: Add ARG/ENV placeholder for build time
4. **Permission denied**: Check USER directive placement
5. **Command not found**: Check if binary exists in the image (node path, proxychains, etc.)
