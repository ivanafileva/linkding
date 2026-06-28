# Dedicated database image for linkding.
#
# Thin wrapper around the official Postgres image so the database is built and
# versioned alongside the other services. Drop SQL files into
# /docker-entrypoint-initdb.d to have them run on first initialization.
FROM postgres:16-alpine

# Store data on a stable path that docker-compose / k8s mount a volume onto.
ENV PGDATA=/var/lib/postgresql/data/pgdata

# Document the port the server listens on.
EXPOSE 5432
