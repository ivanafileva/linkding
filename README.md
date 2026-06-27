<div align="center">
    <br>
    <a href="https://github.com/sissbruecker/linkding">
        <img src="assets/header.svg" height="50">
    </a>
    <br>
</div>

## DevOps Assignment

This section documents the custom infrastructure added on top of the linkding project.

### Services

| Service | Image | Role |
|---------|-------|------|
| `db` | `postgres:16-alpine` | Persistent PostgreSQL database with health check |
| `linkding` | Built from local `Dockerfile` | Django app served by gunicorn on port 9090 |
| `nginx` | `nginx:alpine` | Reverse proxy, routes port 80 → linkding:9090 |

### Running with Docker Compose

```bash
cp .env.example .env          # fill in POSTGRES_PASSWORD and LD_SUPERUSER_PASSWORD
docker compose up --build -d  # build and start all 3 services
docker compose logs -f        # follow logs
docker compose down -v        # stop and remove volumes
```

The app is available at `http://localhost` once all services are healthy.

### CI Pipeline (`.github/workflows/ci.yml`)

Triggers on every push to `main`:
1. Runs `pytest bookmarks/tests/ -x -q` to validate the codebase
2. Logs in to DockerHub using repository secrets `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN`
3. Builds the custom `Dockerfile` and pushes two tags: `latest` and the commit SHA

### Kubernetes

```bash
kubectl apply -f k8s/ -n linkding
```

Manifests in `k8s/`: namespace → postgres Secret + StatefulSet + headless Service → linkding ConfigMap + Secret + Deployment + ClusterIP Service + Ingress.
Before applying, replace base64 placeholder values in `k8s/postgres-secret.yaml` and `k8s/linkding-configmap-secret.yaml`, and set your DockerHub username in `k8s/linkding-deployment.yaml`.

---

##  Introduction

linkding is a bookmark manager that you can host yourself.
It's designed be to be minimal, fast, and easy to set up using Docker.

The name comes from:
- *link* which is often used as a synonym for URLs and bookmarks in common language
- *Ding* which is German for thing
- ...so basically something for managing your links

**Feature Overview:**
- Clean UI optimized for readability
- Organize bookmarks with tags
- Bulk editing, Markdown notes, read it later functionality
- Share bookmarks with other users or guests
- Automatically provides titles, descriptions and icons of bookmarked websites
- Automatically archive websites, either as local HTML file or on Internet Archive
- Import and export bookmarks in Netscape HTML format
- Installable as a Progressive Web App (PWA)
- Extensions for [Firefox](https://addons.mozilla.org/firefox/addon/linkding-extension/) and [Chrome](https://chrome.google.com/webstore/detail/linkding-extension/beakmhbijpdhipnjhnclmhgjlddhidpe), as well as a bookmarklet
- SSO support via OIDC or authentication proxies
- REST API for developing 3rd party apps
- Admin panel for user self-service and raw data access


**Demo:** https://demo.linkding.link/

**Screenshot:**

![Screenshot](/docs/public/linkding-screenshot.png?raw=true "Screenshot")

## Getting Started

The following links help you to get started with linkding:
- [Install linkding on your own server](https://linkding.link/installation) or [check managed hosting options](https://linkding.link/managed-hosting)
- [Install the browser extension](https://linkding.link/browser-extension)
- [Check out community projects](https://linkding.link/community), which include mobile apps, browser extensions, libraries and more

## Documentation

The full documentation is now available at [linkding.link](https://linkding.link/).

If you want to contribute to the documentation, you can find the source files in the `docs` folder.

If you want to contribute a community project, feel free to [submit a PR](https://github.com/sissbruecker/linkding/edit/master/docs/src/content/docs/community.md).

## Contributing

Small improvements, bugfixes and documentation improvements are always welcome. If you want to contribute a larger feature, consider opening an issue first to discuss it. I may choose to ignore PRs for features that don't align with the project's goals or that I don't want to maintain.

## Development

The application is built using the Django web framework. You can get started by checking out the excellent [Django docs](https://docs.djangoproject.com/en/4.1/). The `bookmarks` folder contains the actual bookmark application. Other than that the code should be self-explanatory / standard Django stuff 🙂.

### Prerequisites
- Python 3.13
- [uv](https://docs.astral.sh/uv/getting-started/installation/)
- Node.js

### Setup

Initialize the development environment with:
```
make init
```
This sets up a virtual environment using uv, installs NPM dependencies and runs migrations to create the initial database.

Create a user for the frontend:
```
uv run manage.py createsuperuser --username=joe --email=joe@example.com
```

Run the frontend build for bundling frontend components with:
```
make frontend
```

Then start the Django development server with:
```
make serve
```
The frontend is now available under http://localhost:8000

### Tests

Run all tests with pytest:
```
make test
```


### Linting

Run linting with ruff:
```
make lint
```

### Formatting

Format Python code with ruff, Django templates with djlint, and JavaScript code with prettier:
```
make format
```

### DevContainers

This repository also supports DevContainers: [![Open in Remote - Containers](https://img.shields.io/static/v1?label=Remote%20-%20Containers&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/sissbruecker/linkding.git)

Once checked out, only the following commands are required to get started:

Create a user for the frontend:
```
uv run manage.py createsuperuser --username=joe --email=joe@example.com
```
Start the Node.js development server (used for compiling JavaScript components like tag auto-completion) with:
```
make frontend
```
Start the Django development server with:
```
make serve
```
The frontend is now available under http://localhost:8000
