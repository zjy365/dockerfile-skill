# Dockerfile Skill

A Claude Code plugin that generates production-ready Dockerfiles with automatic build validation.

## Install

### Option 1: Plugin Add (Recommended)

```bash
/plugin add https://github.com/zjy365/dockerfile-skill
```

### Option 2: Git Clone

```bash
# Clone to any location
git clone https://github.com/zjy365/dockerfile-skill.git ~/dockerfile-skill

# Then add as local plugin in Claude Code
/plugin add ~/dockerfile-skill

# Update
cd ~/dockerfile-skill && git pull
```

### Option 3: Quick Install Script

```bash
curl -fsSL "https://raw.githubusercontent.com/zjy365/dockerfile-skill/main/install.sh" | bash
```

## Usage

```bash
/dockerfile-skill:dockerfile                    # Analyze current directory
/dockerfile-skill:dockerfile <github-url>       # Clone and analyze GitHub repo
/dockerfile-skill:dockerfile <path>             # Analyze specific path
```

## Features

- Multi-stage Docker builds with best practices
- Workspace/monorepo support (pnpm, Turborepo, npm)
- Database migration detection and handling
- Build optimization (skip CI tasks, memory management)
- Runtime validation before declaring success
- 35+ error patterns with automatic fixes

## Structure

```
dockerfile-skill/
├── .claude-plugin/
│   └── plugin.json       # Plugin manifest
├── skills/
│   └── dockerfile/
│       ├── SKILL.md      # Skill entry point
│       ├── modules/      # Analyze → Generate → Build workflow
│       ├── templates/    # Dockerfile templates by tech stack
│       └── knowledge/    # Best practices, error patterns
├── install.sh
└── README.md
```

## License

MIT
