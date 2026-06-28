#!/usr/bin/env bash
# Entrypoint for the linkding backend container.
#
# Syncs the static build that was baked into the image (at /opt/linkding-static)
# into ./static, which docker-compose / k8s may mount as a shared volume so the
# frontend (nginx) container can serve the assets directly. Then hands off to the
# project's native bootstrap script, which runs migrations, creates the initial
# superuser and starts uWSGI + the Huey background worker.
set -e

cd /etc/linkding

# Publish the collected static build into the (possibly volume-mounted) ./static
mkdir -p static
cp -a /opt/linkding-static/. static/ 2>/dev/null || true

# Hand off to the standard linkding startup (migrations + uWSGI + Huey)
exec ./bootstrap.sh
