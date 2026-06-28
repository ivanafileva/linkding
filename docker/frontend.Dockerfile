# Dedicated frontend image for linkding.
#
# nginx web tier that sits in front of the backend. It serves the full static
# build (compiled JS/CSS + admin/DRF assets) directly from a shared volume that
# the backend container populates, and reverse-proxies all application requests
# to the backend (uWSGI on port 9090). Any /static miss (e.g. favicons/previews
# generated at runtime) falls back to the backend.
FROM nginx:alpine

# Bake the reverse-proxy config into the image so it also works standalone.
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# The shared static build is mounted here at runtime (see docker-compose.yml).
RUN mkdir -p /var/www/static

EXPOSE 80

HEALTHCHECK --interval=30s --retries=3 --timeout=3s \
    CMD wget -qO- http://127.0.0.1/health >/dev/null 2>&1 || exit 1
