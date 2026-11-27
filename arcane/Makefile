SHELL = /bin/bash

.DEFAULT_GOAL := help

.PHONY: help all check-docker init-env fix-ownership ensure-secret setup-secret setup-domain \
	setup-proxies setup-all install-arcane deploy down restart status logs health \
	password update backup report reload-if-running clean clean-all

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

# Optional: force sudo for every privileged operation: make deploy SUDO=sudo
SUDO ?=
# Docker needs root when the current user is not in the docker group. Detect it
# once so plain `make deploy` works on a docker-group host and still works elsewhere.
DOCKER_SUDO := $(if $(SUDO),$(SUDO),$(shell if docker info >/dev/null 2>&1; then :; elif command -v sudo >/dev/null 2>&1; then echo sudo; fi))
DOCKER = $(DOCKER_SUDO) docker
COMPOSE = $(DOCKER) compose
# Bind mounts under /srv usually belong to root. These commands try unprivileged
# first and escalate only when the current user does not have permission.
FS_SUDO := $(if $(SUDO),$(SUDO),sudo)
CONTAINER ?= arcane
ENV_FILE ?= .env

# Load configuration written by the setup targets. Do not `export` these: an
# empty ARCANE_ENCRYPTION_KEY parsed before setup-secret runs would override the
# value that setup-secret writes to .env for docker compose.
-include .env

# Fallbacks used before .env exists (also documented in .env.example)
ARCANE_IMAGE ?= ghcr.io/getarcaneapp/manager:latest
ARCANE_CONTAINER_NAME ?= arcane
ARCANE_DOMAIN ?= arcane.example.com
ARCANE_APP_URL ?= https://arcane.example.com
ARCANE_PORT ?= 3552
ARCANE_BIND ?= 127.0.0.1
ARCANE_DATA_DIR ?= ./data
ARCANE_PROJECTS_DIR ?= ./projects
ARCANE_BUILDS_DIR ?= ./builds
ARCANE_BACKUPS_DIR ?= ./backups
ARCANE_TRUSTED_PROXIES ?= 172.18.0.0/16
DOCKER_NETWORK ?= my_network
TRAEFIK_ENTRYPOINT ?= websecure
TRAEFIK_CERTRESOLVER ?= cloudflare_resolver

help:
	@echo -e "$(CLR_CYAN)$(CLR_BOLD)Arcane Setup Management$(CLR_RESET)"
	@echo -e "  $(CLR_GREEN)make install-arcane$(CLR_RESET)     - Run setup and deploy Arcane end-to-end"
	@echo -e "  $(CLR_GREEN)make setup-all$(CLR_RESET)         - Configure .env, key, domain and trusted proxies only"
	@echo -e "  $(CLR_GREEN)make setup-secret$(CLR_RESET)      - Generate (or rotate) the Arcane encryption key"
	@echo -e "  $(CLR_GREEN)make setup-domain$(CLR_RESET)      - Set public domain, app URL, entrypoint and TLS resolver"
	@echo -e "  $(CLR_GREEN)make setup-proxies$(CLR_RESET)     - Detect the Docker network CIDR for ARCANE_TRUSTED_PROXIES"
	@echo -e "  $(CLR_GREEN)make fix-ownership$(CLR_RESET)     - Recursively chown bind mounts to PUID:PGID (escalates if needed)"
	@echo -e "  $(CLR_GREEN)make deploy$(CLR_RESET)            - Create bind-mount directories and start the stack"
	@echo -e "  $(CLR_GREEN)make down$(CLR_RESET)              - Stop and remove the container (data is kept)"
	@echo -e "  $(CLR_GREEN)make restart$(CLR_RESET)           - Recreate the container to apply configuration changes"
	@echo -e "  $(CLR_GREEN)make status$(CLR_RESET)            - Show container status and health"
	@echo -e "  $(CLR_GREEN)make health$(CLR_RESET)            - Run Arcane's built-in health command"
	@echo -e "  $(CLR_GREEN)make logs$(CLR_RESET)              - Follow container logs"
	@echo -e "  $(CLR_GREEN)make password$(CLR_RESET)          - Print the first-run admin password"
	@echo -e "  $(CLR_GREEN)make update$(CLR_RESET)            - Pull the latest image and recreate the container"
	@echo -e "  $(CLR_GREEN)make backup$(CLR_RESET)            - Tar ./data into the bind-mounted backups folder"
	@echo -e "  $(CLR_GREEN)make report$(CLR_RESET)            - Display a colored summary of the current configuration"
	@echo -e "  $(CLR_GREEN)make clean$(CLR_RESET)             - Stop the stack and delete ./data (asks for confirmation)"
	@echo -e "  $(CLR_GREEN)make clean-all$(CLR_RESET)         - Also delete projects, builds and backups"
	@echo -e ""
	@echo -e "  $(CLR_YELLOW)Docker uses sudo automatically when the user is not in the docker group.$(CLR_RESET)"
	@echo -e "  $(CLR_YELLOW)Bind-mount paths under /srv escalate with sudo only on permission errors.$(CLR_RESET)"
	@echo -e "  $(CLR_YELLOW)Force sudo everywhere with: make <target> SUDO=sudo$(CLR_RESET)"

