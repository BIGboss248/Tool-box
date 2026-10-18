SHELL = /bin/bash

.PHONY: help init-env check-docker setup-all install-nexora setup-db setup-port setup-firewall setup-traefik disable-traefik setup-node disable-node setup-monitoring disable-monitoring token setup-token rotate-token reset-password admin-list hwid backup restore report reload-if-running restart stop down logs logs-panel logs-postgres logs-node logs-monitoring update

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

help:
	@echo -e "$(CLR_CYAN)$(CLR_BOLD)Nexora Panel Stack Management$(CLR_RESET)"
	@echo -e "  $(CLR_GREEN)make setup-all$(CLR_RESET)          - Run end-to-end interactive guided setup & start Nexora"
	@echo -e "  $(CLR_GREEN)make install-nexora$(CLR_RESET)     - Alias for setup-all and container launch"
	@echo -e "  $(CLR_GREEN)make setup-db$(CLR_RESET)           - Configure database engine (SQLite or PostgreSQL 17)"
	@echo -e "  $(CLR_GREEN)make setup-port$(CLR_RESET)         - Configure panel listening port & host IP binding"
	@echo -e "  $(CLR_GREEN)make setup-firewall$(CLR_RESET)     - Open panel port in iptables & save rules"
	@echo -e "  $(CLR_GREEN)make setup-traefik$(CLR_RESET)      - Configure Traefik reverse proxy routing & TLS resolver"
	@echo -e "  $(CLR_GREEN)make disable-traefik$(CLR_RESET)    - Disable Traefik reverse proxy routing"
	@echo -e "  $(CLR_GREEN)make setup-node$(CLR_RESET)         - Enable optional same-server node (testing/lab)"
	@echo -e "  $(CLR_GREEN)make disable-node$(CLR_RESET)       - Disable same-server node container"
	@echo -e "  $(CLR_GREEN)make setup-monitoring$(CLR_RESET)   - Configure & enable Prometheus & Grafana fleet monitoring"
	@echo -e "  $(CLR_GREEN)make disable-monitoring$(CLR_RESET) - Disable Prometheus & Grafana monitoring"
	@echo -e "  $(CLR_GREEN)make token$(CLR_RESET)              - Display one-time Setup Wizard token & URL (alias: setup-token)"
	@echo -e "  $(CLR_GREEN)make rotate-token$(CLR_RESET)       - Invalidate previous token and generate a new setup token"
	@echo -e "  $(CLR_GREEN)make admin-list$(CLR_RESET)         - List registered panel administrator accounts"
	@echo -e "  $(CLR_GREEN)make reset-password$(CLR_RESET)     - Reset main admin password via CLI"
	@echo -e "  $(CLR_GREEN)make hwid$(CLR_RESET)               - Print machine hardware fingerprint for licensing"
	@echo -e "  $(CLR_GREEN)make backup$(CLR_RESET)             - Trigger backup & inspect ./backups folder"
	@echo -e "  $(CLR_GREEN)make restore$(CLR_RESET)            - Restore panel database from a backup archive"
	@echo -e "  $(CLR_GREEN)make report$(CLR_RESET)             - Display colored summary box of Nexora stack status"
	@echo -e "  $(CLR_GREEN)make update$(CLR_RESET)             - Pull latest images and recreate running containers"
	@echo -e "  $(CLR_GREEN)make logs$(CLR_RESET)               - Follow live logs of panel container (or logs-all)"
	@echo -e "  $(CLR_GREEN)make restart$(CLR_RESET)            - Restart stack containers via Docker Compose"
	@echo -e "  $(CLR_GREEN)make stop$(CLR_RESET)               - Stop all running Nexora containers"
	@echo -e "  $(CLR_GREEN)make down$(CLR_RESET)               - Stop and remove containers and internal networks"

