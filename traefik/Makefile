SHELL = /bin/bash

.PHONY: help check-docker setup-all setup-firewall setup-certs setup-auth setup-acme setup-cloudflare setup-dashboard report install-traefik restart reload-if-running

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
	@echo -e "$(CLR_CYAN)$(CLR_BOLD)Traefik Setup Management$(CLR_RESET)"
	@echo -e "  $(CLR_GREEN)make setup-all$(CLR_RESET)          - Run end-to-end interactive setup (skips already configured steps)"
	@echo -e "  $(CLR_GREEN)make setup-firewall$(CLR_RESET)     - Open ports 80/443 in iptables & save persistently"
	@echo -e "  $(CLR_GREEN)make setup-certs$(CLR_RESET)        - Initialize acme.json with secure 600 permissions"
	@echo -e "  $(CLR_GREEN)make setup-auth$(CLR_RESET)         - Configure dashboard username & password (htpasswd)"
	@echo -e "  $(CLR_GREEN)make setup-acme$(CLR_RESET)         - Configure Let's Encrypt / ACME email (allows skipping)"
	@echo -e "  $(CLR_GREEN)make setup-cloudflare$(CLR_RESET)   - Configure Cloudflare API DNS Token (allows skipping)"
	@echo -e "  $(CLR_GREEN)make setup-dashboard$(CLR_RESET)    - Configure Dashboard domain & resolver (Let's Encrypt / Cloudflare)"
	@echo -e "  $(CLR_GREEN)make report$(CLR_RESET)             - Display colored summary box of current Traefik configuration"
	@echo -e "  $(CLR_GREEN)make restart$(CLR_RESET)            - Restart Traefik containers via Docker Compose"
	@echo -e "  $(CLR_GREEN)make install-traefik$(CLR_RESET)    - Run complete setup and launch Traefik containers"

# Ensure .env exists from template
init-env:
	@if [ ! -f .env ]; then \
		echo -e "$(CLR_YELLOW)[*] Creating .env from .env.example...$(CLR_RESET)"; \
		cp .env.example .env; \
	fi

# 5. Open ports on firewall and save rules
setup-firewall:
	@echo -e "$(CLR_CYAN)[*] Checking firewall rules for ports 80 and 443...$(CLR_RESET)"
	@if sudo iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null; then \
		echo -e "$(CLR_GREEN)[✔] Ports 80 and 443 are already open in iptables.$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_YELLOW)[+] Opening ports 80 and 443 in iptables...$(CLR_RESET)"; \
		sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT; \
		if command -v netfilter-persistent >/dev/null 2>&1; then \
			sudo netfilter-persistent save; \
		elif [ -d /etc/iptables ]; then \
			sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null; \
		fi; \
		echo -e "$(CLR_GREEN)[✔] Ports 80 and 443 opened and saved.$(CLR_RESET)"; \
	fi

# 6. Setup certificate file with proper permissions (600)
setup-certs:
	@echo -e "$(CLR_CYAN)[*] Checking acme.json certificate storage...$(CLR_RESET)"
	@if [ -f ./acme.json ] && [ "$$(stat -c '%a' ./acme.json 2>/dev/null || stat -f '%Lp' ./acme.json 2>/dev/null)" = "600" ]; then \
		echo -e "$(CLR_GREEN)[✔] acme.json already exists with 600 permissions.$(CLR_RESET)"; \
	else \
		touch ./acme.json; \
		chmod 600 ./acme.json; \
		echo -e "$(CLR_GREEN)[✔] acme.json created and permissions set to 600.$(CLR_RESET)"; \
	fi

