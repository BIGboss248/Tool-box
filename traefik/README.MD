
# Traefik

## Legacy setup

After a few trys and fails I changed the file the legacy configs are commented and crossed out in docker-compose file (install better comments in vs code to see the comments crossed) and its files are moved to legacy folder.

## Configs for containers

Container configs are saved in my snippet section of my vscode profile

## Configuration with .env

Configuration is managed via `.env`. A template is provided in `.env.example`:
```bash
cp .env.example .env
```

### Dashboard Access & Security
The dashboard is exposed via HTTPS with Basic Authentication (never exposed unauthenticated on port 8080):
- **Domain**: Set `TRAEFIK_DASHBOARD_DOMAIN` (e.g., `traefik.yourdomain.com`).
- **Resolver**: Set `TRAEFIK_DASHBOARD_CERTRESOLVER` to `myresolver` (HTTP-01) or `cloudflare_resolver` (DNS-01).
- **Authentication**: Set `TRAEFIK_BASIC_AUTH_USERS` in `.env` using htpasswd (`htpasswd -nb user password`). Remember to double dollar signs (`$$`) to prevent docker compose interpolation issues.

## TLS Certificate Resolvers

Traefik is configured with two certificate resolvers:
1. `myresolver`: Standard Let's Encrypt HTTP-01 challenge on port 80 (requires port 80 open and non-proxied DNS direct to host).
2. `cloudflare_resolver`: Let's Encrypt DNS-01 challenge via Cloudflare (supports wildcard domains and hosts behind Cloudflare CDN/proxy).

### Cloudflare DNS Challenge Requirements
The Cloudflare API Token needs the following permissions:
- `Zone.Zone` - Read
- `Zone.DNS` - Edit

Set `CF_DNS_API_TOKEN` and `CF_ZONE_API_TOKEN` in your `.env`.

## Makefile Commands

The Makefile includes individual idempotent setup targets as well as an automated orchestrator:

| Target | Description |
|---|---|
| `make setup-all` | Runs all setup targets sequentially, checking and skipping tasks already completed. |
| `make setup-firewall` | Opens ports 80/443 in `iptables` and persists rules with `netfilter-persistent` / `iptables-save`. |
| `make setup-certs` | Ensures `acme.json` exists with required `600` permissions. |
| `make setup-auth` | Configures dashboard Basic Auth username & password using bcrypt/htpasswd (escapes `$$` for compose). |
| `make setup-acme` | Sets ACME registration email or allows skipping. |
| `make setup-cloudflare` | Configures Cloudflare DNS API token or allows skipping. |
| `make setup-dashboard` | Prompts for dashboard domain and TLS resolver (`myresolver` vs `cloudflare_resolver`). |
| `make report` | Displays an ASCII colored status box of all configurations and system states. |
| `make install-traefik` | Runs `setup-all` and launches Traefik with `docker compose up -d`. |