all: deploy

# Docker availability verification
check-docker:
	@if ! command -v docker >/dev/null 2>&1; then \
		echo -e "$(CLR_RED)[!] Docker is not installed or not in PATH.$(CLR_RESET)"; \
		echo -e "$(CLR_YELLOW)[*] Please install Docker first: https://docs.docker.com/engine/install/$(CLR_RESET)"; \
		exit 1; \
	fi
	@if ! $(DOCKER) compose version >/dev/null 2>&1; then \
		echo -e "$(CLR_RED)[!] The Docker Compose plugin is not available.$(CLR_RESET)"; \
		echo -e "$(CLR_YELLOW)[*] Install it: https://docs.docker.com/compose/install/linux/$(CLR_RESET)"; \
		exit 1; \
	fi

# Ensure .env exists and create the bind-mount directories. Commands escalate
# with sudo only when the path is not writable, which is normal for /srv.
init-env:
	@if [ ! -f $(ENV_FILE) ]; then \
		echo -e "$(CLR_YELLOW)[*] Creating $(ENV_FILE) from .env.example...$(CLR_RESET)"; \
		if ! cp .env.example $(ENV_FILE) 2>/dev/null; then \
			echo -e "$(CLR_YELLOW)[*] Escalating to create $(ENV_FILE)...$(CLR_RESET)"; \
			$(FS_SUDO) cp .env.example $(ENV_FILE); \
			$(FS_SUDO) chown "$$(id -u):$$(id -g)" $(ENV_FILE); \
		fi; \
	fi
	@if [ -f $(ENV_FILE) ] && [ ! -w $(ENV_FILE) ]; then \
		echo -e "$(CLR_YELLOW)[*] Taking ownership of $(ENV_FILE)...$(CLR_RESET)"; \
		$(FS_SUDO) chown "$$(id -u):$$(id -g)" $(ENV_FILE); \
	fi
	@echo -e "$(CLR_CYAN)[*] Creating bind-mount directories...$(CLR_RESET)"
	@data_dir=$$(grep -E '^ARCANE_DATA_DIR=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	data_dir=$${data_dir:-$(ARCANE_DATA_DIR)}; \
	projects_dir=$$(grep -E '^ARCANE_PROJECTS_DIR=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	projects_dir=$${projects_dir:-$(ARCANE_PROJECTS_DIR)}; \
	builds_dir=$$(grep -E '^ARCANE_BUILDS_DIR=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	builds_dir=$${builds_dir:-$(ARCANE_BUILDS_DIR)}; \
	backups_dir=$$(grep -E '^ARCANE_BACKUPS_DIR=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	backups_dir=$${backups_dir:-$(ARCANE_BACKUPS_DIR)}; \
	for d in "$$data_dir" "$$projects_dir" "$$builds_dir" "$$backups_dir"; do \
		if ! mkdir -p "$$d" 2>/dev/null; then \
			echo -e "$(CLR_YELLOW)[*] Escalating to create $$d...$(CLR_RESET)"; \
			$(FS_SUDO) mkdir -p "$$d"; \
		fi; \
	done; \
	puid=$$(grep -E '^PUID=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	pgid=$$(grep -E '^PGID=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	puid=$${puid:-65532}; \
	pgid=$${pgid:-65532}; \
	for d in "$$data_dir" "$$projects_dir" "$$builds_dir" "$$backups_dir"; do \
		owner=$$(stat -c '%u:%g' "$$d" 2>/dev/null || stat -f '%u:%g' "$$d" 2>/dev/null); \
		if [ "$$owner" != "$$puid:$$pgid" ]; then \
			if ! chown "$$puid:$$pgid" "$$d" 2>/dev/null; then \
				$(FS_SUDO) chown "$$puid:$$pgid" "$$d"; \
			fi; \
		fi; \
	done; \
	echo -e "$(CLR_GREEN)[✔] Ready: $$data_dir, $$projects_dir, $$builds_dir, $$backups_dir$(CLR_RESET)"

# Recursively align ownership of existing bind-mount contents (after a migration)
fix-ownership: init-env
	@puid=$$(grep -E '^PUID=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	pgid=$$(grep -E '^PGID=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	puid=$${puid:-65532}; \
	pgid=$${pgid:-65532}; \
	for d in "$(ARCANE_DATA_DIR)" "$(ARCANE_PROJECTS_DIR)" "$(ARCANE_BUILDS_DIR)" "$(ARCANE_BACKUPS_DIR)"; do \
		echo -e "$(CLR_YELLOW)[*] chown -R $$puid:$$pgid $$d$(CLR_RESET)"; \
		if ! chown -R "$$puid:$$pgid" "$$d" 2>/dev/null; then \
			$(FS_SUDO) chown -R "$$puid:$$pgid" "$$d"; \
		fi; \
	done; \
	echo -e "$(CLR_GREEN)[✔] Ownership updated.$(CLR_RESET)"

# Generate the encryption key silently when it is missing (used by deploy)
ensure-secret: init-env
	@key=$$(grep -E '^ARCANE_ENCRYPTION_KEY=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	if [ -z "$$key" ]; then \
		echo -e "$(CLR_YELLOW)[*] ARCANE_ENCRYPTION_KEY is missing. Generating one...$(CLR_RESET)"; \
		raw=$$($(DOCKER) run --rm $(ARCANE_IMAGE) /app/arcane generate secret 2>/dev/null | tr -d '\r'); \
		new_key=$$(echo "$$raw" | sed -n 's/^ARCANE_ENCRYPTION_KEY=//p' | tail -n 1); \
		[ -n "$$new_key" ] || new_key=$$(echo "$$raw" | tail -n 1); \
		[ -n "$$new_key" ] || new_key=$$(openssl rand -hex 32 2>/dev/null); \
		if [ -z "$$new_key" ]; then \
			echo -e "$(CLR_RED)[!] Could not generate a key. Ensure Docker works or install OpenSSL.$(CLR_RESET)"; \
			exit 1; \
		fi; \
		if grep -q '^ARCANE_ENCRYPTION_KEY=' $(ENV_FILE); then \
			sed -i "s|^ARCANE_ENCRYPTION_KEY=.*|ARCANE_ENCRYPTION_KEY=$$new_key|" $(ENV_FILE); \
		else \
			echo "ARCANE_ENCRYPTION_KEY=$$new_key" >> $(ENV_FILE); \
		fi; \
		echo -e "$(CLR_GREEN)[✔] Encryption key generated and saved to $(ENV_FILE).$(CLR_RESET)"; \
	fi

# Generate or rotate the encryption key interactively
setup-secret: init-env
	@key=$$(grep -E '^ARCANE_ENCRYPTION_KEY=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	if [ -n "$$key" ]; then \
		echo -e "$(CLR_GREEN)[✔] ARCANE_ENCRYPTION_KEY already configured.$(CLR_RESET)"; \
		read -p "Regenerate it? Existing encrypted secrets will become unreadable [y/N]: " reconf </dev/tty; \
		if [ "$$reconf" != "y" ] && [ "$$reconf" != "Y" ]; then \
			exit 0; \
		fi; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Generating Arcane encryption key...$(CLR_RESET)"; \
	raw=$$($(DOCKER) run --rm $(ARCANE_IMAGE) /app/arcane generate secret 2>/dev/null | tr -d '\r'); \
	new_key=$$(echo "$$raw" | sed -n 's/^ARCANE_ENCRYPTION_KEY=//p' | tail -n 1); \
	[ -n "$$new_key" ] || new_key=$$(echo "$$raw" | tail -n 1); \
	[ -n "$$new_key" ] || new_key=$$(openssl rand -hex 32 2>/dev/null); \
	if [ -z "$$new_key" ]; then \
		echo -e "$(CLR_RED)[!] Could not generate a key. Ensure Docker works or install OpenSSL.$(CLR_RESET)"; \
		exit 1; \
	fi; \
	if grep -q '^ARCANE_ENCRYPTION_KEY=' $(ENV_FILE); then \
		sed -i "s|^ARCANE_ENCRYPTION_KEY=.*|ARCANE_ENCRYPTION_KEY=$$new_key|" $(ENV_FILE); \
	else \
		echo "ARCANE_ENCRYPTION_KEY=$$new_key" >> $(ENV_FILE); \
	fi; \
	echo -e "$(CLR_GREEN)[✔] Encryption key saved to $(ENV_FILE).$(CLR_RESET)"
	@$(MAKE) --no-print-directory reload-if-running

# Public domain, app URL and Traefik routing
setup-domain: init-env
	@set_var() { if grep -q "^$$1=" $(ENV_FILE); then sed -i "s|^$$1=.*|$$1=$$2|" $(ENV_FILE); else echo "$$1=$$2" >> $(ENV_FILE); fi; }; \
	domain=$$(grep -E '^ARCANE_DOMAIN=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	if [ -n "$$domain" ] && [ "$$domain" != "arcane.example.com" ]; then \
		echo -e "$(CLR_GREEN)[✔] Domain already configured ($$domain).$(CLR_RESET)"; \
		read -p "Do you want to change the domain/TLS settings? [y/N]: " reconf </dev/tty; \
		if [ "$$reconf" != "y" ] && [ "$$reconf" != "Y" ]; then \
			exit 0; \
		fi; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Arcane Domain & TLS Configuration:$(CLR_RESET)"; \
	read -p "Enter the public domain (e.g. arcane.yourdomain.com): " domain </dev/tty; \
	if [ -z "$$domain" ]; then \
		echo -e "$(CLR_RED)[!] Domain cannot be empty.$(CLR_RESET)"; \
		exit 1; \
	fi; \
	domain=$$(echo "$$domain" | sed -E 's|^https?://||; s|/.*$$||'); \
	set_var ARCANE_DOMAIN "$$domain"; \
	set_var ARCANE_APP_URL "https://$$domain"; \
	echo "Select certificate resolver for Arcane:"; \
	echo "  1) Let's Encrypt HTTP-01 challenge (myresolver)"; \
	echo "  2) Cloudflare DNS-01 challenge (cloudflare_resolver) [default]"; \
	read -p "Choose [1/2, default 2]: " resolver_choice </dev/tty; \
	if [ "$$resolver_choice" = "1" ]; then \
		set_var TRAEFIK_CERTRESOLVER "myresolver"; \
		echo -e "$(CLR_GREEN)[✔] Resolver set to 'myresolver'.$(CLR_RESET)"; \
	else \
		set_var TRAEFIK_CERTRESOLVER "cloudflare_resolver"; \
		echo -e "$(CLR_GREEN)[✔] Resolver set to 'cloudflare_resolver'.$(CLR_RESET)"; \
	fi; \
	echo -e "$(CLR_GREEN)[✔] ARCANE_DOMAIN=$$domain, ARCANE_APP_URL=https://$$domain$(CLR_RESET)"
	@$(MAKE) --no-print-directory reload-if-running

# Detect the Docker network CIDR, so Arcane trusts X-Forwarded-For from Traefik
setup-proxies: init-env
	@set_var() { if grep -q "^$$1=" $(ENV_FILE); then sed -i "s|^$$1=.*|$$1=$$2|" $(ENV_FILE); else echo "$$1=$$2" >> $(ENV_FILE); fi; }; \
	network=$$(grep -E '^DOCKER_NETWORK=' $(ENV_FILE) 2>/dev/null | cut -d '=' -f2-); \
	network=$${network:-my_network}; \
	echo -e "$(CLR_CYAN)[*] Detecting the subnet of Docker network '$$network'...$(CLR_RESET)"; \
	subnet=""; \
	if $(DOCKER) network inspect "$$network" >/dev/null 2>&1; then \
		subnet=$$($(DOCKER) network inspect "$$network" --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null | awk '{print $$1}'); \
	fi; \
	if [ -z "$$subnet" ]; then \
		echo -e "$(CLR_YELLOW)[!] Network '$$network' not found yet (start the Traefik stack first).$(CLR_RESET)"; \
		echo -e "$(CLR_YELLOW)[!] Falling back to Docker's default range 172.18.0.0/16.$(CLR_RESET)"; \
		subnet="172.18.0.0/16"; \
	fi; \
	echo -e "    Detected subnet: $(CLR_CYAN)$$subnet$(CLR_RESET)"; \
	read -p "CIDR Arcane should trust [$$subnet]: " cidr </dev/tty; \
	cidr=$${cidr:-$$subnet}; \
	set_var ARCANE_TRUSTED_PROXIES "$$cidr"; \
	echo -e "$(CLR_GREEN)[✔] ARCANE_TRUSTED_PROXIES=$$cidr$(CLR_RESET)"
	@$(MAKE) --no-print-directory reload-if-running

# Configure .env without deploying
setup-all: check-docker setup-secret setup-domain setup-proxies
	@echo -e "$(CLR_GREEN)[✔] Configuration complete. Run 'make deploy' to start Arcane.$(CLR_RESET)"

# Full end-to-end install
install-arcane: setup-all deploy report

deploy: check-docker ensure-secret
	@echo -e "$(CLR_CYAN)[*] Deploying Arcane...$(CLR_RESET)"
	@$(COMPOSE) up -d
	@echo -e "$(CLR_YELLOW)[*] Waiting for the container to become healthy...$(CLR_RESET)"
	@health="starting"; \
	for i in $$(seq 1 45); do \
		health=$$($(DOCKER) inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$(ARCANE_CONTAINER_NAME)" 2>/dev/null || echo missing); \
		if [ "$$health" = "healthy" ] || [ "$$health" = "unhealthy" ] || [ "$$health" = "missing" ]; then \
			break; \
		fi; \
		sleep 2; \
	done; \
	if [ "$$health" = "healthy" ]; then \
		echo -e "$(CLR_GREEN)[✔] Arcane is healthy.$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_RED)[!] Health status: $$health. Run 'make logs' to inspect.$(CLR_RESET)"; \
	fi
	@echo -e "    URL: $(CLR_CYAN)$(ARCANE_APP_URL)$(CLR_RESET) (local: http://127.0.0.1:$(ARCANE_PORT))"
	@echo -e "    First-run password: $(CLR_CYAN)make password$(CLR_RESET)"

down:
	@echo -e "$(CLR_YELLOW)[*] Stopping Arcane...$(CLR_RESET)"
	@$(COMPOSE) down
	@echo -e "$(CLR_GREEN)[✔] Stopped. Bind-mounted data is untouched.$(CLR_RESET)"

restart: check-docker
	@echo -e "$(CLR_YELLOW)[*] Recreating Arcane to apply configuration...$(CLR_RESET)"
	@$(COMPOSE) up -d --force-recreate
	@echo -e "$(CLR_GREEN)[✔] Arcane restarted.$(CLR_RESET)"

status:
	@$(COMPOSE) ps
	@echo -e "    Health: $(CLR_CYAN)$$($(DOCKER) inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$(ARCANE_CONTAINER_NAME)" 2>/dev/null || echo "not running")$(CLR_RESET)"

health:
	@echo -e "$(CLR_CYAN)[*] Running Arcane health check...$(CLR_RESET)"
	@if $(COMPOSE) exec -T arcane ./arcane health --timeout 2s; then \
		echo -e "$(CLR_GREEN)[✔] Health check passed.$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_RED)[!] Health check failed. Run 'make logs'.$(CLR_RESET)"; \
		exit 1; \
	fi

logs:
	@$(COMPOSE) logs -f --tail=200

# Print the first-run admin password. The image has no shell or cat, so read
# the bind-mounted file (sudo if needed) or stream it out with docker cp.
password:
	@file="$(ARCANE_DATA_DIR)/initial-admin-password"; \
	pw=""; \
	if [ -f "$$file" ]; then \
		pw=$$(cat "$$file" 2>/dev/null); \
	fi; \
	if [ -z "$$pw" ]; then \
		pw=$$($(FS_SUDO) cat "$$file" 2>/dev/null); \
	fi; \
	if [ -z "$$pw" ] && $(DOCKER) inspect "$(ARCANE_CONTAINER_NAME)" >/dev/null 2>&1; then \
		pw=$$($(DOCKER) cp "$(ARCANE_CONTAINER_NAME):/app/data/initial-admin-password" - 2>/dev/null | tar -xO 2>/dev/null); \
	fi; \
	pw=$$(printf '%s' "$$pw" | tr -d '\r\n'); \
	if [ -n "$$pw" ]; then \
		echo -e "$(CLR_CYAN)[*] First-run admin credentials:$(CLR_RESET)"; \
		echo -e "    username: $(CLR_WHITE)arcane$(CLR_RESET)"; \
		echo -e "    password: $(CLR_WHITE)$$pw$(CLR_RESET)"; \
		echo -e "$(CLR_YELLOW)[i] Sign in, then set a new password. This file is removed afterwards.$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_YELLOW)[i] No readable initial-admin-password file found.$(CLR_RESET)"; \
		echo -e "    Either the admin password was already changed, or Arcane has not started yet."; \
		echo -e "    Host path: $(CLR_CYAN)$$file$(CLR_RESET)"; \
		echo -e "    Manual copy: $(CLR_CYAN)docker compose cp arcane:/app/data/initial-admin-password . && sudo cat initial-admin-password$(CLR_RESET)"; \
	fi

update: check-docker
	@echo -e "$(CLR_YELLOW)[*] Pulling the latest Arcane image...$(CLR_RESET)"
	@$(COMPOSE) pull
	@$(COMPOSE) up -d
	@echo -e "$(CLR_GREEN)[✔] Arcane updated.$(CLR_RESET)"
	@$(MAKE) --no-print-directory status

# Consistent backup of the SQLite database: stop, tar, start
backup: init-env
	@stamp=$$(date +%Y%m%d-%H%M%S); \
	out="$(ARCANE_BACKUPS_DIR)/arcane-data-$$stamp.tar.gz"; \
	was_running=$$($(DOCKER) inspect -f '{{.State.Running}}' "$(ARCANE_CONTAINER_NAME)" 2>/dev/null || echo false); \
	if [ "$$was_running" = "true" ]; then \
		echo -e "$(CLR_YELLOW)[*] Stopping Arcane for a consistent backup...$(CLR_RESET)"; \
		$(COMPOSE) stop >/dev/null; \
	fi; \
	echo -e "$(CLR_CYAN)[*] Writing $$out...$(CLR_RESET)"; \
	if tar -czf "$$out" -C "$(ARCANE_DATA_DIR)" . 2>/dev/null; then \
		echo -e "$(CLR_GREEN)[✔] Backup created: $$out$(CLR_RESET)"; \
	elif echo -e "$(CLR_YELLOW)[*] Escalating to read the data directory...$(CLR_RESET)" && $(FS_SUDO) tar -czf "$$out" -C "$(ARCANE_DATA_DIR)" .; then \
		echo -e "$(CLR_GREEN)[✔] Backup created: $$out$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_RED)[!] Backup failed.$(CLR_RESET)"; \
	fi; \
	if [ "$$was_running" = "true" ]; then \
		$(COMPOSE) start >/dev/null; \
		echo -e "$(CLR_GREEN)[✔] Arcane restarted.$(CLR_RESET)"; \
	fi

report: init-env
	@domain="$(ARCANE_DOMAIN)"; \
	url="$(ARCANE_APP_URL)"; \
	resolver="$(TRAEFIK_CERTRESOLVER)"; \
	network="$(DOCKER_NETWORK)"; \
	proxies="$(ARCANE_TRUSTED_PROXIES)"; \
	key_status="Missing (run: make setup-secret)"; \
	grep -qE '^ARCANE_ENCRYPTION_KEY=.+' $(ENV_FILE) 2>/dev/null && key_status="Configured"; \
	state=$$($(DOCKER) inspect -f '{{.State.Status}}' "$(ARCANE_CONTAINER_NAME)" 2>/dev/null || echo "not running"); \
	health=$$($(DOCKER) inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$(ARCANE_CONTAINER_NAME)" 2>/dev/null || echo "n/a"); \
	echo ""; \
	echo -e "$(CLR_CYAN)╔══════════════════════════════════════════════════════════════════════════════╗$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)║$(CLR_RESET)                     $(CLR_BOLD)$(CLR_WHITE)ARCANE CONFIGURATION & STATUS$(CLR_RESET)                        $(CLR_CYAN)║$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)╠══════════════════════════════════════════════════════════════════════════════╣$(CLR_RESET)"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Public Domain" "$$domain"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "App URL" "$$url"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "TLS Resolver" "$$resolver"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Docker Network" "$$network"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Trusted Proxies" "$$proxies"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Encryption Key" "$$key_status"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Data (bind)" "$(ARCANE_DATA_DIR)"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Projects (bind)" "$(ARCANE_PROJECTS_DIR)"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Container" "$$state ($$health)"; \
	echo -e "$(CLR_CYAN)╚══════════════════════════════════════════════════════════════════════════════╝$(CLR_RESET)"; \
	echo ""

# Recreate the container so .env changes apply, but only when it is running
reload-if-running:
	@if [ "$$($(DOCKER) inspect -f '{{.State.Running}}' "$(ARCANE_CONTAINER_NAME)" 2>/dev/null || echo false)" = "true" ]; then \
		echo -e "$(CLR_YELLOW)[*] Arcane is running. Applying the new configuration...$(CLR_RESET)"; \
		$(COMPOSE) up -d --force-recreate; \
		echo -e "$(CLR_GREEN)[✔] Arcane recreated.$(CLR_RESET)"; \
	fi

clean:
	@echo -e "$(CLR_RED)[!] This deletes $(ARCANE_DATA_DIR) (database, secrets, sessions).$(CLR_RESET)"; \
	read -p "Type 'yes' to continue: " confirm </dev/tty; \
	if [ "$$confirm" != "yes" ]; then \
		echo -e "$(CLR_YELLOW)[*] Aborted.$(CLR_RESET)"; \
		exit 0; \
	fi; \
	$(COMPOSE) down; \
	if ! rm -rf "$(ARCANE_DATA_DIR)" 2>/dev/null; then \
		echo -e "$(CLR_YELLOW)[*] Escalating to remove $(ARCANE_DATA_DIR)...$(CLR_RESET)"; \
		$(FS_SUDO) rm -rf "$(ARCANE_DATA_DIR)"; \
	fi; \
	echo -e "$(CLR_GREEN)[✔] $(ARCANE_DATA_DIR) removed.$(CLR_RESET)"

clean-all:
	@echo -e "$(CLR_RED)[!] This deletes $(ARCANE_DATA_DIR), $(ARCANE_PROJECTS_DIR), $(ARCANE_BUILDS_DIR) and $(ARCANE_BACKUPS_DIR).$(CLR_RESET)"; \
	read -p "Type 'yes' to continue: " confirm </dev/tty; \
	if [ "$$confirm" != "yes" ]; then \
		echo -e "$(CLR_YELLOW)[*] Aborted.$(CLR_RESET)"; \
		exit 0; \
	fi; \
	$(COMPOSE) down; \
	for d in "$(ARCANE_DATA_DIR)" "$(ARCANE_PROJECTS_DIR)" "$(ARCANE_BUILDS_DIR)" "$(ARCANE_BACKUPS_DIR)"; do \
		if ! rm -rf "$$d" 2>/dev/null; then \
			echo -e "$(CLR_YELLOW)[*] Escalating to remove $$d...$(CLR_RESET)"; \
			$(FS_SUDO) rm -rf "$$d"; \
		fi; \
	done; \
	echo -e "$(CLR_GREEN)[✔] Bind-mount directories removed.$(CLR_RESET)"
