# Hermes Agent — Docker Deployment Stack

Deploy [Hermes Agent](https://hermes-agent.nousresearch.com/) (by Nous Research) as a 24/7 background gateway container to automate DevOps tasks, manage your VPS fleet over SSH, and control Home Assistant, n8n, and Uptime Kuma via Telegram, Discord, or the web.

---

## 📋 Table of Contents

1. [Overview & Capabilities](#overview--capabilities)
2. [Prerequisites](#prerequisites)
3. [How to Get API Keys](#how-to-get-api-keys)
   - [Free LLM Providers](#1-free-llm-providers)
   - [Commercial / Frontier Providers](#2-commercial--frontier-providers)
   - [Telegram Bot Token](#3-telegram-bot-token-chat-gateway)
   - [Home Assistant Token](#4-home-assistant-token)
4. [Deployment Steps](#deployment-steps)
5. [Connecting to Homelab Services on `my_network`](#connecting-to-homelab-services-on-my_network)
6. [Managing Remote VPS Servers via SSH](#managing-remote-vps-servers-via-ssh)
7. [Useful Maintenance Commands](#useful-maintenance-commands)

---

## Overview & Capabilities

* **Self-Improving Memory:** Uses procedural skills (`agentskills.io`) that improve with each problem solved.
* **Always-On Remote Assistant:** Connects to Telegram or Discord so you can run commands, test web apps, or manage infrastructure from your phone.
* **Smart Home Control:** Native integration with Home Assistant to toggle lights, check sensors, or set natural-language cron alarms.
* **DevOps Automation:** Runs diagnostics over SSH, inspects Docker logs, and tests web APIs.
* **Low Footprint:** Runs comfortably on modest cloud instances (e.g. 1 OCPU / 1 vCPU with 2–6 GB RAM).

---

## Prerequisites

* Docker and Docker Compose v2 installed.
* At least one LLM API key (free options available below).
* (Optional) Telegram bot token to chat with Hermes on mobile.

---

## How to Get API Keys

Hermes is the agent runtime; it delegates heavy LLM inference to model providers via API.

### 1. Free LLM Providers

#### A. Groq (Recommended for Home Assistant)
Groq provides ultra-fast inference with sub-second response times, making it ideal for snappy smart home device control.
1. Sign up for free at [console.groq.com](https://console.groq.com).
2. Navigate to **API Keys** → **Create API Key**.
3. Copy the key (`gsk_...`) and set it as `GROQ_API_KEY` in your `.env`.
4. Supported free models: `llama-3.3-70b-versatile` or `llama-3.1-8b-instant`.

#### B. OpenRouter Free Models
OpenRouter offers completely free access to selected open-source models without requiring a credit card.
1. Sign up at [openrouter.ai](https://openrouter.ai).
2. Go to **Keys** → **Create Key**.
3. Set `OPENROUTER_API_KEY` in your `.env`.
4. You can use any model ending in `:free` (e.g., `meta-llama/llama-3.3-70b-instruct:free` or `google/gemini-2.0-flash-exp:free`).

#### C. Nous Portal Free Tier
1. Create a free account at [portal.nousresearch.com](https://portal.nousresearch.com).
2. Under your account dashboard, copy your API key and set `NOUS_API_KEY`.
3. The $0 Free Tier provides standard rate limits to open models.

---

### 2. Commercial / Frontier Providers

For complex coding, multi-turn reasoning, or autonomous subagent pipelines:
* **Anthropic (Claude 3.5 Sonnet):** Create a key at [console.anthropic.com](https://console.anthropic.com).
* **OpenAI (GPT-4o / GPT-4o-mini):** Create a key at [platform.openai.com](https://platform.openai.com).
* **DeepSeek:** Generate an API key at [platform.deepseek.com](https://platform.deepseek.com) (very low cost: ~$0.14-$0.28 / 1M tokens).

---

### 3. Telegram Bot Token (Chat Gateway)

To chat with Hermes from Telegram:
1. Open Telegram and search for `@BotFather`.
2. Send `/newbot` and follow the instructions to choose a name and username.
3. BotFather will provide an API token (e.g., `123456789:ABCdefGHIjklMNOpqrSTUvwxYZ`).
4. Set `TELEGRAM_BOT_TOKEN` in `.env`.
5. *(Important for Security)* Message `@userinfobot` on Telegram to get your numeric user ID, and add it to `TELEGRAM_ALLOWED_USERS` in `.env` so strangers cannot execute commands through your bot.

---

### 4. Home Assistant Token

1. In your Home Assistant UI, click your user profile (bottom left).
2. Go to the **Security** tab.
3. Scroll down to **Long-Lived Access Tokens** and click **Create Token**.
4. Set `HASS_URL` (e.g., `http://homeassistant:8123` if on the same Docker bridge network, or your LAN IP) and paste the token into `HASS_TOKEN` in `.env`.

---

## Deployment Steps

### 1. Clone & Prepare Environment

```bash
cd /path/to/Tool-box/hermes_agent

# Create environment file from template
cp .env.example .env
nano .env
```
Fill in your API keys and configuration in `.env`.

### 2. (Optional) Run the Initial Interactive Setup Wizard

If you want to configure providers and profiles interactively:

```bash
# Using Makefile
make setup

# Or directly with Docker:
mkdir -p data
docker run -it --rm -v $(pwd)/data:/opt/data nousresearch/hermes-agent setup
```

### 3. Start the Background Gateway

```bash
# Using Makefile
make up

# Or directly with Docker Compose:
docker compose up -d
```

### 4. Verify Logs

```bash
make logs
# Or: docker compose logs -f
```
You should see Hermes Gateway connect to your messaging platform and report that it is listening for messages.

---

## Connecting to Homelab Services on `my_network`

Because this stack joins `my_network` (shared across `Tool-box` services like `home_assistant`, `n8n`, and `uptime kuma`), Hermes can address other containers directly by container hostname:

* **Home Assistant:** `http://homeassistant:8123`
* **n8n:** `http://n8n:5678`
* **Uptime Kuma:** `http://uptime-kuma:3001`
* **AdGuard Home:** `http://adguard:80`

---

## Managing Remote VPS Servers via SSH

To give Hermes the ability to inspect and manage your remote VPS instances:

1. Generate a dedicated SSH keypair on your host:
   ```bash
   ssh-keygen -t ed25519 -f ./data/.ssh/id_ed25519 -N ""
   ```
2. Copy the public key to your target servers:
   ```bash
   ssh-copy-id -i ./data/.ssh/id_ed25519.pub user@vps-ip
   ```
3. Create an SSH config file at `./data/.ssh/config`:
   ```ssh-config
   Host staging
       HostName 198.51.100.10
       User deploy
       IdentityFile /opt/data/.ssh/id_ed25519

   Host prod
       HostName 198.51.100.20
       User admin
       IdentityFile /opt/data/.ssh/id_ed25519
   ```
4. Now you can tell Hermes from chat:
   > *"SSH into staging, check disk space, and verify if the latest docker compose containers are healthy."*

---

## Useful Maintenance Commands

| Command | Action |
| :--- | :--- |
| `make up` | Start Hermes Agent in the background |
| `make down` | Stop and remove the Hermes container |
| `make restart` | Restart the gateway |
| `make logs` | Follow real-time container output |
| `make cli` | Open the interactive Hermes CLI inside the container |
| `make shell` | Open a bash terminal inside the container |
| `docker compose pull && docker compose up -d` | Update to the latest Hermes image |
