# ── Stage 1: deps ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

# ── Stage 2: builder ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Generate Prisma client (schema only, no real DB needed at build time)
RUN npx prisma generate

ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# ── Stage 3: runner ────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser  --system --uid 1001 nextjs

# Copy only what the production server needs
COPY --from=builder /app/public          ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static    ./.next/static
COPY --from=builder /app/node_modules    ./node_modules
COPY --from=builder /app/prisma          ./prisma
COPY --from=builder /app/prisma.config.ts ./prisma.config.ts
COPY --from=builder /app/package.json    ./package.json

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# /data is where the Fly volume will be mounted
RUN mkdir -p /data && chown nextjs:nodejs /data

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

ENTRYPOINT ["docker-entrypoint.sh"]
