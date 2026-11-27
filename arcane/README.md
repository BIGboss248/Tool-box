# Arcane

Self-hosted Docker management UI, deployed behind the shared Traefik stack in
`../traefik`. This stack uses **bind mounts only** — there are no named volumes.

- Upstream install guide: <https://getarcane.app/docs/get-started/installation>
- Traefik guide: <https://getarcane.app/docs/networking/reverse-proxy>

## Layout

| Path | Container path | Purpose |
|---|---|---|
| `./data` | `/app/data` | SQLite database, sessions, first-run admin password |
| `./projects` | `/opt/docker` | Compose projects managed by Arcane |
| `./builds` | `/builds` | Dockerfiles and build contexts for image builds |
| `./backups` | `/backups` | Exported volume backups |
| `/var/run/docker.sock` | `/var/run/docker.sock` | Docker API access (read-write) |

Host paths are configurable in `.env` (`ARCANE_DATA_DIR`, `ARCANE_PROJECTS_DIR`,
`ARCANE_BUILDS_DIR`, `ARCANE_BACKUPS_DIR`). The projects folder is mounted at the
same path inside the container (`/opt/docker`), which keeps relative mounts in
managed Compose projects resolvable.

Upstream recommends host and container paths match for the projects folder. The
default `./projects` host path works because Arcane maps it from its own mount
table; for exact parity set `ARCANE_PROJECTS_DIR=/opt/docker` so `/opt/docker`
exists on the host as well.

## Prerequisites

- Docker Engine and the Compose plugin.
- The Traefik stack from `../traefik` running, sharing the `my_network` Docker
  network (created by that stack). Ports 80/443 must be reachable.
- A Cloudflare API token in `../traefik/.env` (`CF_DNS_API_TOKEN`), because the
  default resolver is `cloudflare_resolver`. Run `make setup-cloudflare` in
  `../traefik` or set `TRAEFIK_CERTRESOLVER=myresolver` to use HTTP-01 instead.
- DNS for the Arcane hostname pointing at the Docker host.

## Quick start

```bash
cd arcane
make install-arcane     # configure .env, generate a key, then deploy
make report             # show the resulting configuration
```

`install-arcane` runs `setup-secret`, `setup-domain` and `setup-proxies` before
deploying. To configure in steps:

```bash
make init-env           # creates .env from .env.example and the bind-mount dirs
make setup-secret       # generates ARCANE_ENCRYPTION_KEY (Docker CLI or OpenSSL)
make setup-domain       # public domain + certresolver (myresolver / cloudflare_resolver)
make setup-proxies      # detects the Docker network CIDR for ARCANE_TRUSTED_PROXIES
make deploy
```

The Makefile handles privilege escalation automatically:

- Docker commands use `sudo` when the current user is not in the `docker` group.
- Bind-mount paths under `/srv` that the user cannot create or read are retried
  with `sudo` (creation, ownership, backups and cleanup).
- Force sudo for everything with `make <target> SUDO=sudo`.

For a `/srv` deployment, point the paths in `.env` at absolute directories:

```dotenv
ARCANE_DATA_DIR=/srv/arcane/data
ARCANE_PROJECTS_DIR=/srv/arcane/projects
ARCANE_BUILDS_DIR=/srv/arcane/builds
ARCANE_BACKUPS_DIR=/srv/arcane/backups
```

`make deploy` creates them and aligns their owner with `PUID:PGID`; use
`make fix-ownership` to recursively fix existing contents after a migration.

## First sign-in

Arcane creates an `arcane` admin with a random password on first boot and writes
it to `/app/data/initial-admin-password` — on the host that is
`./data/initial-admin-password`.

```bash
make password           # prints it from the container
# or
cat ./data/initial-admin-password
```

Sign in at `ARCANE_APP_URL` as `arcane`, then set a new password. The file is
removed after the first password change.

## Configuration

`.env.example` documents every variable. The important ones:

