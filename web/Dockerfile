# Aşama 1: derleme
# T-148 (A8-11): taban imajlar ozetle (sha256) sabitlidir (bkz. backend/Dockerfile).
FROM node:22-alpine@sha256:fe4f6d74e20370acb04ad889077d14d0f64a9c8ea6a42bc60cddf1e844699914 AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY . .
# Üretimde API aynı kökenden nginx proxy'si ile sunulur
ENV VITE_API_BASE=/api
# Herkese acik kok adres: canonical, hreflang, sitemap, robots, OG (scripts/prerender.mjs). Bos birakilirsa https://bukampus.com.tr
ARG PUBLIC_WEB_URL=
ENV PUBLIC_WEB_URL=$PUBLIC_WEB_URL
ENV VITE_PUBLIC_URL=$PUBLIC_WEB_URL
# Gizli yonetim yolu (docker-compose build.args <- ADMIN_PATH); bos = /admin. Guvenlik onlemi degil, bkz. web/src/adminBase.ts
ARG VITE_ADMIN_PATH=
ENV VITE_ADMIN_PATH=$VITE_ADMIN_PATH
RUN npm run build

# Aşama 2: statik sunum + ters vekil
FROM nginx:1.27.5-alpine@sha256:65645c7bb6a0661892a8b03b89d0743208a18dd2f3f17a54ef4b76fb8e2f2a10
RUN rm -f /etc/nginx/conf.d/default.conf && mkdir -p /etc/nginx/snippets
COPY nginx-security.conf /etc/nginx/snippets/security.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
