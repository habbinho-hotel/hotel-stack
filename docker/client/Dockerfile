# syntax=docker/dockerfile:1

# ---- build: habbinho-client já reúne Octane e Octane-Renderer; mantemos ambas como irmãs ----
FROM node:22-bookworm-slim AS build
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
    YARN_ENABLE_TELEMETRY=0 \
    NODE_OPTIONS=--max-old-space-size=4096
RUN corepack enable
WORKDIR /src
COPY habbinho-client/Octane-Renderer/ ./Octane-Renderer/
COPY habbinho-client/Octane/ ./Octane/
RUN cd Octane-Renderer && yarn install
RUN cd Octane && yarn install && yarn build

# ---- runtime: nginx servindo dist/ e, por volume, /gamedata ----
FROM nginx:stable-alpine
COPY --from=build /src/Octane/dist /usr/share/nginx/html
COPY docker/client/nginx.conf /etc/nginx/conf.d/default.conf
# Scripts em /docker-entrypoint.d rodam antes do nginx subir (imagem oficial)
COPY --chmod=755 docker/client/entrypoint.sh /docker-entrypoint.d/40-octane-config.sh
