# syntax=docker/dockerfile:1.7

# =====================================================================
# Stage 1 — builder: minify + precompress the site into dist/
# Conservative: only whitespace/comment stripping, JS/CSS untouched.
# =====================================================================
FROM node:26-alpine AS builder
RUN apk add --no-cache brotli bash && rm -rf /var/cache/apk/*
WORKDIR /src
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY index.html ./
COPY scripts/build.sh scripts/build.sh
RUN MINIFY=1 npm run build

# =====================================================================
# Stage 2 — runtime: Caddy (auto-HTTPS, gzip, security headers)
# Official image runs as non-root `caddy` user.
# =====================================================================
FROM caddy:2-alpine

LABEL org.opencontainers.image.title="munchi-birthday-letter" \
      org.opencontainers.image.description="Static birthday letter site served by Caddy" \
      org.opencontainers.image.source="https://github.com/PavaraM/Munchi-s-Birthday-Letter"

COPY docker/Caddyfile /etc/caddy/Caddyfile
COPY --from=builder /src/dist/ /srv/

EXPOSE 80 443
VOLUME ["/data", "/config"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