# 1. Dashboard username and password
setup-auth: init-env
	@auth_val=$$(grep -E '^TRAEFIK_BASIC_AUTH_USERS=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	if [ -n "$$auth_val" ] && [ "$$auth_val" != 'admin:$$apr1$$8cvG1.rX$$1pE7aV6.Dph7H9z1oJbXQ0' ]; then \
		echo -e "$(CLR_GREEN)[✔] Dashboard basic authentication already configured for user '$$(echo "$$auth_val" | cut -d ':' -f1)'.$(CLR_RESET)"; \
		read -p "Do you want to reconfigure username/password? [y/N]: " reconf; \
		if [ "$$reconf" != "y" ] && [ "$$reconf" != "Y" ]; then \
			exit 0; \
		fi; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Configuring Traefik Dashboard Basic Auth credentials:$(CLR_RESET)"; \
	read -p "Enter dashboard username [admin]: " d_user </dev/tty; \
	d_user=$${d_user:-admin}; \
	read -s -p "Enter dashboard password: " d_pass </dev/tty; echo ""; \
	if [ -z "$$d_pass" ]; then \
		echo -e "$(CLR_RED)[!] Password cannot be empty.$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_YELLOW)[*] Generating password hash...$(CLR_RESET)"; \
		if command -v htpasswd >/dev/null 2>&1; then \
			raw_hash=$$(htpasswd -nbB "$$d_user" "$$d_pass" 2>/dev/null | tr -d '\r\n'); \
		else \
			raw_hash=$$(sudo docker run --rm httpd:alpine htpasswd -nbB "$$d_user" "$$d_pass" 2>/dev/null | tr -d '\r\n'); \
		fi; \
		if [ -z "$$raw_hash" ]; then \
			echo -e "$(CLR_RED)[!] Failed to generate hash. Ensure Docker is running or htpasswd is installed.$(CLR_RESET)"; \
		else \
			user_part=$$(echo "$$raw_hash" | cut -d ':' -f1); \
			pass_part=$$(echo "$$raw_hash" | cut -d ':' -f2-); \
			escaped_entry=$$(awk -v u="$$user_part" -v p="$$pass_part" 'BEGIN { gsub(/\$$/, "$$$$", p); print u ":" p }'); \
			grep -v '^TRAEFIK_BASIC_AUTH_USERS=' .env > .env.tmp 2>/dev/null || cp .env .env.tmp; \
			echo "TRAEFIK_BASIC_AUTH_USERS=$$escaped_entry" >> .env.tmp; \
			mv .env.tmp .env; \
			echo -e "$(CLR_GREEN)[✔] Dashboard credentials updated for user '$$d_user'.$(CLR_RESET)"; \
		fi; \
	fi
	@$(MAKE) --no-print-directory reload-if-running

# 2. ACME Email (Allows skipping)
setup-acme: init-env
	@acme_val=$$(grep -E '^ACME_EMAIL=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	if [ -n "$$acme_val" ]; then \
		echo -e "$(CLR_GREEN)[✔] ACME email already configured ($$acme_val).$(CLR_RESET)"; \
		read -p "Do you want to change ACME email? [y/N]: " reconf; \
		if [ "$$reconf" != "y" ] && [ "$$reconf" != "Y" ]; then \
			exit 0; \
		fi; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] ACME / Let's Encrypt Email Configuration:$(CLR_RESET)"; \
	read -p "Enter ACME email (leave blank to skip registration email): " acme_in </dev/tty; \
	if grep -q '^ACME_EMAIL=' .env; then \
		sed -i -E "s|^ACME_EMAIL=.*|ACME_EMAIL=$$acme_in|" .env; \
	else \
		echo "ACME_EMAIL=$$acme_in" >> .env; \
	fi; \
	if [ -n "$$acme_in" ]; then \
		echo -e "$(CLR_GREEN)[✔] ACME email set to '$$acme_in'.$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_YELLOW)[✔] ACME email skipped.$(CLR_RESET)"; \
	fi
	@$(MAKE) --no-print-directory reload-if-running

# 3. Cloudflare DNS token (Allows skipping)
setup-cloudflare: init-env
	@token_val=$$(grep -E '^CF_DNS_API_TOKEN=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	if [ -n "$$token_val" ]; then \
		echo -e "$(CLR_GREEN)[✔] Cloudflare DNS token already configured.$(CLR_RESET)"; \
		read -p "Do you want to reconfigure Cloudflare DNS tokens? [y/N]: " reconf; \
		if [ "$$reconf" != "y" ] && [ "$$reconf" != "Y" ]; then \
			exit 0; \
		fi; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Cloudflare DNS-01 Token Configuration (Required for wildcard certs):$(CLR_RESET)"; \
	read -p "Enter Cloudflare API Email (leave blank to skip): " cf_email_in </dev/tty; \
	read -p "Enter Cloudflare API Token (leave blank to skip): " cf_token_in </dev/tty; \
	if [ -n "$$cf_token_in" ]; then \
		sed -i -E "s|^CF_API_EMAIL=.*|CF_API_EMAIL=$$cf_email_in|" .env; \
		sed -i -E "s|^CF_DNS_API_TOKEN=.*|CF_DNS_API_TOKEN=$$cf_token_in|" .env; \
		sed -i -E "s|^CF_ZONE_API_TOKEN=.*|CF_ZONE_API_TOKEN=$$cf_token_in|" .env; \
		echo -e "$(CLR_GREEN)[✔] Cloudflare credentials configured.$(CLR_RESET)"; \
	else \
		sed -i -E "s|^CF_API_EMAIL=.*|CF_API_EMAIL=|" .env; \
		sed -i -E "s|^CF_DNS_API_TOKEN=.*|CF_DNS_API_TOKEN=|" .env; \
		sed -i -E "s|^CF_ZONE_API_TOKEN=.*|CF_ZONE_API_TOKEN=|" .env; \
		echo -e "$(CLR_YELLOW)[✔] Cloudflare DNS challenge configuration skipped.$(CLR_RESET)"; \
	fi
	@$(MAKE) --no-print-directory reload-if-running

# 4. Traefik dashboard domain and Resolver selection (Let's Encrypt / Cloudflare)
setup-dashboard: init-env
	@domain_val=$$(grep -E '^TRAEFIK_DASHBOARD_DOMAIN=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	if [ -n "$$domain_val" ]; then \
		echo -e "$(CLR_GREEN)[✔] Dashboard domain already configured ($$domain_val).$(CLR_RESET)"; \
		read -p "Do you want to change dashboard domain/resolver? [y/N]: " reconf; \
		if [ "$$reconf" != "y" ] && [ "$$reconf" != "Y" ]; then \
			exit 0; \
		fi; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Traefik Dashboard Domain & TLS Resolver:$(CLR_RESET)"; \
	read -p "Enter Dashboard Domain (e.g., traefik.yourdomain.com): " d_domain </dev/tty; \
	if [ -n "$$d_domain" ]; then \
		if grep -q '^TRAEFIK_DASHBOARD_DOMAIN=' .env; then \
			sed -i -E "s|^TRAEFIK_DASHBOARD_DOMAIN=.*|TRAEFIK_DASHBOARD_DOMAIN=$$d_domain|" .env; \
		else \
			echo "TRAEFIK_DASHBOARD_DOMAIN=$$d_domain" >> .env; \
		fi; \
	fi; \
	echo "Select certificate resolver for the dashboard:"; \
	echo "  1) Let's Encrypt HTTP-01 challenge (myresolver)"; \
	echo "  2) Cloudflare DNS-01 challenge (cloudflare_resolver)"; \
	read -p "Choose [1/2, default 1]: " resolver_choice </dev/tty; \
	if [ "$$resolver_choice" = "2" ]; then \
		sed -i -E "s|^TRAEFIK_DASHBOARD_CERTRESOLVER=.*|TRAEFIK_DASHBOARD_CERTRESOLVER=cloudflare_resolver|" .env; \
		echo -e "$(CLR_GREEN)[✔] Dashboard resolver set to 'cloudflare_resolver'.$(CLR_RESET)"; \
	else \
		sed -i -E "s|^TRAEFIK_DASHBOARD_CERTRESOLVER=.*|TRAEFIK_DASHBOARD_CERTRESOLVER=myresolver|" .env; \
		echo -e "$(CLR_GREEN)[✔] Dashboard resolver set to 'myresolver' (HTTP challenge).$(CLR_RESET)"; \
	fi
	@$(MAKE) --no-print-directory reload-if-running

# Color formatted status report box
report: init-env
	@AUTH_SET=$$(grep -E '^TRAEFIK_BASIC_AUTH_USERS=' .env | cut -d '=' -f2- | tr -d '[:space:]'); \
	ACME_SET=$$(grep -E '^ACME_EMAIL=' .env | cut -d '=' -f2- | tr -d '[:space:]'); \
	CF_SET=$$(grep -E '^CF_DNS_API_TOKEN=' .env | cut -d '=' -f2- | tr -d '[:space:]'); \
	DOM_SET=$$(grep -E '^TRAEFIK_DASHBOARD_DOMAIN=' .env | cut -d '=' -f2- | tr -d '[:space:]'); \
	RES_SET=$$(grep -E '^TRAEFIK_DASHBOARD_CERTRESOLVER=' .env | cut -d '=' -f2- | tr -d '[:space:]'); \
	PORT_CHECK="Open (80, 443)"; \
	sudo iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || PORT_CHECK="Needs Attention"; \
	PERM_CHECK="Not Set"; \
	[ -f ./acme.json ] && PERM_CHECK="$$(stat -c '%a' ./acme.json 2>/dev/null || stat -f '%Lp' ./acme.json 2>/dev/null)"; \
	[ -z "$$AUTH_SET" ] || [ "$$AUTH_SET" = 'admin:$$apr1$$8cvG1.rX$$1pE7aV6.Dph7H9z1oJbXQ0' ] && AUTH_STATUS="Default/Unset" || AUTH_STATUS="Configured"; \
	[ -z "$$ACME_SET" ] || [ "$$ACME_SET" = "admin@example.com" ] && ACME_STATUS="Not Set (Skipped)" || ACME_STATUS="$$ACME_SET"; \
	[ -z "$$CF_SET" ] || [ "$$CF_SET" = "your_cloudflare_api_token_here" ] && CF_STATUS="Disabled (Skipped)" || CF_STATUS="Configured"; \
	[ -z "$$DOM_SET" ] || [ "$$DOM_SET" = "traefik.example.com" ] && DOM_STATUS="Default (traefik.example.com)" || DOM_STATUS="$$DOM_SET"; \
	[ "$$RES_SET" = "cloudflare_resolver" ] && RES_STATUS="Cloudflare DNS-01" || RES_STATUS="Let's Encrypt HTTP-01"; \
	echo ""; \
	echo -e "$(CLR_CYAN)╔══════════════════════════════════════════════════════════════════════════════╗$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)║$(CLR_RESET)                   $(CLR_BOLD)$(CLR_WHITE)TRAEFIK CONFIGURATION & STATUS REPORT$(CLR_RESET)                      $(CLR_CYAN)║$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)╠══════════════════════════════════════════════════════════════════════════════╣$(CLR_RESET)"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Dashboard Domain" "$$DOM_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Dashboard TLS Resolver" "$$RES_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Basic Auth Status" "$$AUTH_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "ACME Notification Email" "$$ACME_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Cloudflare DNS Token" "$$CF_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Firewall Ports" "$$PORT_CHECK"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)acme.json (perms: %-27s)$(CLR_CYAN)║$(CLR_RESET)\n" "$$PERM_CHECK"; \
	echo -e "$(CLR_CYAN)╚══════════════════════════════════════════════════════════════════════════════╝$(CLR_RESET)"; \
	echo ""

# Check if Traefik is running and recreate/restart to apply config changes
reload-if-running:
	@if command -v docker >/dev/null 2>&1; then \
		if [ -n "$$(sudo docker compose ps -q traefik 2>/dev/null)" ] || [ -n "$$(sudo docker ps -q -f name=^/traefik$$ 2>/dev/null)" ]; then \
			echo -e "$(CLR_YELLOW)[*] Traefik is currently running. Restarting to apply changes...$(CLR_RESET)"; \
			sudo docker compose up -d --force-recreate; \
			echo -e "$(CLR_GREEN)[✔] Traefik updated and running with latest configuration.$(CLR_RESET)"; \
		fi; \
	fi

# Explicit manual restart target
restart: check-docker
	@echo -e "$(CLR_YELLOW)[*] Restarting Traefik...$(CLR_RESET)"
	sudo docker compose up -d --force-recreate
	@echo -e "$(CLR_GREEN)[✔] Traefik restarted successfully.$(CLR_RESET)"

# Docker availability verification
check-docker:
	@if ! command -v docker >/dev/null 2>&1; then \
		echo -e "$(CLR_RED)[!] Docker is not installed or not in PATH.$(CLR_RESET)"; \
		echo -e "$(CLR_YELLOW)[*] Please install Docker first: https://docs.docker.com/engine/install/$(CLR_RESET)"; \
		exit 1; \
	fi

# End-to-end setup orchestrator
setup-all: init-env setup-firewall setup-certs setup-auth setup-acme setup-cloudflare setup-dashboard report reload-if-running

install-traefik: check-docker setup-all
	@if [ -z "$$(sudo docker compose ps -q traefik 2>/dev/null)" ] && [ -z "$$(sudo docker ps -q -f name=^/traefik$$ 2>/dev/null)" ]; then \
		echo -e "$(CLR_GREEN)[*] Starting Traefik via Docker Compose...$(CLR_RESET)"; \
		sudo docker compose up -d; \
		echo -e "$(CLR_GREEN)[✔] Traefik deployed successfully.$(CLR_RESET)"; \
	fi