# Ensure directories, machine-id and .env exist from template
init-env:
	@mkdir -p ./data ./backups ./rulesets ./bin ./sub-themes ./certs ./cache ./monitoring/prometheus ./monitoring/grafana/dashboards
	@if [ ! -f .env ]; then \
		echo -e "$(CLR_YELLOW)[*] Creating .env from .env.example...$(CLR_RESET)"; \
		cp .env.example .env; \
	fi
	@if [ ! -f /etc/machine-id ] && [ ! -f ./machine-id ]; then \
		echo -e "$(CLR_YELLOW)[*] Generating fallback machine-id for licensing...$(CLR_RESET)"; \
		(openssl rand -hex 16 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' || date +%s%N | sha256sum | head -c 32) > ./machine-id 2>/dev/null || echo "0123456789abcdef0123456789abcdef" > ./machine-id; \
		if ! grep -q '^MACHINE_ID_PATH=' .env; then \
			echo "MACHINE_ID_PATH=./machine-id" >> .env; \
		else \
			sed -i -E "s|^MACHINE_ID_PATH=.*|MACHINE_ID_PATH=./machine-id|" .env; \
		fi; \
	elif [ -f /etc/machine-id ]; then \
		if grep -q '^MACHINE_ID_PATH=' .env; then \
			sed -i -E "s|^MACHINE_ID_PATH=.*|MACHINE_ID_PATH=/etc/machine-id|" .env; \
		fi; \
	fi

# Docker availability check
check-docker:
	@if ! command -v docker >/dev/null 2>&1; then \
		echo -e "$(CLR_RED)[!] Docker is not installed or not in PATH.$(CLR_RESET)"; \
		echo -e "$(CLR_YELLOW)[*] Please install Docker first: https://docs.docker.com/engine/install/$(CLR_RESET)"; \
		exit 1; \
	fi

# 1. Database engine configuration (SQLite vs PostgreSQL 17)
setup-db: init-env
	@curr_driver=$$(grep -E '^NEXORA_DB_DRIVER=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	echo -e "$(CLR_YELLOW)[*] Database Configuration (Current: $${curr_driver:-sqlite}):$(CLR_RESET)"; \
	echo "Select database backend:"; \
	echo "  1) SQLite (Default, embedded file, zero maintenance, ideal for <10,000 active users)"; \
	echo "  2) PostgreSQL 17 (Dedicated container, high concurrency & clustering)"; \
	read -p "Choose [1/2, default 1]: " db_choice </dev/tty; \
	db_choice=$${db_choice:-1}; \
	if [ "$$db_choice" = "2" ]; then \
		echo -e "$(CLR_CYAN)[*] Configuring PostgreSQL 17...$(CLR_RESET)"; \
		sed -i -E "s|^NEXORA_DB_DRIVER=.*|NEXORA_DB_DRIVER=postgres|" .env; \
		pg_pass=$$(grep -E '^POSTGRES_PASSWORD=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
		if [ -z "$$pg_pass" ] || [ "$$pg_pass" = "change-me" ]; then \
			gen_pass=$$(openssl rand -hex 16 2>/dev/null || date +%s%N | sha256sum | head -c 24); \
			read -p "Enter PostgreSQL password or press Enter to auto-generate: " user_pass </dev/tty; \
			pg_pass=$${user_pass:-$$gen_pass}; \
			sed -i -E "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$$pg_pass|" .env; \
		fi; \
		sed -i -E 's|^[#[:space:]]*NEXORA_DB_DSN=host=postgres.*|NEXORA_DB_DSN=host=postgres port=5432 user=nexora password='$${pg_pass}' dbname=nexora sslmode=disable|' .env; \
		curr_prof=$$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
		new_prof=$$(echo "$$curr_prof,postgres" | tr ',' '\n' | grep -v '^$$' | awk '!seen[$$0]++' | paste -sd, -); \
		sed -i -E "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=$$new_prof|" .env; \
		echo -e "$(CLR_GREEN)[✔] Database set to PostgreSQL 17 (profile 'postgres' activated).$(CLR_RESET)"; \
	else \
		sed -i -E "s|^NEXORA_DB_DRIVER=.*|NEXORA_DB_DRIVER=sqlite|" .env; \
		sed -i -E "s|^NEXORA_DB_DSN=.*|NEXORA_DB_DSN=/app/db/nexora.db|" .env; \
		curr_prof=$$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
		new_prof=$$(echo "$$curr_prof" | tr ',' '\n' | grep -v '^$$' | grep -v '^postgres$$' | awk '!seen[$$0]++' | paste -sd, -); \
		sed -i -E "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=$$new_prof|" .env; \
		echo -e "$(CLR_GREEN)[✔] Database set to SQLite (data directory: ./data).$(CLR_RESET)"; \
	fi
	@$(MAKE) --no-print-directory reload-if-running

# 2. Port and IP binding configuration
setup-port: init-env
	@curr_port=$$(grep -E '^NEXORA_PORT=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	echo -e "$(CLR_YELLOW)[*] Nexora Panel Port Configuration (Current: $${curr_port:-2095}):$(CLR_RESET)"; \
	read -p "Enter panel listening port [default 2095]: " port_in </dev/tty; \
	port_in=$${port_in:-$${curr_port:-2095}}; \
	sed -i -E "s|^NEXORA_PORT=.*|NEXORA_PORT=$$port_in|" .env; \
	echo -e "$(CLR_GREEN)[✔] Panel port set to $$port_in.$(CLR_RESET)"; \
	read -p "Bind host IP (0.0.0.0 for public, 127.0.0.1 for local/reverse proxy only) [0.0.0.0]: " bind_in </dev/tty; \
	bind_in=$${bind_in:-0.0.0.0}; \
	sed -i -E "s|^NEXORA_BIND_IP=.*|NEXORA_BIND_IP=$$bind_in|" .env; \
	echo -e "$(CLR_GREEN)[✔] Host IP binding set to $$bind_in:$$port_in.$(CLR_RESET)"
	@$(MAKE) --no-print-directory reload-if-running

# 3. Firewall configuration
setup-firewall: init-env
	@port=$$(grep -E '^NEXORA_PORT=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	port=$${port:-2095}; \
	echo -e "$(CLR_CYAN)[*] Checking firewall rules for TCP port $$port...$(CLR_RESET)"; \
	if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then \
		echo -e "$(CLR_YELLOW)[+] Allowing port $$port in UFW...$(CLR_RESET)"; \
		sudo ufw allow $$port/tcp; \
		echo -e "$(CLR_GREEN)[✔] UFW rule added for port $$port/tcp.$(CLR_RESET)"; \
	elif command -v iptables >/dev/null 2>&1; then \
		if sudo iptables -C INPUT -p tcp --dport $$port -j ACCEPT 2>/dev/null; then \
			echo -e "$(CLR_GREEN)[✔] Port $$port is already open in iptables.$(CLR_RESET)"; \
		else \
			echo -e "$(CLR_YELLOW)[+] Opening port $$port in iptables...$(CLR_RESET)"; \
			sudo iptables -I INPUT -p tcp --dport $$port -j ACCEPT; \
			if command -v netfilter-persistent >/dev/null 2>&1; then \
				sudo netfilter-persistent save; \
			elif [ -d /etc/iptables ]; then \
				sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null; \
			fi; \
			echo -e "$(CLR_GREEN)[✔] Port $$port opened and persisted.$(CLR_RESET)"; \
		fi; \
	else \
		echo -e "$(CLR_YELLOW)[!] Neither UFW nor iptables detected. Ensure port $$port is open in your cloud provider firewall.$(CLR_RESET)"; \
	fi

# 4. Traefik reverse proxy integration
setup-traefik: init-env
	@tr_en=$$(grep -E '^TRAEFIK_ENABLED=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	tr_dom=$$(grep -E '^NEXORA_DOMAIN=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	echo -e "$(CLR_YELLOW)[*] Traefik Reverse Proxy Integration:$(CLR_RESET)"; \
	read -p "Route Nexora Panel through Traefik reverse proxy? [y/N, default N]: " route_tr </dev/tty; \
	route_tr=$${route_tr:-N}; \
	if [ "$$route_tr" != "y" ] && [ "$$route_tr" != "Y" ]; then \
		$(MAKE) --no-print-directory disable-traefik; \
		exit 0; \
	fi; \
	read -p "Enter domain for Nexora Panel (e.g. nexora.yourdomain.com): " domain_in </dev/tty; \
	if [ -n "$$domain_in" ]; then \
		sed -i -E "s|^NEXORA_DOMAIN=.*|NEXORA_DOMAIN=$$domain_in|" .env; \
	fi; \
	echo "Select Traefik certificate resolver:"; \
	echo "  1) Let's Encrypt HTTP-01 challenge (myresolver)"; \
	echo "  2) Cloudflare DNS-01 challenge (cloudflare_resolver)"; \
	read -p "Choose [1/2, default 1]: " res_choice </dev/tty; \
	if [ "$$res_choice" = "2" ]; then \
		sed -i -E "s|^TRAEFIK_CERTRESOLVER=.*|TRAEFIK_CERTRESOLVER=cloudflare_resolver|" .env; \
		echo -e "$(CLR_GREEN)[✔] Traefik resolver set to 'cloudflare_resolver'.$(CLR_RESET)"; \
	else \
		sed -i -E "s|^TRAEFIK_CERTRESOLVER=.*|TRAEFIK_CERTRESOLVER=myresolver|" .env; \
		echo -e "$(CLR_GREEN)[✔] Traefik resolver set to 'myresolver'.$(CLR_RESET)"; \
	fi; \
	sed -i -E "s|^TRAEFIK_ENABLED=.*|TRAEFIK_ENABLED=true|" .env; \
	read -p "Optional: Restrict host port binding to localhost only (127.0.0.1) since Traefik handles external ingress? [Y/n, default Y]: " bind_local </dev/tty; \
	if [ "$$bind_local" != "n" ] && [ "$$bind_local" != "N" ]; then \
		sed -i -E "s|^NEXORA_BIND_IP=.*|NEXORA_BIND_IP=127.0.0.1|" .env; \
	fi; \
	echo -e "$(CLR_GREEN)[✔] Traefik reverse proxy routing enabled for $$(grep -E '^NEXORA_DOMAIN=' .env | cut -d '=' -f2-).$(CLR_RESET)"
	@$(MAKE) --no-print-directory reload-if-running

disable-traefik: init-env
	@sed -i -E "s|^TRAEFIK_ENABLED=.*|TRAEFIK_ENABLED=false|" .env; \
	sed -i -E "s|^NEXORA_BIND_IP=.*|NEXORA_BIND_IP=0.0.0.0|" .env; \
	echo -e "$(CLR_GREEN)[✔] Traefik routing disabled. Panel bound directly to 0.0.0.0.$$(CLR_RESET)"
	@$(MAKE) --no-print-directory reload-if-running

# 5. Same-Server Node configuration (Testing / Lab deployment)
setup-node: init-env
	@echo -e "$(CLR_YELLOW)[*] Same-Server Node Configuration:$(CLR_RESET)"; \
	echo -e "$(CLR_RED)[!] Note: Running a node on the same server as the panel is NOT recommended for production$(CLR_RESET)"; \
	echo -e "    because nodes expose the server IP in subscription links and traffic bursts can affect the panel."; \
	read -p "Enable same-server node for test/demo purposes? [y/N, default N]: " node_choice </dev/tty; \
	node_choice=$${node_choice:-N}; \
	if [ "$$node_choice" != "y" ] && [ "$$node_choice" != "Y" ]; then \
		$(MAKE) --no-print-directory disable-node; \
		exit 0; \
	fi; \
	curr_prof=$$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	new_prof=$$(echo "$$curr_prof,node" | tr ',' '\n' | grep -v '^$$' | awk '!seen[$$0]++' | paste -sd, -); \
	sed -i -E "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=$$new_prof|" .env; \
	mkdir -p ./certs ./cache; \
	echo -e "$(CLR_GREEN)[✔] Same-server node container profile activated.$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)[i] Setup Steps for Local Node:$(CLR_RESET)"; \
	echo -e "    1. Finish the panel setup wizard by running $(CLR_GREEN)make token$(CLR_RESET)."; \
	echo -e "    2. In the panel UI: Fleet -> Nodes -> Add Node."; \
	echo -e "    3. Set Address: 127.0.0.1, Port: 62050."; \
	echo -e "    4. Copy the mTLS certificate into $(CLR_YELLOW)./certs/panel_ca.pem$(CLR_RESET)."; \
	echo -e "    5. Run $(CLR_GREEN)make restart$(CLR_RESET) to start the node."

disable-node: init-env
	@curr_prof=$$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	new_prof=$$(echo "$$curr_prof" | tr ',' '\n' | grep -v '^$$' | grep -v '^node$$' | awk '!seen[$$0]++' | paste -sd, -); \
	sed -i -E "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=$$new_prof|" .env; \
	if command -v docker >/dev/null 2>&1; then \
		sudo docker compose stop node 2>/dev/null || true; \
		sudo docker compose rm -f node 2>/dev/null || true; \
	fi; \
	echo -e "$(CLR_GREEN)[✔] Same-server node profile disabled.$(CLR_RESET)"

# 6. Prometheus & Grafana Monitoring Configuration
setup-monitoring: init-env
	@echo -e "$(CLR_YELLOW)[*] Prometheus & Grafana Fleet Monitoring Configuration:$(CLR_RESET)"; \
	read -p "Enable Prometheus & Grafana monitoring stack? [y/N, default N]: " mon_choice </dev/tty; \
	mon_choice=$${mon_choice:-N}; \
	if [ "$$mon_choice" != "y" ] && [ "$$mon_choice" != "Y" ]; then \
		$(MAKE) --no-print-directory disable-monitoring; \
		exit 0; \
	fi; \
	read -p "Enter Grafana admin password [default change-me]: " graf_pass </dev/tty; \
	graf_pass=$${graf_pass:-change-me}; \
	sed -i -E "s|^GRAFANA_PASSWORD=.*|GRAFANA_PASSWORD=$$graf_pass|" .env; \
	echo -e "$(CLR_CYAN)[*] Panel API Token Setup for Prometheus /metrics scrape:$(CLR_RESET)"; \
	echo -e "    (In Panel: Admins -> API tokens -> Add Token with 'stats:read' scope)"; \
	read -p "Enter panel API token (or press Enter to configure later): " api_tok </dev/tty; \
	if [ -n "$$api_tok" ]; then \
		echo -n "$$api_tok" > ./monitoring/prometheus/token; \
		echo -e "$(CLR_GREEN)[✔] API token written to ./monitoring/prometheus/token.$(CLR_RESET)"; \
	fi; \
	curr_prof=$$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	new_prof=$$(echo "$$curr_prof,monitoring" | tr ',' '\n' | grep -v '^$$' | awk '!seen[$$0]++' | paste -sd, -); \
	sed -i -E "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=$$new_prof|" .env; \
	echo -e "$(CLR_GREEN)[✔] Monitoring stack enabled (Grafana UI on http://127.0.0.1:3000).$(CLR_RESET)"
	@$(MAKE) --no-print-directory reload-if-running

disable-monitoring: init-env
	@curr_prof=$$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	new_prof=$$(echo "$$curr_prof" | tr ',' '\n' | grep -v '^$$' | grep -v '^monitoring$$' | awk '!seen[$$0]++' | paste -sd, -); \
	sed -i -E "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=$$new_prof|" .env; \
	if command -v docker >/dev/null 2>&1; then \
		sudo docker compose stop prometheus grafana 2>/dev/null || true; \
		sudo docker compose rm -f prometheus grafana 2>/dev/null || true; \
	fi; \
	echo -e "$(CLR_GREEN)[✔] Monitoring stack disabled.$(CLR_RESET)"

# Retrieve and print one-time setup token & wizard URL
setup-token: check-docker
	@echo -e "$(CLR_CYAN)[*] Fetching one-time setup wizard token...$(CLR_RESET)"
	@if [ -z "$$(sudo docker compose ps -q panel 2>/dev/null)" ]; then \
		echo -e "$(CLR_RED)[!] Panel container is not currently running. Starting containers...$(CLR_RESET)"; \
		sudo docker compose up -d panel; \
		sleep 4; \
	fi
	@token_out=$$(sudo docker compose exec panel /app/nexora-panel setup-token 2>/dev/null || true); \
	port=$$(grep -E '^NEXORA_PORT=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	port=$${port:-2095}; \
	host_ip=$$(curl -fsSL https://api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $$1}' || echo "YOUR_SERVER_IP"); \
	tr_en=$$(grep -E '^TRAEFIK_ENABLED=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	tr_dom=$$(grep -E '^NEXORA_DOMAIN=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	echo ""; \
	echo -e "$(CLR_CYAN)╔══════════════════════════════════════════════════════════════════════════════╗$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)║$(CLR_RESET)                   $(CLR_BOLD)$(CLR_WHITE)NEXORA PANEL FIRST-RUN SETUP WIZARD$(CLR_RESET)                       $(CLR_CYAN)║$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)╚══════════════════════════════════════════════════════════════════════════════╝$(CLR_RESET)"; \
	if [ -n "$$token_out" ] && [ "$$token_out" != "no setup token active" ]; then \
		echo -e "  $(CLR_YELLOW)Token:$(CLR_RESET) $(CLR_BOLD)$$token_out$(CLR_RESET)"; \
		echo ""; \
		echo -e "  $(CLR_GREEN)Direct URL:$(CLR_RESET)    http://$$host_ip:$$port/setup?t=$$token_out"; \
		if [ "$$tr_en" = "true" ] && [ -n "$$tr_dom" ]; then \
			echo -e "  $(CLR_GREEN)Traefik URL:$(CLR_RESET)   https://$$tr_dom/setup?t=$$token_out"; \
		fi; \
		echo ""; \
		echo -e "  $(CLR_WHITE)Open this one-time link in your browser to complete initial configuration$(CLR_RESET)"; \
		echo -e "  $(CLR_WHITE)(create the main administrator account, configure domains, paths & SSL).$(CLR_RESET)"; \
	else \
		echo -e "  $(CLR_YELLOW)[i] Setup wizard is already completed or panel has seeded admin.$(CLR_RESET)"; \
		echo -e "      Access your panel at:"; \
		echo -e "      Direct:  http://$$host_ip:$$port/"; \
		if [ "$$tr_en" = "true" ] && [ -n "$$tr_dom" ]; then \
			echo -e "      Traefik: https://$$tr_dom/"; \
		fi; \
	fi; \
	echo ""

token: setup-token

# Rotate setup token if expired or leaked
rotate-token: check-docker
	@echo -e "$(CLR_YELLOW)[*] Rotating one-time setup token...$(CLR_RESET)"
	@sudo docker compose exec panel /app/nexora-panel setup-token -rotate 2>/dev/null || echo -e "$(CLR_RED)[!] Failed to rotate token or panel already initialized.$(CLR_RESET)"

# List administrator accounts
admin-list: check-docker
	@echo -e "$(CLR_CYAN)[*] Listing Nexora Panel Administrator Accounts:$(CLR_RESET)"
	@sudo docker compose exec panel /app/nexora-panel admin list 2>/dev/null || echo -e "$(CLR_RED)[!] Panel container not running or CLI error.$(CLR_RESET)"

# Reset main admin password via CLI
reset-password: check-docker
	@echo -e "$(CLR_YELLOW)[*] Resetting Administrator Password:$(CLR_RESET)"
	@sudo docker compose exec -it panel /app/nexora-panel admin reset-password

# Print hardware fingerprint for license activation
hwid: check-docker
	@echo -e "$(CLR_CYAN)[*] Nexora Hardware Fingerprint (HWID):$(CLR_RESET)"
	@sudo docker compose exec panel /app/nexora-panel hwid 2>/dev/null || echo -e "$(CLR_RED)[!] Panel container not running.$(CLR_RESET)"

# Trigger backup or inspect backup archives
backup: check-docker
	@echo -e "$(CLR_CYAN)[*] Checking Nexora Backup Archives in ./backups:$(CLR_RESET)"
	@ls -lh ./backups/ 2>/dev/null || true
	@echo -e "$(CLR_YELLOW)[i] Backups are managed inside the Panel under Settings -> Backup & Restore.$(CLR_RESET)"
	@echo -e "    Scheduled automatic backups and downloads are saved in $(CLR_GREEN)./backups$(CLR_RESET)."

# Restore instructions
restore:
	@echo -e "$(CLR_CYAN)[*] Nexora Database Restore:$(CLR_RESET)"
	@echo "  To restore an existing backup archive (.tar.gz):"
	@echo "    1. Place the backup file into ./backups/"
	@echo "    2. Run: sudo docker compose exec -it panel /app/nexora-panel restore /var/opt/nexora/backups/<ARCHIVE>.tar.gz"
	@echo "    3. Restart containers: make restart"

# Configuration and live status report box
report: init-env
	@DB_DRIVER=$$(grep -E '^NEXORA_DB_DRIVER=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	PORT_SET=$$(grep -E '^NEXORA_PORT=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	BIND_SET=$$(grep -E '^NEXORA_BIND_IP=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	PROFILES_SET=$$(grep -E '^COMPOSE_PROFILES=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	TR_EN=$$(grep -E '^TRAEFIK_ENABLED=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	TR_DOM=$$(grep -E '^NEXORA_DOMAIN=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	TR_RES=$$(grep -E '^TRAEFIK_CERTRESOLVER=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	PANEL_STATUS="Stopped"; \
	command -v docker >/dev/null 2>&1 && [ -n "$$(sudo docker compose ps -q panel 2>/dev/null)" ] && PANEL_STATUS="Running"; \
	DB_STATUS="SQLite (embedded)"; \
	if [ "$$DB_DRIVER" = "postgres" ]; then \
		DB_RUNNING="Stopped"; \
		command -v docker >/dev/null 2>&1 && [ -n "$$(sudo docker compose ps -q postgres 2>/dev/null)" ] && DB_RUNNING="Running"; \
		DB_STATUS="PostgreSQL 17 ($$DB_RUNNING)"; \
	fi; \
	NODE_STATUS="Disabled"; \
	if echo "$$PROFILES_SET" | grep -q 'node'; then \
		NODE_RUNNING="Stopped"; \
		command -v docker >/dev/null 2>&1 && [ -n "$$(sudo docker compose ps -q node 2>/dev/null)" ] && NODE_RUNNING="Running"; \
		NODE_STATUS="Enabled ($$NODE_RUNNING)"; \
	fi; \
	MON_STATUS="Disabled"; \
	if echo "$$PROFILES_SET" | grep -q 'monitoring'; then \
		MON_RUNNING="Stopped"; \
		command -v docker >/dev/null 2>&1 && [ -n "$$(sudo docker compose ps -q grafana 2>/dev/null)" ] && MON_RUNNING="Running"; \
		MON_STATUS="Enabled ($$MON_RUNNING)"; \
	fi; \
	TR_STATUS="Disabled"; \
	[ "$$TR_EN" = "true" ] && TR_STATUS="Enabled ($$TR_DOM via $$TR_RES)"; \
	echo ""; \
	echo -e "$(CLR_CYAN)╔══════════════════════════════════════════════════════════════════════════════╗$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)║$(CLR_RESET)                   $(CLR_BOLD)$(CLR_WHITE)NEXORA STACK CONFIGURATION & STATUS REPORT$(CLR_RESET)                 $(CLR_CYAN)║$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)╠══════════════════════════════════════════════════════════════════════════════╣$(CLR_RESET)"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Panel Container Status" "$$PANEL_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Database Backend" "$$DB_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Host Port Binding" "$$BIND_SET:$$PORT_SET"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Traefik Ingress" "$$TR_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Same-Server Node" "$$NODE_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Monitoring Stack" "$$MON_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Compose Profiles" "$${PROFILES_SET:-default (sqlite)}"; \
	echo -e "$(CLR_CYAN)╚══════════════════════════════════════════════════════════════════════════════╝$(CLR_RESET)"; \
	echo ""

# Reload containers if already running
reload-if-running:
	@if command -v docker >/dev/null 2>&1; then \
		if [ -n "$$(sudo docker compose ps -q panel 2>/dev/null)" ]; then \
			echo -e "$(CLR_YELLOW)[*] Applying updated configuration...$(CLR_RESET)"; \
			sudo docker compose up -d --remove-orphans; \
			echo -e "$(CLR_GREEN)[✔] Stack updated and running.$(CLR_RESET)"; \
		fi; \
	fi

restart: check-docker
	@echo -e "$(CLR_YELLOW)[*] Restarting Nexora stack...$(CLR_RESET)"
	sudo docker compose up -d --force-recreate
	@echo -e "$(CLR_GREEN)[✔] Nexora stack restarted.$(CLR_RESET)"

stop: check-docker
	@echo -e "$(CLR_YELLOW)[*] Stopping Nexora stack...$(CLR_RESET)"
	sudo docker compose stop
	@echo -e "$(CLR_GREEN)[✔] Stack stopped.$(CLR_RESET)"

down: check-docker
	@echo -e "$(CLR_YELLOW)[*] Taking down Nexora stack...$(CLR_RESET)"
	sudo docker compose down --remove-orphans
	@echo -e "$(CLR_GREEN)[✔] Stack taken down.$(CLR_RESET)"

logs: check-docker
	sudo docker compose logs -f panel

logs-panel: check-docker
	sudo docker compose logs -f panel

logs-postgres: check-docker
	sudo docker compose logs -f postgres

logs-node: check-docker
	sudo docker compose logs -f node

logs-monitoring: check-docker
	sudo docker compose logs -f prometheus grafana

update: check-docker
	@echo -e "$(CLR_YELLOW)[*] Pulling latest Nexora container images...$(CLR_RESET)"
	sudo docker compose pull
	@echo -e "$(CLR_YELLOW)[*] Recreating containers with latest images...$(CLR_RESET)"
	sudo docker compose up -d --remove-orphans
	@echo -e "$(CLR_GREEN)[✔] Nexora stack updated to latest releases.$(CLR_RESET)"

# End-to-end guided setup
setup-all: init-env check-docker setup-db setup-port setup-firewall setup-traefik setup-node setup-monitoring report
	@echo -e "$(CLR_GREEN)[*] Starting Nexora stack via Docker Compose...$(CLR_RESET)"
	sudo docker compose up -d --remove-orphans
	@echo -e "$(CLR_YELLOW)[*] Waiting 5 seconds for Nexora panel service to boot...$(CLR_RESET)"
	@sleep 5
	@$(MAKE) --no-print-directory token

install-nexora: setup-all

