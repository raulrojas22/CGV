# Deployment tooling

This directory contains infrastructure used to deploy CGeV. It is separate
from the application entry points at the repository root.

- `docker/` — dependency image, container entry point, and cache prewarming.
- `nginx/` — reverse-proxy and static-asset configuration.
- `shinyproxy/` — ShinyProxy application configuration.
- `rootless/` and `systemd/` — alternative host environments.
- `docker-compose.deploy.yml` — production Docker Compose configuration.
- `docker-compose.shinyproxy.yml` — per-session ShinyProxy configuration.
- `deploy-*.sh` — operator deployment scripts.

Run commands from the repository root. User-facing instructions are maintained
in [`docs/deployment/`](../docs/deployment/).
