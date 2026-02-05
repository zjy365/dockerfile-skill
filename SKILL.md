# Dockerfile Generator Skill

---
name: dockerfile
description: Generate production-ready Dockerfile for any GitHub project. Use when user wants to containerize a project, create Docker configuration, or deploy to cloud.
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
---

## Overview

This skill generates production-ready Dockerfiles through a 3-phase process:
1. **Analyze** - Understand the project structure and requirements
2. **Generate** - Create Dockerfile and supporting files
3. **Build & Fix** - Validate through actual build, fix errors iteratively

## Usage

```
/dockerfile                    # Analyze current directory
/dockerfile <github-url>       # Clone and analyze GitHub repo
/dockerfile <path>             # Analyze specific path
```

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
| L3 | Monorepo, multi-language, complex dependencies | 5 |

## Success Criteria

A successful Dockerfile must:
1. Build without errors (`docker build` exits 0)
2. Follow production best practices (multi-stage, non-root, fixed versions)
3. Include all necessary supporting files
