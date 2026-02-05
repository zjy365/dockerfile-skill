# syntax=docker/dockerfile:1.4

# ============================================
# Stage 1: Dependencies
# ============================================
FROM node:20.11.1-slim AS deps

WORKDIR /app

# Install system dependencies for native modules (if needed)
# {{SYSTEM_DEPS}}

# Copy package files
COPY package.json package-lock.json* yarn.lock* pnpm-lock.yaml* ./

# Install dependencies
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# ============================================
# Stage 2: Build
# ============================================
FROM deps AS build

WORKDIR /app

# Copy source code
COPY . .

# Set build-time environment variables
# These are placeholders for SSG/ISR builds
ARG NEXT_PUBLIC_API_URL=http://localhost:3000
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

# Disable telemetry during build
ENV NEXT_TELEMETRY_DISABLED=1

# Build Next.js application
RUN npm run build

# ============================================
# Stage 3: Runtime
# ============================================
FROM node:20.11.1-slim AS runtime

WORKDIR /app

# Set production environment
ENV NODE_ENV=production
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"
ENV NEXT_TELEMETRY_DISABLED=1

# Create non-root user
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

# ============================================
# Option A: Standalone mode (recommended)
# Requires: output: 'standalone' in next.config.js
# ============================================
COPY --from=build /app/public ./public
COPY --from=build --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=build --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD node -e "require('http').get('http://127.0.0.1:3000/api/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

CMD ["node", "server.js"]

# ============================================
# Option B: Non-standalone mode
# Use if standalone is not configured
# ============================================
# COPY --from=build /app/.next ./.next
# COPY --from=build /app/public ./public
# COPY --from=build /app/node_modules ./node_modules
# COPY --from=build /app/package.json ./package.json
#
# USER nextjs
#
# EXPOSE 3000
#
# CMD ["npm", "start"]
