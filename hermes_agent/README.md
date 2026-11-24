# Hermes Agent — Docker Deployment Stack

Deploys [Hermes Agent](https://hermes-agent.nousresearch.com/) (Nous Research) on a VPS as a single container. It answers on Telegram, serves its web dashboard behind Traefik at your domain, and runs on an OpenCode Go subscription.

Everything it needs is three things: an OpenCode Go API key, a domain, and a Telegram bot token. All other provider, Home Assistant and Discord settings from the previous version are gone.

---

## What runs

| Piece | Where | Port |
| :--- | :--- | :--- |
| Gateway (`gateway run`) | container | — |
| Web dashboard + browser chat | container, published by Traefik | `9119` |
| Telegram bot | outbound long polling | — |
| State, config, keys | host `./data` | — |

The dashboard is the only port Traefik touches. The OpenAI-compatible API on `8642` stays off; see [Optional: OpenAI-compatible API](#optional-openai-compatible-api) if you want it.

---

## Prerequisites

- Docker and Docker Compose v2, usable through `sudo`.
- Traefik running from `traefik/docker-compose.yml`, sharing the `my_network` Docker network.
- A DNS record for your domain pointing at the VPS.
- An OpenCode Go subscription key from [opencode.ai/auth](https://opencode.ai/auth).
- A Telegram bot token from [@BotFather](https://t.me/BotFather).

---

## Setup

Run this on the VPS, in a bash shell; the make targets use bash, the same way `traefik/Makefile` does.

```bash
cd hermes_agent
make setup
```

It asks only for values that are still empty, so running it again is safe: anything already in `.env` is kept and reported as `[✔] already set`.

| Question | Notes |
| :--- | :--- |
| Timezone | Defaults to `Asia/Tehran`, stored in `TZ` |
| Hostname | Required. The dashboard refuses to bind publicly without one |
| TLS resolver | Read live from `../traefik/docker-compose.yml`; `cloudflare_resolver` (DNS-01) is preselected as the default |
| Dashboard username and password | Required. The dashboard refuses public binds without a login provider; there is no default username |
| OpenCode Go API key | From [opencode.ai/auth](https://opencode.ai/auth) |
| Telegram bot token and user IDs | Optional; leaving the token blank keeps the bot off |
| Model | Stays `deepseek-v4.1-flash` unless you type another model ID |

`make init` runs first. It creates `.env`, creates `data/`, seeds `data/config.yaml` with `provider: opencode-go`, and generates `HERMES_DASHBOARD_SECRET` if it is empty, so logins survive restarts.

Then it starts the container and prints the report:

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                  HERMES AGENT DEPLOYMENT REPORT                              ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Dashboard URL            : https://hermes.example.com                       ║
...
```

`make report` prints the same box at any time: domain, resolver and its challenge type, login state, secret state, model, provider, API key, Telegram, timezone, container and healthcheck state, data size, and whether the Traefik compose file was found.

`make resolvers` lists what Traefik defines on its own. If Traefik lives somewhere else, point at it with `make setup TRAEFIK_DIR=/srv/traefik`.

All Docker commands run through `sudo`, the same way `traefik/Makefile` does. Run `make` as your normal user, never as `sudo make`: only the Docker calls need root, and a root-run `make` would leave `.env` and `data/` owned by root.

If your user is in the `docker` group, drop the sudo per call:

```bash
make up SUDO=
```

Check the service after setup:

```bash
make logs
make status              # healthcheck hits the dashboard on 9119
```

Open `https://<your domain>` and sign in. Message your Telegram bot to confirm it replies.

---

## Inside `data/`

`./data` is the Hermes home (`/opt/data` in the container). It holds `config.yaml`, `.env`, sessions, memory, logs and skills. It is gitignored because it stores your API keys in clear text.

The container runs as root, so anything it writes into `data/` belongs to root. Read or edit it with `sudo`, or take ownership once with:

```bash
sudo chown -R "$USER" data
```

Back it up with the whole directory:

```bash
tar -czf hermes-data-$(date +%F).tar.gz -C hermes_agent data
```

---

## Changing the model

`data/config.yaml` is the source of truth for provider and model:

```yaml
model:
  provider: opencode-go
  default: deepseek-v4.1-flash
```

The seeded value is `deepseek-v4.1-flash`, which the Go catalog lists as **DeepSeek V4.1 Flash 1017**. Any model ID from [the Go model list](https://opencode.ai/docs/go) works, for example `glm-5.3`, `glm-5.3-flash`, `kimi-k3`, `qwen3.8-max`, `grok-4.7`, `claude-haiku-5-5`.

Three ways to switch, pick one:

```bash
# 1. edit the file on the host, then restart
nano data/config.yaml
make restart

# 2. inside a chat (dashboard or Telegram), this session only
/model opencode-go/glm-5.3-flash
# ...or write it to config with a trailing --global
/model opencode-go/kimi-k3 --global

# 3. interactive picker with the model list of the provider
make cli
hermes model
```

Hermes sends its own `x-opencode-session` header on every request, which the Go plan requires from non-OpenCode clients. It has been validated against Go, so no proxy or extra header wiring is needed.

If the model ID is wrong, the first chat fails with a provider error instead of answering. Run `hermes model` and pick a model from the list it fetches.

---

## Signing in to a provider

OpenCode Go has no OAuth flow. Hermes registers `opencode-go` as an API-key provider and reads `OPENCODE_GO_API_KEY` as its only credential; OpenCode's own Go docs also hand you a key from the console rather than a login. So on this stack the key **is** the sign-in, and `make setup` collects it.

For the providers that do have a real login, `make login` opens the provider wizard inside the container:

```bash
make login        # docker compose run --rm -it hermes model
```

| Provider | Flow | Works from this VPS |
| :--- | :--- | :--- |
| ChatGPT / Codex | device code | Yes, open the printed URL anywhere |
| Claude (Pro/Max) | paste the code from the browser | Yes |
| xAI Grok | device code | Yes |
| Qwen, MiniMax, Nous Portal | device code | Yes |
| opencode-go | prompts for the API key | Yes, same key as `make setup` |
| Any provider with a `127.0.0.1` callback | loopback redirect | Only with an SSH tunnel |

If the wizard says it is waiting on `127.0.0.1:<port>`, forward that port from your laptop before opening the URL:

```bash
ssh -N -L <port>:127.0.0.1:<port> user@your-vps
```

The wizard writes the provider into `data/config.yaml` and its secrets into `data/.env`. `make login` then copies an OpenCode Go key it finds into `.env` and recreates the container so the gateway uses the new provider.

### What the API key may do

Console keys carry a permission scope. Hermes only lists models and calls them, so the smallest working key is:

- Create a **personal API key** in Console at **Account → Personal API keys → Add API key**, or a **service account key** under **Settings → Service accounts** when the machine, not a person, should own the usage.
- Set **Permissions: Restricted** with **Models: Request**. `Request` lists and calls models; `Read only` can list them but not call, so chat fails with a permission error.
- Leave Usage, Budgets, Members, Providers, Billing, Workspace settings, SSO, Service accounts and "This account's API keys" at **None**. Hermes calls no admin endpoint.

A member can only create model-only keys; owners and admins choose the scope. Each key belongs to one workspace, is shown once, and can carry an expiration — an expired key cannot be renewed, so put a fresh one in `.env`. During a Go subscription, usage inside the plan is billed as `go` and does not consume budgets.

---

## Web access and login

Traefik terminates TLS on `websecure` and forwards to `9119`, where the dashboard serves the status pages, config editor, sessions, cron jobs, logs and a full browser chat tab.

`HERMES_DASHBOARD_PUBLIC_URL=https://${DOMAIN}` is set in the compose file for two reasons:

- The dashboard trusts `https://<your domain>` as the allowed `Host` header. Without it the server's host check rejects requests arriving through a proxy.
- Login redirects and cookies are built from that URL.

The dashboard refuses to start on a public address without a login provider, so `HERMES_DASHBOARD_USERNAME` and `HERMES_DASHBOARD_PASSWORD` are required. `HERMES_DASHBOARD_SECRET` signs the session cookie; `make init` generates it once and keeps it, otherwise every restart signs you out.

Traefik reaches the dashboard from another container, so it is not on the trusted-proxy list by default. That only affects the `Secure` flag on the cookie. To fix it, uncomment the `dashboard.trusted_proxies` block in `config.example.yaml`, put this network's subnet there, and `make restart`.

---

## Telegram

1. Create the bot with `@BotFather` (`/newbot`) and copy the token into `TELEGRAM_BOT_TOKEN`.
2. Message `@userinfobot` and put your numeric ID in `TELEGRAM_ALLOWED_USERS`.

Hermes enables Telegram automatically once the token is present; no `config.yaml` entry is needed. With an allowlist set, everyone else is ignored, which matters because the bot can run shell commands.

Useful chat commands: `/new`, `/model`, `/status`, `/stop`, `/sethome` (marks this chat as the target for scheduled jobs).

Group chats need extra care: Telegram's privacy mode hides ordinary messages from bots by default. Either promote the bot to group admin, or turn privacy off in BotFather and re-add the bot to the group.

---

## Optional: OpenAI-compatible API

The dashboard covers normal use. If you also want Open WebUI, LobeChat or another OpenAI-compatible client to drive Hermes, enable the API server:

```yaml
# add to the environment: block
      - API_SERVER_ENABLED=true
      - API_SERVER_HOST=0.0.0.0
      - API_SERVER_KEY=${HERMES_API_KEY}
```

and add a second router in the labels:

```yaml
      - "traefik.http.routers.hermes-api.rule=Host(`api.${DOMAIN}`)"
      - "traefik.http.routers.hermes-api.entrypoints=websecure"
      - "traefik.http.routers.hermes-api.tls.certresolver=${CERT_RESOLVER:-myresolver}"
      - "traefik.http.services.hermes-api.loadbalancer.server.port=8642"
```

The client URL is `https://api.$DOMAIN/v1`, with `HERMES_API_KEY` as the bearer token.

---

## Troubleshooting

### 401 after replacing the API key

The Go endpoint answers a bad credential with `401 {"error":{"type":"authentication_error","message":"Invalid credential"}}`. The model list is public, so Hermes starts and lists models fine and only fails when it sends a message. Check in this order:

1. **The container still holds the old key.** `docker compose restart` keeps the old environment, so a revoked key keeps being sent. Recreate the container instead:

   ```bash
   make restart        # docker compose up -d --force-recreate
   ```

2. **A copy of the old key lives in `data/.env`.** `make login` and the dashboard API Keys page write there, and Hermes reads that file too. Delete the `OPENCODE_GO_API_KEY=` line or set it to the new key.

3. **The key itself.** It is shown once, so a truncated paste, a revoked key, an expired key, or a key created in a different workspace all give 401. A valid key that is not allowed to use the model gives **403**, not 401.

`make check-key` checks all three at once: it prints the key prefix from `.env`, warns about whitespace and CRLF, reports a mismatched `data/.env`, compares the running container's environment, then calls the Go endpoint with the configured model and explains the status code.

---

## Maintenance

| Command | Action |
| :--- | :--- |
| `make setup` | Ask for missing values, start the container, print the report |
| `make login` | Provider wizard in the container: OAuth logins, or paste the Go key |
| `make report` | Print the deployment report box |
| `make resolvers` | List the certificate resolvers Traefik defines |
| `make init` | Create `.env`, `data/`, `data/config.yaml`, generate the session secret |
| `make up` | Create `data/` if missing, then start |
| `make down` | Stop and remove the container |
| `make restart` | Recreate the container so `.env` and config changes apply |
| `make check-key` | Test the key in `.env` against the OpenCode Go endpoint |
| `make logs` | Follow container output |
| `make status` | Container and healthcheck state |
| `make cli` | Hermes CLI inside the container |
| `make shell` | Bash inside the container |
| `make wizard` | Upstream Hermes setup wizard; it overwrites `data/config.yaml` |

Update to the newest image:

```bash
docker compose pull && docker compose up -d
```

Hermes restarts itself on crash inside the container (s6 supervises the gateway and the dashboard), and `restart: unless-stopped` covers reboots of the VPS.
