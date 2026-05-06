# ─── Stage 1: Build ────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Install ALL dependencies (devDeps needed for react-scripts build)
COPY package*.json ./
RUN npm ci

# Copy source
COPY . .

# Build the app
RUN npm run build

# ─── Stage 2: Production ───────────────────────────────────────────────────────
FROM nginx:1.27-alpine

# Add non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup

# Copy built assets from builder
COPY --from=builder /app/build /usr/share/nginx/html
COPY --from=builder /app/public /usr/share/nginx/html

# Custom nginx config for React SPA
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Fix permissions
RUN chown -R appuser:appgroup /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx        && \
    chown -R appuser:appgroup /var/log/nginx           && \
    touch /var/run/nginx.pid                           && \
    chown appuser:appgroup /var/run/nginx.pid

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000 || exit 1

CMD ["nginx", "-g", "daemon off;"]
