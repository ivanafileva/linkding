# Dedicated backend image for linkding.
#
# Produces the full application build: it compiles the frontend assets (JS/CSS),
# installs the Python dependencies (incl. the PostgreSQL driver), and runs
# collectstatic so the complete static bundle is baked in. At runtime it syncs
# that static build into a shared volume (so the frontend/nginx container can
# serve it) and starts uWSGI together with the Huey background task worker.

# ---------------------------------------------------------------------------
# Stage 1 — build the frontend assets (bundle.js + theme CSS) with Node
# ---------------------------------------------------------------------------
FROM node:22-alpine AS node-build
WORKDIR /build
# Install JS build dependencies first for better layer caching
COPY package.json package-lock.json rollup.config.mjs postcss.config.js ./
RUN npm ci
# Copy only the sources needed to produce the bundle
COPY bookmarks/frontend ./bookmarks/frontend
COPY bookmarks/styles ./bookmarks/styles
# Emits bookmarks/static/bundle.js and bookmarks/static/theme-*.css
RUN npm run build

# ---------------------------------------------------------------------------
# Stage 2 — install Python dependencies (production + Postgres driver)
# ---------------------------------------------------------------------------
FROM python:3.13-slim AS python-build
# build-essential / libpq-dev: build psycopg (C) and other wheels from source
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libpq-dev \
        python3-dev \
    && rm -rf /var/lib/apt/lists/*
# Bring in the uv package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv
WORKDIR /etc/linkding
COPY pyproject.toml uv.lock ./
# --no-dev: skip dev tooling, --group postgres: build psycopg[c] for Postgres
RUN uv sync --no-dev --group postgres --frozen

# ---------------------------------------------------------------------------
# Stage 3 — runtime image
# ---------------------------------------------------------------------------
FROM python:3.13-slim AS runtime
LABEL org.opencontainers.image.source="https://github.com/sissbruecker/linkding"

# Runtime dependencies:
# libpq5: Postgres client library, libexpat1: XML parsing required by uWSGI,
# media-types: MIME types for served files, curl: container health check
RUN apt-get update && apt-get install -y --no-install-recommends \
        libpq5 \
        libexpat1 \
        media-types \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /etc/linkding

# Python virtual environment from the build stage
COPY --from=python-build /etc/linkding/.venv ./.venv
ENV VIRTUAL_ENV=/etc/linkding/.venv
ENV PATH="/etc/linkding/.venv/bin:$PATH"
ENV DJANGO_SETTINGS_MODULE=bookmarks.settings.prod

# Application code
COPY . .
# Overlay the compiled frontend assets on top of the committed static files
COPY --from=node-build /build/bookmarks/static ./bookmarks/static

# Collect the complete static bundle (frontend assets + admin/DRF + app images),
# then move it out of the way so a volume mounted at ./static at runtime does not
# hide it. The entrypoint syncs it back into that volume on startup.
RUN mkdir -p data \
    && python manage.py collectstatic --no-input \
    && mv static /opt/linkding-static \
    && chmod +x ./bootstrap.sh ./docker/backend-entrypoint.sh

# Limit file descriptors used by uWSGI (see linkding issue #453)
ENV UWSGI_MAX_FD=4096
# uWSGI serves the app (and static/favicons/previews) on this port
EXPOSE 9090

HEALTHCHECK --interval=30s --retries=3 --timeout=3s \
    CMD curl -f http://localhost:${LD_SERVER_PORT:-9090}/${LD_CONTEXT_PATH}health || exit 1

ENTRYPOINT ["/bin/bash", "/etc/linkding/docker/backend-entrypoint.sh"]
