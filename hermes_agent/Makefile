SHELL = /bin/bash

# Docker runs through sudo, the same way traefik/Makefile does it. Override with
# `make up SUDO=` when your user is already in the docker group.
SUDO ?= sudo

.PHONY: help check-docker init setup up down restart logs status shell wizard login report resolvers

# Color definitions
CLR_RESET   = \033[0m
CLR_BOLD    = \033[1m
CLR_RED     = \033[31m
CLR_GREEN   = \033[32m
CLR_YELLOW  = \033[33m
CLR_BLUE    = \033[34m
CLR_MAGENTA = \033[35m
CLR_CYAN    = \033[36m
CLR_WHITE   = \033[37m

TRAEFIK_DIR ?= ../traefik
TRAEFIK_COMPOSE = $(TRAEFIK_DIR)/docker-compose.yml

help:
	@printf "$(CLR_CYAN)$(CLR_BOLD)Hermes Agent Deployment Management$(CLR_RESET)\n"
	@printf "  $(CLR_GREEN)make setup$(CLR_RESET)      - Ask for missing values, start the container, print the report\n"
	@printf "  $(CLR_GREEN)make login$(CLR_RESET)      - Provider wizard in the container (OAuth providers, or paste a key)\n"
	@printf "  $(CLR_GREEN)make report$(CLR_RESET)     - Colored summary of the current deployment\n"
	@printf "  $(CLR_GREEN)make resolvers$(CLR_RESET)  - List certificate resolvers found in Traefik\n"
	@printf "  $(CLR_GREEN)make init$(CLR_RESET)       - Create .env, data/ and data/config.yaml, generate the session secret\n"
	@printf "  $(CLR_GREEN)make up$(CLR_RESET)         - Start the container (runs init first)\n"
	@printf "  $(CLR_GREEN)make down$(CLR_RESET)       - Stop and remove the container\n"
	@printf "  $(CLR_GREEN)make restart$(CLR_RESET)    - Restart the gateway\n"
	@printf "  $(CLR_GREEN)make logs$(CLR_RESET)       - Follow container output\n"
	@printf "  $(CLR_GREEN)make status$(CLR_RESET)     - Container and healthcheck state\n"
	@printf "  $(CLR_GREEN)make shell$(CLR_RESET)      - Bash inside the container\n"
	@printf "  $(CLR_GREEN)make wizard$(CLR_RESET)     - Interactive Hermes setup wizard (rewrites data/config.yaml)\n"
	@printf "\n  Docker commands run through $(CLR_WHITE)sudo$(CLR_RESET). Use $(CLR_WHITE)make up SUDO=$(CLR_RESET) if your user is in the docker group.\n"

# Create .env, the data directory, the seeded config and the session secret
init:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		printf "$(CLR_YELLOW)[*] Created .env from .env.example.$(CLR_RESET)\n"; \
	fi
	@mkdir -p data
	@if [ ! -f data/config.yaml ]; then \
		cp config.example.yaml data/config.yaml; \
		printf "$(CLR_GREEN)[✔] Seeded data/config.yaml.$(CLR_RESET)\n"; \
	fi
	@if ! grep -qE '^HERMES_DASHBOARD_SECRET=.+' .env; then \
		secret=$$(openssl rand -base64 32 2>/dev/null || head -c 32 /dev/urandom | base64); \
		secret=$$(printf '%s' "$$secret" | tr -d '\r\n'); \
		awk -v v="$$secret" ' \
			index($$0, "HERMES_DASHBOARD_SECRET=") == 1 { print "HERMES_DASHBOARD_SECRET=" v; found = 1; next } \
			{ print } \
			END { if (!found) print "HERMES_DASHBOARD_SECRET=" v } \
		' .env > .env.tmp && mv .env.tmp .env; \
		printf "$(CLR_GREEN)[✔] Generated the dashboard session secret.$(CLR_RESET)\n"; \
	fi

# Interactive configuration: only empty values are asked for, then start + report
setup: init
	@bash setup.sh
	@$(MAKE) --no-print-directory up
	@$(MAKE) --no-print-directory report

up: check-docker init
	$(SUDO) docker compose up -d

down: check-docker
	$(SUDO) docker compose down

restart: check-docker
	$(SUDO) docker compose restart

logs: check-docker
	$(SUDO) docker compose logs -f

status: check-docker
	$(SUDO) docker compose ps

shell: check-docker
	$(SUDO) docker compose exec -it hermes /bin/bash

# The upstream Hermes wizard. It writes into data/ and overwrites data/config.yaml
wizard: check-docker init
	$(SUDO) docker run -it --rm -v $(CURDIR)/data:/opt/data nousresearch/hermes-agent setup

# Provider login inside the container. OpenCode Go is API-key only, so this is
# for providers with a real login (ChatGPT/Codex device code, Claude Max, Qwen,
# MiniMax, xAI Grok); for opencode-go the wizard prompts for the API key.
login: check-docker init
	@printf "$(CLR_CYAN)[*] Opening the Hermes provider wizard. It writes data/config.yaml and data/.env.$(CLR_RESET)\n"
	$(SUDO) docker compose run --rm -it hermes model
	@bash setup.sh --sync-key
	@$(MAKE) --no-print-directory up
	@$(MAKE) --no-print-directory report

# Docker availability check shared by the container targets
check-docker:
	@if ! command -v docker >/dev/null 2>&1; then \
		printf "$(CLR_RED)[!] Docker is not installed or not in PATH.$(CLR_RESET)\n"; \
		printf "$(CLR_YELLOW)[*] Install it first: https://docs.docker.com/engine/install/$(CLR_RESET)\n"; \
		exit 1; \
	fi
	@if ! $(SUDO) docker compose version >/dev/null 2>&1; then \
		printf "$(CLR_RED)[!] '$(SUDO) docker compose' failed. Docker Compose v2 must work under sudo.$(CLR_RESET)\n"; \
		printf "$(CLR_YELLOW)[*] If your user is in the docker group, run: make <target> SUDO=$(CLR_RESET)\n"; \
		exit 1; \
	fi

# Certificate resolvers defined in the Traefik compose file
resolvers:	@if [ ! -f "$(TRAEFIK_COMPOSE)" ]; then \
		printf "$(CLR_RED)[!] %s not found.$(CLR_RESET)\n" "$(TRAEFIK_COMPOSE)"; \
		exit 1; \
	fi; \
	printf "$(CLR_CYAN)[*] Resolvers in %s:$(CLR_RESET)\n" "$(TRAEFIK_COMPOSE)"; \
	sed -nE 's/.*certificatesresolvers\.([A-Za-z0-9_]+)\.acme\..*/\1/p' "$(TRAEFIK_COMPOSE)" | awk '!seen[$$0]++' | while read -r name; do \
		[ -z "$$name" ] && continue; \
		if grep -qE "certificatesresolvers\.$$name\.acme\.dnschallenge\." "$(TRAEFIK_COMPOSE)"; then \
			kind="DNS-01"; \
		else \
			kind="HTTP-01"; \
		fi; \
		printf "  $(CLR_WHITE)%-22s$(CLR_RESET) %s\n" "$$name" "$$kind"; \
	done

# Color formatted status report box
report: init
	@DOM=$$(grep -E '^DOMAIN=' .env 2>/dev/null | cut -d '=' -f2-); \
	TZ_VAL=$$(grep -E '^TZ=' .env 2>/dev/null | cut -d '=' -f2-); \
	RES=$$(grep -E '^CERT_RESOLVER=' .env 2>/dev/null | cut -d '=' -f2-); \
	DUSER=$$(grep -E '^HERMES_DASHBOARD_USERNAME=' .env 2>/dev/null | cut -d '=' -f2-); \
	DPASS=$$(grep -E '^HERMES_DASHBOARD_PASSWORD=' .env 2>/dev/null | cut -d '=' -f2-); \
	DSEC=$$(grep -E '^HERMES_DASHBOARD_SECRET=' .env 2>/dev/null | cut -d '=' -f2-); \
	TGBOT=$$(grep -E '^TELEGRAM_BOT_TOKEN=' .env 2>/dev/null | cut -d '=' -f2-); \
	TGUSERS=$$(grep -E '^TELEGRAM_ALLOWED_USERS=' .env 2>/dev/null | cut -d '=' -f2-); \
	MODEL=$$(awk '/^model:/{m=1;next} m&&/^[^[:space:]#]/{m=0} m&&$$1=="default:"{print $$2;exit}' data/config.yaml 2>/dev/null); \
	PROVIDER=$$(awk '/^model:/{m=1;next} m&&/^[^[:space:]#]/{m=0} m&&$$1=="provider:"{print $$2;exit}' data/config.yaml 2>/dev/null); \
	short() { printf '%.45s' "$$1"; }; \
	[ -z "$$DOM" ] && DOM_STATUS="Not set" || DOM_STATUS="https://$$DOM"; \
	if [ -z "$$RES" ]; then \
		RES_STATUS="Not set"; \
	elif [ ! -f "$(TRAEFIK_COMPOSE)" ]; then \
		RES_STATUS="$$RES (traefik compose missing)"; \
	elif grep -qE "certificatesresolvers\.$$RES\.acme\.dnschallenge\." "$(TRAEFIK_COMPOSE)"; then \
		RES_STATUS="$$RES (DNS-01)"; \
	else \
		RES_STATUS="$$RES (HTTP-01)"; \
	fi; \
	TLS_CRED_STATUS="-"; \
	if [ -n "$$RES" ] && [ -f "$(TRAEFIK_COMPOSE)" ]; then \
		if grep -qE "certificatesresolvers\.$$RES\.acme\.dnschallenge\." "$(TRAEFIK_COMPOSE)"; then \
			if grep -qE '^CF_DNS_API_TOKEN=.+' "$(TRAEFIK_DIR)/.env" 2>/dev/null; then \
				TLS_CRED_STATUS="Cloudflare token present"; \
			else \
				TLS_CRED_STATUS="Cloudflare token missing - TLS will fail"; \
			fi; \
		else \
			TLS_CRED_STATUS="Not needed (HTTP-01)"; \
		fi; \
	fi; \
	[ -n "$$DUSER" ] && [ -n "$$DPASS" ] && AUTH_STATUS="$$DUSER / password set" || AUTH_STATUS="Incomplete - dashboard will refuse to start"; \
	[ "$$DPASS" = "change-me" ] && AUTH_STATUS="$$DUSER / default password - change it"; \
	[ -n "$$DSEC" ] && SEC_STATUS="Configured" || SEC_STATUS="Missing - logins drop on restart"; \
	KEY_STATUS="Missing - no model access"; \
	if grep -qE '^OPENCODE_GO_API_KEY=.+' .env 2>/dev/null; then \
		KEY_STATUS="Configured (.env)"; \
	elif grep -qE '^OPENCODE_GO_API_KEY=.+' data/.env 2>/dev/null; then \
		KEY_STATUS="Configured (data/.env)"; \
	fi; \
	[ -n "$$TGBOT" ] && TG_STATUS="Enabled" || TG_STATUS="Disabled (no token)"; \
	if [ -z "$$TGUSERS" ]; then \
		TG_USERS_STATUS="None - bot rejects every sender"; \
	else \
		TG_USERS_STATUS="$$(printf '%s' "$$TGUSERS" | tr ',' '\n' | grep -c .) allowed user(s)"; \
	fi; \
	MODEL_STATUS="$${MODEL:-unset} $([ -n "$$MODEL" ] && [ "$$MODEL" = "deepseek-v4.1-flash" ] && printf '(V4.1 Flash 1017)')"; \
	PROVIDER_STATUS="$${PROVIDER:-unset}"; \
	[ -z "$$TZ_VAL" ] && TZ_VAL="UTC"; \
	if [ -f "$(TRAEFIK_COMPOSE)" ]; then TRAEFIK_STATUS="Found"; else TRAEFIK_STATUS="Not found"; fi; \
	CT_STATUS="Stopped"; \
	HEALTH_STATUS="-"; \
	if command -v docker >/dev/null 2>&1; then \
		CID=$$($(SUDO) docker compose ps -q hermes 2>/dev/null); \
		if [ -n "$$CID" ]; then \
			CT_STATUS=$$($(SUDO) docker inspect -f '{{.State.Status}}' "$$CID" 2>/dev/null); \
			HEALTH_STATUS=$$($(SUDO) docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$$CID" 2>/dev/null); \
		fi; \
	fi; \
	[ -d data ] && DATA_STATUS="$$(du -sh data 2>/dev/null | cut -f1)" || DATA_STATUS="missing"; \
	row() { \
		printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "$$1" "$$(short "$$2")"; \
	}; \
	printf '\n'; \
	printf "$(CLR_CYAN)╔══════════════════════════════════════════════════════════════════════════════╗$(CLR_RESET)\n"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)                  $(CLR_BOLD)$(CLR_WHITE)HERMES AGENT DEPLOYMENT REPORT$(CLR_RESET)                       $(CLR_CYAN)║$(CLR_RESET)\n"; \
	printf "$(CLR_CYAN)╠══════════════════════════════════════════════════════════════════════════════╣$(CLR_RESET)\n"; \
	row "Dashboard URL" "$$DOM_STATUS"; \
	row "TLS Resolver" "$$RES_STATUS"; \
	row "TLS Credentials" "$$TLS_CRED_STATUS"; \
	row "Dashboard Login" "$$AUTH_STATUS"; \
	row "Session Secret" "$$SEC_STATUS"; \
	row "Model" "$$MODEL_STATUS"; \
	row "Provider" "$$PROVIDER_STATUS"; \
	row "OpenCode Go Key" "$$KEY_STATUS"; \
	row "Telegram" "$$TG_STATUS"; \
	row "Telegram Allowlist" "$$TG_USERS_STATUS"; \
	row "Timezone" "$$TZ_VAL"; \
	row "Container" "$$CT_STATUS"; \
	row "Healthcheck" "$$HEALTH_STATUS"; \
	row "Data Directory" "$$DATA_STATUS"; \
	row "Traefik Compose" "$$TRAEFIK_STATUS"; \
	printf "$(CLR_CYAN)╚══════════════════════════════════════════════════════════════════════════════╝$(CLR_RESET)\n"; \
	printf '\n'
