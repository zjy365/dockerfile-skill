# Dockerfile Generator Skill

---
name: dockerfile
description: Generate production-ready Dockerfile for any GitHub project. Use when user wants to containerize a project, create Docker configuration, deploy to cloud, or mentions "docker", "dockerfile", "container", "containerize".
triggers:
  - "write dockerfile"
  - "create dockerfile"
  - "containerize"
  - "docker build"
  - "deploy to docker"
  - "需要 dockerfile"
  - "写 dockerfile"
allowed-tools: Read, Glob, Grep, Bash, Write, Edit, WebFetch, mcp__deepwiki__ask_question
---

## Overview

This skill generates production-ready Dockerfiles through a 3-phase process:
1. **Analyze** - Understand the project structure, workspace, and requirements
2. **Generate** - Create Dockerfile and supporting files
3. **Build & Fix** - Validate through actual build, fix errors iteratively

## Key Capabilities

- **Workspace/Monorepo Support**: pnpm workspace, Turborepo, npm workspaces
- **Build-Time Env Vars**: Auto-detect and add placeholders for Next.js SSG
- **Error Pattern Database**: 30+ known error patterns with automatic fixes
- **Smart .dockerignore**: Avoid excluding workspace-required files
- **Custom Entry Points**: Support for custom server launchers

## Usage

```
/dockerfile                    # Analyze current directory
/dockerfile <github-url>       # Clone and analyze GitHub repo
/dockerfile <path>             # Analyze specific path
```

## Quick Start

When invoked, ALWAYS follow this sequence:

1. Read and execute [modules/analyze.md](modules/analyze.md)
2. Read and execute [modules/generate.md](modules/generate.md)
3. Read and execute [modules/build-fix.md](modules/build-fix.md)

## Workflow

### Phase 1: Project Analysis

Load and execute: [modules/analyze.md](modules/analyze.md)

**Output**: Structured project metadata including:
- Language / Framework / Package manager
- Build commands / Run commands / Port
- External dependencies (DB/Redis/S3)
- System library requirements
- Complexity level (L1/L2/L3)

### Phase 2: Generate Dockerfile

Load and execute: [modules/generate.md](modules/generate.md)

**Input**: Analysis result from Phase 1
**Output**:
- `Dockerfile`
- `.dockerignore`
- `docker-compose.yml` (if external services needed)
- Environment variable documentation

### Phase 3: Build Validation (Closed Loop)

Load and execute: [modules/build-fix.md](modules/build-fix.md)

**Process**:
1. Execute `docker build`
2. If success → Output final artifacts
3. If failure → Parse error, match pattern, fix Dockerfile, retry
4. Max iterations based on complexity level

## Supporting Resources

- **Templates**: [templates/](templates/) - Base Dockerfile templates by tech stack
- **Error Patterns**: [knowledge/error-patterns.md](knowledge/error-patterns.md) - Known errors and fixes
- **System Dependencies**: [knowledge/system-deps.md](knowledge/system-deps.md) - NPM/Pip package → system library mapping
- **Best Practices**: [knowledge/best-practices.md](knowledge/best-practices.md) - Docker production best practices
- **Output Format**: [examples/output-format.md](examples/output-format.md) - Expected output structure

## Complexity Levels

| Level | Criteria | Max Build Iterations |
|-------|----------|---------------------|
| L1 | Single language, no build step, no external services | 1 |
| L2 | Has build step, has external services (DB/Redis) | 3 |
| L3 | Monorepo, multi-language, complex dependencies, build-time env vars | 5 |

## Common Issues & Solutions

### 1. Workspace files not found
**Symptom**: `ENOENT: no such file or directory, open '/app/e2e/package.json'`
**Cause**: .dockerignore excludes workspace package.json files
**Fix**: Use `e2e/*` instead of `e2e`, then `!e2e/package.json`

### 2. lockfile=false projects
**Symptom**: `Cannot generate lockfile because lockfile is set to false`
**Cause**: Project has `lockfile=false` in .npmrc
**Fix**: Use `pnpm install` instead of `pnpm install --frozen-lockfile`

### 3. Build-time env vars missing
**Symptom**: `KEY_VAULTS_SECRET is not set`
**Cause**: Next.js SSG needs env vars at build time
**Fix**: Add ARG/ENV placeholders in build stage

### 4. Node binary path
**Symptom**: `spawn /bin/node ENOENT`
**Cause**: Scripts hardcode `/bin/node` but `node:slim` has it at `/usr/local/bin/node`
**Fix**: Add `RUN ln -sf /usr/local/bin/node /bin/node`

## Success Criteria

A successful Dockerfile must:
1. Build without errors (`docker build` exits 0)
2. Container starts successfully (`docker run` doesn't crash)
3. Follow production best practices (multi-stage, non-root, fixed versions)
4. Include all necessary supporting files (.dockerignore, docker-compose.yml)
5. Handle all workspace/monorepo requirements

## Post-Build Validation

After successful build, verify:
```bash
# 1. Check image size
docker images <image-name>

# 2. Test container starts
docker run --rm -d --name test -p 3000:3000 \
  -e DATABASE_URL="postgres://..." \
  -e KEY_VAULTS_SECRET="..." \
  <image-name>

# 3. Check logs
docker logs test

# 4. Test health endpoint
curl http://localhost:3000/api/health

# 5. Cleanup
docker stop test
```
