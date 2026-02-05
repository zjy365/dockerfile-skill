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

---

## Unknown Error Fallback

If no pattern matches:

1. Log the full error message
2. Check if error contains a file path → might be COPY issue
3. Check if error contains package name → might be dependency issue
4. Return to user with error for manual review
