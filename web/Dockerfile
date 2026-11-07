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
# Uygulama baglantisi dogrulama dosyalari (.well-known/apple-app-site-association, assetlinks.json; paylasim baglantisi /s/*).
# Degerler (docker compose build.args <- .env.prod APPLE_TEAM_ID, PLAY_APP_SIGNING_SHA256) bos/gecersizse dosya URETILMEZ
# (nginx yalin 404 verir), derleme basarisiz OLMAZ. Ayrinti: docs/SHARING.md. Bu katman `npm run build`den SONRA: degerler degisince yalniz o yeniden calisir.
ARG APPLE_TEAM_ID=
ARG PLAY_APP_SIGNING_SHA256=
RUN APPLE_TEAM_ID="$APPLE_TEAM_ID" PLAY_APP_SIGNING_SHA256="$PLAY_APP_SIGNING_SHA256" node scripts/gen-app-links.mjs

# Aşama 2: statik sunum + ters vekil
FROM nginx:1.31.7-alpine@sha256:892bb2152464f0c5d8972593a5f5afaf8054552580b699d95f8ff4af08c2d33d
RUN rm -f /etc/nginx/conf.d/default.conf && mkdir -p /etc/nginx/snippets
COPY nginx-security.conf /etc/nginx/snippets/security.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
# Yonetim konumu parcasi derlemede uretilir (VITE_ADMIN_PATH'e gore, scripts/prerender.mjs); html kokunden tasinir.
# Dosya yoksa tasima basarisiz olur ve imaj derlenmez (nginx.conf bu parcayi include eder: fail-closed).
RUN mv /usr/share/nginx/html/_nginx-generated.conf /etc/nginx/snippets/generated-locations.conf
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1