| Variable | Default | Notes |
|---|---|---|
| `ARCANE_DOMAIN` | `arcane.example.com` | Public hostname, no scheme or port |
| `ARCANE_APP_URL` | `https://arcane.example.com` | Exact URL users open; must match the domain |
| `ARCANE_TLS_ENABLED` | `false` | Traefik terminates TLS; keep `false` for h2c agent tunnels |
| `ARCANE_ENCRYPTION_KEY` | — | Required; `make setup-secret` generates it |
| `ARCANE_TRUSTED_PROXIES` | `172.18.0.0/16` | CIDR of the Traefik network; `make setup-proxies` sets it |
| `DOCKER_NETWORK` | `my_network` | Must match Traefik's network |
| `TRAEFIK_CERTRESOLVER` | `cloudflare_resolver` | DNS-01 (wildcards); needs `CF_DNS_API_TOKEN` in `../traefik/.env`. Use `myresolver` for HTTP-01 |
| `ARCANE_MIDDLEWARES` | `arcane-compress,arcane-headers` | Prepend `crowdsec-bouncer` when CrowdSec is enabled |
| `PUID` / `PGID` | `1000` / `1000` | Host owner for files Arcane creates |
| `TZ` | `Asia/Tehran` | IANA timezone used by scheduled jobs |

`ARCANE_TRUSTED_PROXIES` is required for correct login rate limiting: without it,
Arcane sees every request as coming from Traefik and rate-limits by the proxy IP.
`make setup-proxies` reads the subnet from `docker network inspect` and writes it
for you.

## Traefik integration

The service registers two routers on the domain:

| Router | Rule | Backend |
|---|---|---|
| `arcane-web` (priority 10) | `Host(...)` — UI, API and WebSockets | `arcane:3552` over `http` |
| `arcane-grpc` (priority 100) | `Host(...) && Path(/api/tunnel/connect) && POST && Content-Type ~ ^application/grpc` | `arcane:3552` over `h2c` |

The gRPC router is only used by remote agents; the web router alone serves the
UI. No dedicated WebSocket middleware is needed — Traefik forwards the upgrade
itself. The default chain only adds compression and a `noindex` header, both
defined by this stack.

### Remote agent tunnel (gRPC)

Traefik's `websecure` entrypoint stops reading responses after 60s by default,
which kills the long-lived gRPC tunnel. The required flag is set in
`../traefik/docker-compose.yml`:

```yaml
- "--entrypoints.websecure.transport.respondingtimeouts.readtimeout=0s"
```

Recreate Traefik once so it takes effect:

```bash
cd ../traefik && make restart
```

Arcane runs with `ARCANE_TLS_ENABLED=false`, so Traefik forwards the tunnel to
port 3552 as `h2c`. Without the flag, `ARCANE_AGENT_TRANSPORT=auto` falls back to
WebSocket; `transport=grpc` fails outright.

### CrowdSec

The Traefik stack always defines the `crowdsec-bouncer` middleware (disabled
unless CrowdSec is configured). To protect Arcane with it:

```dotenv
ARCANE_MIDDLEWARES=crowdsec-bouncer,arcane-compress,arcane-headers
```

Then `make restart`. Note that the bouncer trusts private ranges by default, so
protect the public path (Cloudflare or direct) rather than LAN clients.

## Remote agents

Agents connect outbound to the Manager and open no ports, so the agent host can
sit behind NAT. The Manager side is already prepared: the `arcane-grpc` router
plus the disabled `websecure` read timeout above.

1. In Arcane open **Agents → Add Agent**, name the host, then **Generate Agent
   Configuration**. The enrollment token is shown once.
2. On the remote host, run the agent with `ARCANE_MANAGER_API_URL` set to the
   same public URL as `ARCANE_APP_URL` (must be `https://`) and
   `ARCANE_AGENT_TRANSPORT=auto`.
3. Keep `/app/data` persistent — it stores the agent key (and mTLS material).
   Without it, a used single-use token is refused on the next restart.

