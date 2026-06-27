# Stage 1: Builder
# Note: python:3.13-slim is required because pyproject.toml specifies requires-python = ">=3.13"
FROM python:3.13-slim AS builder

# Install Node.js 20 (needed to compile frontend JS/CSS before collectstatic)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app

# Install Python dependencies (production + postgres driver, no dev extras)
COPY pyproject.toml uv.lock ./
RUN uv sync --no-dev --group postgres --frozen

# Install gunicorn into the venv (project uses uWSGI by default; gunicorn is our runtime choice)
RUN .venv/bin/pip install --no-cache-dir gunicorn

# Install and build frontend assets
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# Collect Django static files into /app/static/
RUN mkdir -p data && \
    SECRET_KEY=build-only-not-used-in-prod \
    DJANGO_SETTINGS_MODULE=bookmarks.settings.prod \
    .venv/bin/python manage.py collectstatic --no-input

# Stage 2: Runtime — slim image with no build tooling
FROM python:3.13-slim

RUN groupadd --gid 1001 linkding && \
    useradd --uid 1001 --gid 1001 --no-create-home linkding

WORKDIR /app

# Copy virtual environment and compiled assets from builder
COPY --from=builder --chown=linkding:linkding /app/.venv ./.venv
COPY --from=builder --chown=linkding:linkding /app/static ./static
COPY --from=builder --chown=linkding:linkding /app/bookmarks ./bookmarks
COPY --from=builder --chown=linkding:linkding /app/manage.py ./manage.py

# Persistent data directory (secret key file, uploaded assets)
RUN mkdir -p /etc/linkding/data && chown -R linkding:linkding /etc/linkding/data

USER linkding

ENV PATH="/app/.venv/bin:$PATH" \
    DJANGO_SETTINGS_MODULE=bookmarks.settings.prod

EXPOSE 9090

CMD ["gunicorn", "bookmarks.wsgi:application", "--bind", "0.0.0.0:9090", "--workers", "4", "--timeout", "60"]
