
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
| `make setup-crowdsec` | Interactively enables CrowdSec IPS, prompts/auto-generates API key, configures Captcha remediation, selects scope, and tails verification logs. |
| `make setup-captcha` | Interactively configures or updates the CrowdSec Captcha provider (`turnstile`, `hcaptcha`, `recaptcha`), keys, grace period, and remediation profile (`profiles.yaml`). |
| `make disable-crowdsec`| Disables CrowdSec IPS, stops the CrowdSec container, and updates Traefik. |
| `make enable-crowdsec-all` | Protects ALL services globally via `websecure` entrypoint and restarts Traefik. |
| `make disable-crowdsec-all`| Reverts to per-service protection (disables global entrypoint middleware). |
| `make setup-metrics` | Interactively configures & enables Prometheus Metrics with built-in Prometheus Server UI (`127.0.0.1:9090`) or internal `/metrics` endpoint (`:8082`). |
| `make disable-metrics` | Disables Prometheus Metrics, comments out `--metrics.*` flags, and stops the Prometheus container. |
| `make setup-tracing` | Interactively configures & enables OpenTelemetry (OTLP) Tracing with built-in Jaeger UI (`127.0.0.1:16686`) or a custom OTLP collector. |
| `make disable-tracing` | Disables OpenTelemetry Tracing, comments out `--tracing.*` flags, and stops the Jaeger container. |
| `make report` | Displays an ASCII colored status box of all configurations, Captcha status, Tracing status, scopes, and system states. |
| `make crowdsec-report`| Displays a detailed CrowdSec report (registered bouncers, active bans/captchas, metrics). |
| `make crowdsec-bans`  | Displays active CrowdSec IP bans & captcha decisions (alias: `make bans`). |
| `make captcha-test`   | Adds a test 4-hour `captcha` decision for an IP (`make captcha-test IP=x.x.x.x`). |
| `make crowdsec-unban` | Removes active ban/captcha decisions for an IP interactively or via `make crowdsec-unban IP=x.x.x.x` (alias: `make unban`). |
| `make logs-crowdsec` | Follows live logs from the CrowdSec container. |
| `make install-traefik` | Runs `setup-all` and launches Traefik with `docker compose up -d`. |

## CrowdSec Intrusion Prevention (IPS), Behind-Proxy & Captcha Remediation

