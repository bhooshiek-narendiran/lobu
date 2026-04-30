# Lobu gateway + embedded Owletto server (production bundle).
#
# Before building:
#   git submodule update --init --recursive packages/owletto-web
#
# Build & push (example):
#   docker build -t lobu:latest .
#   docker tag lobu:latest $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/lobu:latest
#   docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/lobu:latest

# syntax=docker/dockerfile:1
FROM oven/bun:1 AS builder
WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ git \
  && rm -rf /var/lib/apt/lists/*

COPY package.json bun.lock bunfig.toml ./
COPY patches ./patches
COPY packages ./packages
COPY config ./config

RUN test -f packages/owletto-web/package.json || \
  (echo "packages/owletto-web is empty. Run: git submodule update --init --recursive packages/owletto-web" && exit 1)

RUN bun install --frozen-lockfile

RUN cd packages/core && bun run build \
  && cd ../owletto-sdk && bun run build \
  && cd ../worker && bun run build

RUN cd packages/owletto-web && bun run build

RUN cd packages/owletto-backend && bun run build:server

RUN bun install --frozen-lockfile --production

FROM node:22-bookworm-slim AS runtime
WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app /app

RUN mkdir -p /app/workspaces \
  && chown -R node:node /app

ENV NODE_ENV=production \
  LOBU_DEV_PROJECT_PATH=/app \
  LOBU_WORKER_ENTRYPOINT=/app/packages/worker/dist/index.js \
  PORT=8787 \
  HOST=0.0.0.0

EXPOSE 8787

USER node

CMD ["node", "packages/owletto-backend/dist/server.bundle.mjs"]
