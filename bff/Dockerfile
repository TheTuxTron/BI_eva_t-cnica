# syntax=docker/dockerfile:1
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev --no-audit --no-fund

FROM node:22-alpine
ENV NODE_ENV=production PORT=8080 DB_PATH=/data/kinti.db
WORKDIR /app
RUN addgroup -S kinti && adduser -S kinti -G kinti && mkdir -p /data && chown kinti:kinti /data
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
COPY public ./public
USER kinti
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=3s --retries=3 CMD wget -qO- http://localhost:8080/health/live || exit 1
CMD ["node", "--no-warnings=ExperimentalWarning", "src/server.js"]
