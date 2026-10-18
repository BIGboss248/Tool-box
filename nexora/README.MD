# Nexora Panel

A containerized deployment stack and interactive management toolkit for the **[Nexora Panel](https://docs.nexora-panel.org/)** — the control plane for Nexora proxy and VPN fleet management.

Nexora is built around an asymmetric architecture:
- **Panel (this stack)**: The single source of truth. Manages all protocols, users, templates, node configurations, subscriptions, and backups.
- **Nodes**: Stateless Linux edge servers running [`nexora-vpn/node`](https://github.com/nexora-vpn/node) that hold no database and are orchestrated dynamically by the panel over mutual TLS (mTLS).

---

## Architecture & Features

- **Database Choice**:
  - **SQLite (Default)**: Embedded, high-performance WAL-mode database stored in `./data`. Zero external dependencies, minimal memory footprint, ideal for fleets up to ~10,000 active concurrent users.
  - **PostgreSQL 17**: Dedicated container for large-scale operations, multi-node clustering, and network storage environments (`COMPOSE_PROFILES=postgres`).
- **One-Time Setup Wizard**: Newly deployed panels isolate themselves until initialized via a secure one-time token link printed upon deployment.
- **Traefik Reverse Proxy Integration**: Out-of-the-box routing labels for automatic HTTPS with Let's Encrypt HTTP-01 (`myresolver`) or Cloudflare DNS-01 (`cloudflare_resolver`), plus optional CrowdSec IPS protection.
- **Fleet Monitoring**: Integrated Prometheus & Grafana stack provisioned with the official Nexora fleet dashboard (`COMPOSE_PROFILES=monitoring`).
- **Disaster Recovery & CLI Access**: Offline password reset, token rotation, database restore, and HWID license inspection commands built directly into the Makefile.

---

## Directory Structure

```text
nexora/
├── docker-compose.yml              # Primary multi-profile Compose stack
├── .env.example                    # Template environment file
├── Makefile                        # Interactive guided setup & maintenance commands
├── README.MD                       # This documentation
├── data/                           # SQLite database storage (./data/nexora.db)
├── backups/                        # Database backup archives & snapshots
├── rulesets/                       # Mirrored routing rule-sets cached for nodes
├── bin/                            # Staged node binaries served to node installers
├── sub-themes/                     # Custom subscription page themes
├── certs/                          # mTLS certificates for same-server node
├── cache/                          # Cache directory for same-server node
└── monitoring/
    ├── docker-compose.monitoring.yml # Standalone monitoring overlay compose file
    ├── prometheus/
    │   ├── prometheus.yml          # Scrapes panel:2095/metrics with Bearer token
    │   └── token                   # API token with 'stats:read' scope
    └── grafana/
        ├── provisioning/
        │   ├── datasources/
        │   │   └── prometheus.yml  # Pre-configured Prometheus datasource
        │   └── dashboards/
        │       └── nexora.yml      # Pre-configured dashboard provider
        └── dashboards/
            └── nexora-fleet.json   # Official Nexora fleet Grafana dashboard
```

---

## Quickstart (Interactive Guided Setup)

To deploy Nexora using the automated, step-by-step guided wizard:

```bash
cd /scripts/Tool-box/nexora
make setup-all
```

The interactive wizard will:
1. Initialize `.env` and verify host `machine-id` (for licensing).
2. Prompt you to select your database engine (**SQLite** or **PostgreSQL 17**).
3. Configure the panel listening port (default: `2095`) and host IP binding.
4. Check and open the firewall port in `iptables` / `ufw`.
5. Offer Traefik reverse proxy integration (domain name & TLS resolver).
6. Prompt for optional Prometheus & Grafana monitoring.
7. Launch the containers with `docker compose up -d`.
8. Fetch the one-time **Setup Wizard Link** and display it with instructions.

---

## Makefile Command Reference

The `Makefile` provides idempotent setup steps and day-to-day administration targets:

| Target | Description |
|---|---|
| `make setup-all` | Runs the full interactive setup wizard and starts the stack (alias: `make install-nexora`). |
| `make token` | Displays the active one-time Setup Wizard URL & token (alias: `make setup-token`). |
| `make rotate-token` | Invalidates the existing setup token and generates a fresh one. |
| `make report` | Displays an ASCII colored status box of current settings, database driver, ports, and container states. |
| `make setup-db` | Interactively switches between SQLite and PostgreSQL 17 (generates secure passwords & updates profiles). |
| `make setup-port` | Configures the panel host port (default `2095`) and bind IP (`0.0.0.0` or `127.0.0.1`). |
| `make setup-firewall` | Opens the panel port in `ufw` or `iptables` and persists the rules across reboots. |
| `make setup-traefik` | Interactively configures Traefik reverse proxy routing, domain, and certificate resolver. |
| `make disable-traefik` | Reverts panel to direct host port exposure. |
| `make setup-monitoring` | Configures and enables Prometheus and Grafana with pre-provisioned dashboards. |
| `make disable-monitoring` | Stops and disables Prometheus and Grafana containers. |
| `make setup-node` | Activates same-server node profile for testing/lab environments. |
| `make disable-node` | Stops and removes the local node container. |
| `make admin-list` | Lists all administrator accounts registered in the panel database. |
| `make reset-password` | Interactively resets the main administrator password via CLI (clears 2FA and active sessions). |
| `make hwid` | Prints the host's hardware fingerprint (HWID) required for license activation. |
| `make backup` | Inspects backup archives in `./backups` and provides backup instructions. |
| `make restore` | Step-by-step instructions to restore the panel database from a `.tar.gz` archive. |
| `make update` | Pulls the newest container images and recreates running services with zero state loss. |
| `make restart` | Restarts all active stack services. |
| `make logs` | Follows live output from the panel container (alias: `make logs-panel`). |
| `make stop` | Gracefully stops all running Nexora containers. |
| `make down` | Stops and removes stack containers and internal networks. |

---

## Database Configuration

### Option A: SQLite (Default)
In `.env`:
```dotenv
NEXORA_DB_DRIVER=sqlite
NEXORA_DB_DSN=/app/db/nexora.db
COMPOSE_PROFILES=
```
- Database file is stored at `./data/nexora.db`.
- The panel uses SQLite WAL (Write-Ahead Logging) mode.
- Backups taken inside the panel UI (or via scheduled backups) are placed in `./backups`.

### Option B: PostgreSQL 17
To switch to PostgreSQL, run:
```bash
make setup-db
```
Or set in `.env`:
```dotenv
NEXORA_DB_DRIVER=postgres
NEXORA_DB_DSN=host=postgres port=5432 user=nexora password=YOUR_SECRET_PASSWORD dbname=nexora sslmode=disable
POSTGRES_USER=nexora
POSTGRES_PASSWORD=YOUR_SECRET_PASSWORD
POSTGRES_DB=nexora
COMPOSE_PROFILES=postgres
```
- The `postgres` service starts automatically using the `postgres:17-alpine` image.
- Database data is stored in the persistent Docker volume `pgdata`.
- The panel runs migrations automatically on boot once PostgreSQL passes its healthcheck.

---

## Traefik Reverse Proxy Integration

If you use Traefik (from `@traefik` in this toolbox), you can expose Nexora Panel with automatic Let's Encrypt certificates without opening port 2095 directly to the internet.

1. Run:
   ```bash
   make setup-traefik
   ```
2. Enter your domain (e.g., `nexora.yourdomain.com`).
3. Select your resolver:
   - `myresolver`: Let's Encrypt HTTP-01 challenge.
   - `cloudflare_resolver`: Cloudflare DNS-01 challenge (supports wildcards).
4. Restrict direct host binding to `127.0.0.1` when prompted.

In `.env`, this sets:
```dotenv
TRAEFIK_ENABLED=true
NEXORA_DOMAIN=nexora.yourdomain.com
TRAEFIK_CERTRESOLVER=myresolver
NEXORA_BIND_IP=127.0.0.1
DOCKER_NETWORK=my_network
```

---

## Prometheus & Grafana Monitoring

Nexora exports Prometheus metrics under `/metrics`. To protect fleet architecture data, the `/metrics` endpoint requires a Bearer token.

### Enabling Monitoring
1. Run:
   ```bash
   make setup-monitoring
   ```
2. Set your Grafana administrator password.
3. In the Nexora Panel: go to **Admins** -> **API tokens** -> **Add token** with the `stats:read` scope.
4. Paste the token when prompted (or place it in `./monitoring/prometheus/token`).
5. Open Grafana at `http://127.0.0.1:3000` (or through an SSH tunnel: `ssh -L 3000:127.0.0.1:3000 user@server`).
6. Navigate to **Dashboards** -> **Nexora** -> **Nexora Fleet** to view live node health, active sessions, traffic volume, CPU/memory, and disk usage.

---

## First-Run Setup Wizard

On first startup, the panel database contains no administrator accounts. To prevent unauthorized access:
1. Every path (including `/` and `/login`) returns `404 Not Found`.
2. Only the one-time link with the secret token can open the setup wizard:
   ```bash
   make token
   ```
3. Open the printed link in your browser:
   ```text
   http://YOUR_SERVER_IP:2095/setup?t=9f3c1ad2...
   ```
4. On the setup wizard page:
   - Create the **Main Administrator** account (username & 12+ character password).
   - Configure **Panel Path** and **Subscription Path**.
   - Configure **HTTPS** (self-signed or custom certificate).
   - Click **Save and Start**.

Once completed, the setup token is invalidated and the panel enters normal operations.

---

## Disaster Recovery & Troubleshooting

### Lost Setup Link or Expired Token
If you did not complete the setup wizard before the token expired or lost the link:
```bash
make token
# Or force a token rotation:
make rotate-token
```

### Locked Out / Reset Administrator Password
If you forgot the administrator password or lost your 2FA authenticator device:
```bash
make reset-password
```
This invokes `nexora-panel admin reset-password` inside the container:
- Prompts for a new password without echoing.
- Disables 2FA on the account.
- Immediately terminates all active sessions.

### Licensing & Hardware ID (HWID)
Nexora includes a free tier (up to 25 users, 1 node). To view your hardware ID for paid license activation:
```bash
make hwid
```
The stack automatically mounts `/etc/machine-id` (or generates a persistent `./machine-id` fallback) so your hardware fingerprint remains stable across container recreation.

### Backups & Restoring
- Automatic backups are stored in `./backups`.
- To restore an existing archive:
  ```bash
  # 1. Place your archive into ./backups/nexora-backup-YYYYMMDD.tar.gz
  # 2. Run restore:
  docker compose exec -it panel /app/nexora-panel restore /var/opt/nexora/backups/nexora-backup-YYYYMMDD.tar.gz
  # 3. Restart stack:
  make restart
  ```

---

## References

- Official Documentation: [docs.nexora-panel.org](https://docs.nexora-panel.org/)
- Official Panel GitHub: [github.com/Nexora-VPN/panel](https://github.com/Nexora-VPN/panel)
- Official Node GitHub: [github.com/Nexora-VPN/node](https://github.com/Nexora-VPN/node)
- Traefik Stack Reference: `@traefik`