Bind-mounted agent example (no named volumes, matching this repo's convention):

```yaml
services:
  arcane-agent:
    image: ghcr.io/getarcaneapp/agent:latest
    container_name: arcane-agent
    restart: unless-stopped
    environment:
      - ARCANE_AGENT=true
      - ARCANE_AGENT_TRANSPORT=auto
      - ARCANE_AGENT_TOKEN=arc_etkn_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
      - ARCANE_MANAGER_API_URL=https://arcane.example.com
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./agent-data:/app/data
```

`auto` tries gRPC first and falls back to WebSocket, which is served by the
`arcane-web` router. Agents have no listening port and no HTTP health endpoint;
check **Agents** in the UI for **Online** status and tunnel stats.

If you enable **Agent mTLS** (`ARCANE_AGENT_MTLS_MODE=required`), Traefik must
request and verify client certificates on `/api/tunnel/connect`; otherwise the
proxy rejects the tunnel. Use `optional` while rolling out, and persist
`ARCANE_AGENT_MTLS_ASSETS_DIR` on the agent.

## Make targets

| Target | Description |
|---|---|
| `make install-arcane` | Configure and deploy the full stack end-to-end |
| `make setup-all` | Configure `.env` without deploying |
| `make setup-secret` | Generate or rotate `ARCANE_ENCRYPTION_KEY` |
| `make setup-domain` | Set domain, app URL and TLS resolver |
| `make setup-proxies` | Detect and set `ARCANE_TRUSTED_PROXIES` |
| `make fix-ownership` | Recursively chown bind mounts to `PUID:PGID` (escalates if needed) |
| `make deploy` | Create bind-mount dirs, start the stack, wait for healthy |
| `make down` | Stop and remove the container; data is kept |
| `make restart` | Recreate the container to apply `.env` changes |
| `make status` | Container status and health |
| `make health` | Run `arcane health` inside the container |
| `make logs` | Follow logs |
| `make password` | Print the first-run admin password |
| `make update` | Pull the latest image and recreate |
| `make backup` | Stop, tar `./data` into `./backups`, start |
| `make report` | Colored configuration and status summary |
| `make clean` | Delete `./data` (asks for confirmation) |
| `make clean-all` | Also delete `./projects`, `./builds`, `./backups` |

## Operations

### Updates

```bash
make update
```

Pulls `ghcr.io/getarcaneapp/manager:latest` and recreates the container. The
database schema migrates on start; back up first if you care about rollback.

### Backups

```bash
make backup
```

Stops the container for a consistent SQLite copy, writes
`./backups/arcane-data-<timestamp>.tar.gz`, then starts it again. Restore with:

```bash
make down
tar -xzf ./backups/arcane-data-<timestamp>.tar.gz -C ./data
make deploy
```

### Health

The container uses Arcane's built-in probe:

```yaml
healthcheck:
  test: ["CMD", "./arcane", "health", "--timeout", "2s"]
  interval: 10s
  timeout: 3s
  retries: 5
  start_period: 15s
```

`start_period` covers first-boot migrations, so a slow start is not marked
unhealthy. `make deploy` waits for the health status before returning.

## Security notes

- The Docker socket grants root-equivalent control of the host. Keep Arcane on a
  trusted network, do not expose port 3552 publicly (`ARCANE_BIND` defaults to
  `127.0.0.1`), and put it behind Traefik with TLS.
- `ARCANE_ENCRYPTION_KEY` encrypts stored secrets. Back it up with `./data`;
  losing it makes previously encrypted credentials unreadable.
- Prefer a socket proxy (`/docs/security/socket-proxy`) if you need to restrict
  what Arcane can do through the Docker API.
- Put the admin behind strong credentials. `ARCANE_DEFAULT_ADMIN_USERNAME` and
  `ARCANE_DEFAULT_ADMIN_PASSWORD` are only read when the database is empty.

## Troubleshooting

| Symptom | Check |
|---|---|
| 404 from Traefik | `docker compose logs traefik`; confirm the containers share `DOCKER_NETWORK` and that `traefik.enable=true` |
| 502/504 | `make status`; the container must be `healthy` before Traefik routes to it |
| Login limiter trips for everyone | `ARCANE_TRUSTED_PROXIES` does not match the Traefik network CIDR — rerun `make setup-proxies` |
| Oversized-cookie sign-in errors | Raise Traefik's request header size; old sessions can span multiple cookies |
| Remote agent tunnel drops | Add the `readtimeout=0s` entrypoint flag above and recreate Traefik |
| `ARCANE_ENCRYPTION_KEY is required` | Run `make setup-secret` |