CrowdSec is integrated using the [CrowdSec Bouncer Traefik Plugin](https://plugins.traefik.io/plugins/6335346ca4caa9ddeffda116/crowdsec-bouncer-traefik-plugin):
- **Log Acquisition**: CrowdSec parses Traefik's access log (`./logs/access.log`) via `./crowdsec/acquis.yaml` using the `crowdsecurity/traefik`, `crowdsecurity/http-cve`, `crowdsecurity/base-http-scenarios`, and `crowdsecurity/whitelist-good-actors` collections.
- **Behind-Proxy (Cloudflare & Local Reverse Proxy)**:
  - Traefik entrypoints (`web` and `websecure`) and the CrowdSec Bouncer plugin (`forwardedheaderstrustedips`) both trust Cloudflare IPv4/IPv6 CIDR ranges and private Docker/LAN ranges via `X-Forwarded-For`, preventing IP spoofing on direct connections while accurately extracting the real client IP behind Cloudflare.
  - Internal LAN/Docker ranges (`127.0.0.1/32,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16`) are whitelisted in `clienttrustedips`.
- **Decision Enforcement & Custom Ban Page**:
  - The bouncer plugin runs in **stream mode** inside Traefik (`updatemaxfailure=-1`, `streamstartupblock=false`), syncing decisions every 60s into an in-memory cache with zero latency overhead on HTTP requests.
  - `./crowdsec/ban.html` is mounted into the Traefik container at `/ban.html:ro` (`banfilepath=/ban.html`), so banned visitors receive a styled **CrowdSec Access Forbidden** HTML page (displaying `{{ .ClientIP }}` and `{{ .RemediationReason }}`) along with `HTTP 403` instead of a blank browser error page.
- **Enable on Running Instance**: Run `make setup-crowdsec`.
- **Protect All Endpoints (Zero Labels)**: Run `make enable-crowdsec-all` to protect all services routed via port 443 automatically.
- **Per-Service Mode**: Run `make disable-crowdsec-all` to only protect services explicitly labeled with `crowdsec-bouncer@docker`.
- **Detailed Security Report**: Run `make crowdsec-report` to view active bans/captchas, bouncer status, and parsed metrics.
- **Live Logs**: Run `make logs-crowdsec` to monitor the CrowdSec engine.
- **Disable Anytime**: Run `make disable-crowdsec`.

---

## Detailed Guide: Setting Up CrowdSec Captcha Remediation

CrowdSec supports two remediation actions in Traefik:
1. **`ban`**: Immediately returns `HTTP 403 Forbidden`.
2. **`captcha`**: Renders `/captcha.html` (`./crowdsec/captcha.html`) challenging the user with **Cloudflare Turnstile**, **hCaptcha**, or **Google reCAPTCHA v2**. Once solved, the user's IP is marked clean in Traefik's cache for the configured grace period (`1800` seconds / 30 minutes by default) and redirected back to the original page.

### Step 1: Obtain a Site Key & Secret Key from a Captcha Provider

Choose one of the 3 supported providers:

#### Option A: Cloudflare Turnstile *(Recommended)*
1. Go to the [Cloudflare Dashboard](https://dash.cloudflare.com/) -> **Turnstile** -> **Add Widget**.
2. Enter a widget name and add your domain(s) (e.g., `yourdomain.com` or all subdomains).
3. Select **Managed** (or Non-interactive / Invisible) widget mode and click **Create**.
4. Copy the **Site Key** and **Secret Key**.

#### Option B: hCaptcha
1. Sign in to the [hCaptcha Dashboard](https://dashboard.hcaptcha.com/).
2. Go to **Sites** -> **New Site** and add your domain(s) -> copy the **Sitekey**.
3. Go to **Settings** -> copy your account **Secret Key**.

#### Option C: Google reCAPTCHA v2
1. Go to the [Google reCAPTCHA Admin Console](https://www.google.com/recaptcha/admin/create).
2. Choose **Challenge (v2)** -> **"I'm not a robot" Checkbox** (note: use reCAPTCHA v2 Challenge, not v3 score-based).
3. Add your domain(s) and submit.
4. Copy the **Site Key** and **Secret Key**.

---

### Step 2: Configure Captcha (Interactive or Manual)

#### Method 1: Interactive Setup via Makefile *(Recommended)*
Run:
```bash
make setup-captcha
```
*(Note: `make setup-captcha` is also called automatically during `make setup-crowdsec` and `make setup-all`.)*

You will be prompted for:
1. **Captcha Provider**:
   - `1) Cloudflare Turnstile (turnstile)`
   - `2) hCaptcha (hcaptcha)`
   - `3) Google reCAPTCHA v2 (recaptcha)`
   - `4) Disable Captcha (use HTTP 403 Ban only)`
2. **Site Key & Secret Key**: Paste the keys from Step 1.
3. **Grace Period**: How long (in seconds) a user can browse after solving a Captcha before being re-challenged if their decision is still active (default: `1800` = 30 minutes).
4. **CrowdSec Remediation Profile Mode**:
   - `1) Mixed (Recommended)`: Writes `./crowdsec/profiles.yaml` so the **first 3 HTTP scenario alerts within 24 hours** receive a `4h` **`captcha`** challenge, and **4+ alerts** (or non-HTTP scenarios) escalate to a `4h` **`ban`**.
   - `2) Captcha-only`: Copies `./crowdsec/profiles_captcha_only.yaml` to `./crowdsec/profiles.yaml` so all HTTP scenario alerts trigger a `captcha` challenge.

`make setup-captcha` automatically ensures `./crowdsec/captcha.html` is downloaded, saves the settings to `.env`, and recreates Traefik/CrowdSec if running.

#### Method 2: Manual Setup via `.env`
Edit `.env` directly:
```dotenv
CROWDSEC_CAPTCHA_PROVIDER=turnstile
CROWDSEC_CAPTCHA_SITE_KEY=0x4AAAAAA...
CROWDSEC_CAPTCHA_SECRET_KEY=0x4AAAAAA...
CROWDSEC_CAPTCHA_GRACE_PERIOD=1800
```
Then apply the changes:
```bash
make restart
```

---

### Step 3: Verify & Test Captcha Challenges

1. **Check Configuration Status**:
   ```bash
   make report
   ```
   Verify that `CrowdSec Captcha` shows `Enabled (turnstile|hcaptcha|recaptcha)`.

2. **Trigger a Manual Test Captcha on an IP**:
   > **Note**: Internal LAN/Docker IPs (`127.0.0.1/32`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) are in `clienttrustedips` and bypass CrowdSec checks. Test using an external IP (e.g., your public IP or mobile data IP):
   ```bash
   make captcha-test IP=203.0.113.50
   ```
   *(Wait up to 60 seconds in `stream` mode for Traefik's bouncer cache to sync with CrowdSec LAPI.)*

3. **View Active Decisions**:
   ```bash
   make bans
   ```
   You will see the decision listed with action `captcha`.

4. **Remove the Test Decision**:
   ```bash
   make unban IP=203.0.113.50
   ```

---

## Optional OpenTelemetry Distributed Tracing (Traefik v3.7)

Traefik v3.7 natively instruments HTTP requests using the **OpenTelemetry (OTLP)** standard and W3C Trace Context (`traceparent` / `tracestate` headers):
- **Span Hierarchy**: For every sampled incoming request, Traefik creates a root entrypoint span, child spans for each middleware (including `crowdsec-bouncer` via `traceheaderscustomname=traceparent`), and a child span for the upstream backend service call, propagating `traceparent` so your backend apps can attach their own database/API spans to the same trace.
- **Sampling**: Controlled via `TRAEFIK_TRACING_SAMPLE_RATE` (`0.0` to `1.0`, default `1.0` = 100%) using OpenTelemetry's `ParentBased(TraceIDRatioBased)` sampler.
- **Enable Interactively**:
  ```bash
  make enable-tracing
  ```
  You can choose between:
  1. **Built-in Jaeger All-in-One Container** (`tracing` Docker Compose profile): Automatically starts `jaegertracing/all-in-one:latest` receiving traces over `http://jaeger:4318/v1/traces` and exposing the Jaeger Web UI on `127.0.0.1:16686` (access via SSH port forwarding: `ssh -L 16686:127.0.0.1:16686 user@your-server` and open `http://localhost:16686`).
  2. **External OTLP HTTP Collector**: Send traces to Grafana Tempo, SigNoz, Honeycomb, or an OpenTelemetry Collector at a custom URL.
- **Disable Tracing on Specific Routers**: Add the label `- "traefik.http.routers.<router-name>.observability.tracing=false"` to any container where you want to skip tracing.
- **Disable Tracing Globally**:
  ```bash
  make disable-tracing
  ```

---

## Optional Prometheus Metrics Collection (Traefik v3.7)

Traefik v3.7 exports rich time-series metrics in Prometheus format across four levels:
1. **Global Metrics**: Config reloads (`traefik_config_reloads_total`), open TCP/UDP connections (`traefik_open_connections`), and TLS certificate expiration timestamps (`traefik_tls_certs_not_after`).
2. **EntryPoint Metrics**: Total requests (`traefik_entrypoint_requests_total`), TLS handshakes by version/cipher (`traefik_entrypoint_requests_tls_total`), latency histograms (`traefik_entrypoint_request_duration_seconds_bucket`), and request/response byte counters.
3. **Router Metrics** *(enabled via `TRAEFIK_METRICS_ADD_ROUTERS_LABELS=true`)*: Per-router request counts, status codes, latency histograms (`traefik_router_request_duration_seconds_bucket`), and bandwidth.
4. **Service Metrics** *(enabled via `TRAEFIK_METRICS_ADD_SERVICES_LABELS=true`)*: Per-backend service request counts, retries (`traefik_service_retries_total`), healthcheck status (`traefik_service_server_up`), and latency histograms.

### Security & Architecture
- Rather than exposing `/metrics` publicly on port 443 (`websecure`), Traefik exposes `/metrics` on a dedicated internal entrypoint (`--entrypoints.metrics.address=:8082`) accessible **only inside the Docker network** (`http://traefik:8082/metrics`).
- When using the built-in Prometheus container (`metrics` Docker Compose profile), `./prometheus/prometheus.yml` automatically scrapes both:
  - **Traefik** (`traefik:8082/metrics`)
  - **CrowdSec Engine** (`crowdsec:6060/metrics` — tracks parsed log lines, active bans, alerts, and LAPI queries)

### Enable, View, and Disable Metrics
- **Enable Interactively**:
  ```bash
  make enable-metrics
  ```
  Choose between:
  1. **Built-in Prometheus Server Container** (`prom/prometheus:latest` with persistent `prometheus-data` volume and Web UI bound to `127.0.0.1:9090` — access via SSH tunnel: `ssh -L 9090:127.0.0.1:9090 user@your-server` and open `http://localhost:9090`).
  2. **Internal Endpoint Only**: Exposes `http://traefik:8082/metrics` inside `my_network` so your existing Prometheus/Grafana stack (Grafana dashboard ID `17346`) can scrape it.
- **Disable Metrics on Specific Routers**: Add the label `- "traefik.http.routers.<router-name>.observability.metrics=false"` to any container where you want to exclude metrics collection.
- **Disable Metrics Globally**:
  ```bash
  make disable-metrics
  ```




