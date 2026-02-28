# ── Stage 1: Install dependencies ──────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package files
COPY package.json package-lock.json ./

# Install production dependencies only
RUN npm ci --omit=dev

# ── Stage 2: Production image ───────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

# Install dumb-init for proper signal handling (graceful shutdown)
RUN apk add --no-cache dumb-init

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S eggova -u 1001

# Copy production node_modules from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy application source
COPY --chown=eggova:nodejs . .

# Remove dev/local-only files
RUN rm -f eggova.sqlite .env startup.log

# Switch to non-root user
USER eggova

# Expose app port
EXPOSE 3000

# Health check — Docker will restart container if backend stops responding
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/health || exit 1

# Start with dumb-init so Node handles SIGTERM properly
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]
