SHELL = /bin/bash

.PHONY: help check-docker setup-all setup-firewall setup-certs setup-auth setup-acme setup-cloudflare setup-dashboard setup-crowdsec setup-captcha disable-crowdsec enable-crowdsec enable-crowdsec-all disable-crowdsec-all enable-crowdsec-global disable-crowdsec-global report crowdsec-report cs-report crowdsec-bans bans cs-bans crowdsec-decisions crowdsec-captcha-test captcha-test crowdsec-unban unban logs-crowdsec install-traefik restart reload-if-running

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
	@echo -e "  $(CLR_GREEN)make setup-crowdsec$(CLR_RESET)     - Configure & enable CrowdSec IPS, Bouncer & Captcha remediation"
	@echo -e "  $(CLR_GREEN)make setup-captcha$(CLR_RESET)      - Configure CrowdSec Captcha provider (Turnstile, hCaptcha, reCAPTCHA)"
	@echo -e "  $(CLR_GREEN)make disable-crowdsec$(CLR_RESET)   - Disable CrowdSec IPS & stop CrowdSec container"
	@echo -e "  $(CLR_GREEN)make enable-crowdsec-all$(CLR_RESET)- Protect ALL endpoints globally via websecure entrypoint & restart"
	@echo -e "  $(CLR_GREEN)make disable-crowdsec-all$(CLR_RESET)- Revert to per-service protection (disable global entrypoint)"
	@echo -e "  $(CLR_GREEN)make report$(CLR_RESET)             - Display colored summary box of current Traefik configuration"
	@echo -e "  $(CLR_GREEN)make crowdsec-report$(CLR_RESET)    - Display detailed CrowdSec report (bouncers, active bans, metrics)"
	@echo -e "  $(CLR_GREEN)make crowdsec-bans$(CLR_RESET)      - View active CrowdSec IP bans & captcha decisions (alias: make bans)"
	@echo -e "  $(CLR_GREEN)make captcha-test$(CLR_RESET)       - Trigger a test Captcha challenge for an IP (make captcha-test IP=x.x.x.x)"
	@echo -e "  $(CLR_GREEN)make crowdsec-unban$(CLR_RESET)     - Remove ban/captcha decisions for an IP (make crowdsec-unban IP=x.x.x.x)"
	@echo -e "  $(CLR_GREEN)make logs-crowdsec$(CLR_RESET)      - Tail live logs from CrowdSec container"
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
	@if [ -d ./acme.json ]; then \
		echo -e "$(CLR_YELLOW)[!] acme.json is currently a directory (created by Docker volume mount). Replacing with file...$(CLR_RESET)"; \
		rm -rf ./acme.json; \
		touch ./acme.json; \
		chmod 600 ./acme.json; \
		echo -e "$(CLR_GREEN)[✔] acme.json recreated as regular file with 600 permissions.$(CLR_RESET)"; \
	elif [ -f ./acme.json ]; then \
		chmod 600 ./acme.json; \
		echo -e "$(CLR_GREEN)[✔] acme.json exists with 600 permissions.$(CLR_RESET)"; \
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

# 5. CrowdSec IPS, Traefik Bouncer & Captcha setup
setup-crowdsec: init-env
	@cs_enabled=$$(grep -E '^CROWDSEC_ENABLED=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	cs_key=$$(grep -E '^CROWDSEC_BOUNCER_KEY=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	if [ "$$cs_enabled" = "true" ] && [ -n "$$cs_key" ]; then \
		echo -e "$(CLR_GREEN)[✔] CrowdSec already configured and enabled (Bouncer Key: $${cs_key:0:6}...$${cs_key: -4}).$(CLR_RESET)"; \
		read -p "Do you want to reconfigure CrowdSec? [y/N]: " reconf </dev/tty; \
		if [ "$$reconf" != "y" ] && [ "$$reconf" != "Y" ]; then \
			exit 0; \
		fi; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Configuring CrowdSec Intrusion Prevention System (IPS):$(CLR_RESET)"; \
	read -p "Enable CrowdSec for Traefik? [Y/n, default Y]: " enable_cs </dev/tty; \
	if [ "$$enable_cs" = "n" ] || [ "$$enable_cs" = "N" ]; then \
		$(MAKE) --no-print-directory disable-crowdsec; \
		exit 0; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Configuring CrowdSec Bouncer API Key:$(CLR_RESET)"; \
	if [ -n "$$cs_key" ]; then \
		echo -e "Existing Bouncer API Key detected in .env: $(CLR_CYAN)$$cs_key$(CLR_RESET)"; \
		read -p "Enter new Bouncer Key or press Enter to keep existing [keep existing]: " key_input </dev/tty; \
		if [ -z "$$key_input" ]; then \
			key_input="$$cs_key"; \
			echo -e "$(CLR_GREEN)[✔] Retained existing Bouncer API Key: $$key_input$(CLR_RESET)"; \
		else \
			echo -e "$(CLR_GREEN)[✔] Using new Bouncer API Key: $$key_input$(CLR_RESET)"; \
		fi; \
	else \
		echo "Leave blank to auto-generate a secure random 32-character key."; \
		read -p "Enter CrowdSec Bouncer Key [auto-generate]: " key_input </dev/tty; \
		if [ -z "$$key_input" ]; then \
			key_input=$$(openssl rand -hex 16 2>/dev/null || od -vN 16 -An -tx1 /dev/urandom 2>/dev/null | tr -d ' \n'); \
			if [ -z "$$key_input" ]; then \
				key_input=$$(date +%s%N | sha256sum | head -c 32); \
			fi; \
			echo -e "$(CLR_GREEN)[✔] Auto-generated Bouncer API Key: $$key_input$(CLR_RESET)"; \
		else \
			echo -e "$(CLR_GREEN)[✔] Using provided Bouncer API Key.$(CLR_RESET)"; \
		fi; \
	fi; \
	read -p "Protect ALL endpoints/services globally via websecure entrypoint? [y/N, default N]: " global_cs </dev/tty; \
	if [ "$$global_cs" = "y" ] || [ "$$global_cs" = "Y" ]; then \
		sed -i -E 's|^[[:space:]]*#[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|      - "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|' docker-compose.yml; \
		echo -e "$(CLR_GREEN)[✔] Global protection enabled on websecure entrypoint.$(CLR_RESET)"; \
	else \
		sed -i -E 's|^[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|      # - "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|' docker-compose.yml; \
		echo -e "$(CLR_YELLOW)[✔] Global protection disabled (per-service router labels will be used).$(CLR_RESET)"; \
	fi; \
	mkdir -p ./crowdsec ./logs; \
	touch ./logs/access.log; \
	if [ ! -f ./crowdsec/acquis.yaml ]; then \
		printf "filenames:\n  - /var/log/traefik/access.log\nlabels:\n  type: traefik\n" > ./crowdsec/acquis.yaml; \
		echo -e "$(CLR_GREEN)[✔] Created crowdsec/acquis.yaml for Traefik access log acquisition.$(CLR_RESET)"; \
	fi; \
	if [ ! -f ./crowdsec/profiles.yaml ]; then \
		printf "name: captcha_remediation\nfilters:\n  - Alert.Remediation == true && Alert.GetScope() == \"Ip\" && Alert.GetScenario() contains \"http\" && GetDecisionsSinceCount(Alert.GetValue(), \"24h\") <= 3\ndecisions:\n  - type: captcha\n    duration: 4h\non_success: break\n---\nname: default_ip_remediation\nfilters:\n  - Alert.Remediation == true && Alert.GetScope() == \"Ip\"\ndecisions:\n  - type: ban\n    duration: 4h\non_success: break\n" > ./crowdsec/profiles.yaml; \
		echo -e "$(CLR_GREEN)[✔] Created crowdsec/profiles.yaml with Captcha + Ban remediation profiles.$(CLR_RESET)"; \
	fi; \
	if [ ! -f ./crowdsec/captcha.html ]; then \
		echo -e "$(CLR_YELLOW)[*] Downloading official CrowdSec Captcha HTML template...$(CLR_RESET)"; \
		curl -fsSL https://raw.githubusercontent.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/main/captcha.html -o ./crowdsec/captcha.html; \
		echo -e "$(CLR_GREEN)[✔] Downloaded crowdsec/captcha.html.$(CLR_RESET)"; \
	fi; \
	if grep -q '^CROWDSEC_ENABLED=' .env; then \
		sed -i -E "s|^CROWDSEC_ENABLED=.*|CROWDSEC_ENABLED=true|" .env; \
	else \
		echo "CROWDSEC_ENABLED=true" >> .env; \
	fi; \
	if grep -q '^COMPOSE_PROFILES=' .env; then \
		sed -i -E "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=crowdsec|" .env; \
	else \
		echo "COMPOSE_PROFILES=crowdsec" >> .env; \
	fi; \
	if grep -q '^CROWDSEC_BOUNCER_KEY=' .env; then \
		sed -i -E "s|^CROWDSEC_BOUNCER_KEY=.*|CROWDSEC_BOUNCER_KEY=$$key_input|" .env; \
	else \
		echo "CROWDSEC_BOUNCER_KEY=$$key_input" >> .env; \
	fi; \
	echo -e "$(CLR_GREEN)[✔] CrowdSec configuration saved to .env.$(CLR_RESET)"; \
	$(MAKE) --no-print-directory setup-captcha SKIP_RELOAD=1; \
	$(MAKE) --no-print-directory reload-if-running; \
	echo ""; \
	echo -e "$(CLR_YELLOW)[*] Waiting 5 seconds for CrowdSec and Traefik to initialize...$(CLR_RESET)"; \
	sleep 5; \
	if command -v docker >/dev/null 2>&1; then \
		if [ -n "$$(sudo docker compose ps -q crowdsec 2>/dev/null)" ] || [ -n "$$(sudo docker ps -q -f name=^/crowdsec$$ 2>/dev/null)" ]; then \
			sudo docker exec crowdsec cscli bouncers delete TRAEFIK >/dev/null 2>&1 || true; \
			sudo docker exec crowdsec cscli bouncers add TRAEFIK --key "$$key_input" >/dev/null 2>&1 || true; \
		fi; \
	fi; \
	echo -e "$(CLR_CYAN)[*] Verifying Live Logs & Bouncer Connectivity:$(CLR_RESET)"; \
	if command -v docker >/dev/null 2>&1; then \
		if [ -n "$$(sudo docker compose ps -q crowdsec 2>/dev/null)" ] || [ -n "$$(sudo docker ps -q -f name=^/crowdsec$$ 2>/dev/null)" ]; then \
			echo -e "$(CLR_YELLOW)--- CrowdSec Engine Recent Logs ---$(CLR_RESET)"; \
			sudo docker compose logs --tail=15 crowdsec 2>/dev/null || true; \
			echo -e "$(CLR_YELLOW)--- Traefik Bouncer Recent Logs ---$(CLR_RESET)"; \
			sudo docker compose logs --tail=15 traefik 2>/dev/null || true; \
			echo -e "$(CLR_YELLOW)--- Registered Bouncers Status ---$(CLR_RESET)"; \
			sudo docker exec crowdsec cscli bouncers list 2>/dev/null || true; \
		fi; \
	fi

enable-crowdsec: setup-crowdsec

# 5b. CrowdSec Captcha Remediation Setup (Turnstile, hCaptcha, or Google reCAPTCHA v2)
setup-captcha: init-env
	@mkdir -p ./crowdsec; \
	if [ ! -f ./crowdsec/captcha.html ]; then \
		echo -e "$(CLR_YELLOW)[*] Downloading official CrowdSec Captcha HTML template...$(CLR_RESET)"; \
		curl -fsSL https://raw.githubusercontent.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/main/captcha.html -o ./crowdsec/captcha.html; \
	fi; \
	cap_prov=$$(grep -E '^CROWDSEC_CAPTCHA_PROVIDER=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	cap_site=$$(grep -E '^CROWDSEC_CAPTCHA_SITE_KEY=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	if [ -n "$$cap_prov" ] && [ -n "$$cap_site" ]; then \
		echo -e "$(CLR_GREEN)[✔] CrowdSec Captcha already configured (Provider: $$cap_prov).$(CLR_RESET)"; \
		read -p "Do you want to reconfigure Captcha remediation? [y/N]: " reconf_cap </dev/tty; \
		if [ "$$reconf_cap" != "y" ] && [ "$$reconf_cap" != "Y" ]; then \
			exit 0; \
		fi; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] CrowdSec Captcha Remediation Configuration:$(CLR_RESET)"; \
	echo "Select Captcha provider for CrowdSec challenge pages:"; \
	echo "  1) Cloudflare Turnstile (turnstile)"; \
	echo "  2) hCaptcha (hcaptcha)"; \
	echo "  3) Google reCAPTCHA v2 (recaptcha)"; \
	echo "  4) Skip / Disable Captcha (use HTTP 403 Ban only)"; \
	read -p "Choose [1-4, default 4 (Skip)]: " prov_choice </dev/tty; \
	prov_choice=$${prov_choice:-4}; \
	case "$$prov_choice" in \
		1) selected_prov="turnstile" ;; \
		2) selected_prov="hcaptcha" ;; \
		3) selected_prov="recaptcha" ;; \
		4) selected_prov="" ;; \
		*) selected_prov="" ;; \
	esac; \
	if [ -n "$$selected_prov" ]; then \
		read -p "Enter $$selected_prov Site Key (leave blank to skip Captcha): " site_key </dev/tty; \
		read -p "Enter $$selected_prov Secret Key (leave blank to skip Captcha): " secret_key </dev/tty; \
		if [ -z "$$site_key" ] || [ -z "$$secret_key" ]; then \
			echo -e "$(CLR_YELLOW)[!] Site Key or Secret Key left blank. Falling back to Ban-only mode.$(CLR_RESET)"; \
			selected_prov=""; \
		fi; \
	fi; \
	if [ -z "$$selected_prov" ]; then \
		for var in CROWDSEC_CAPTCHA_PROVIDER CROWDSEC_CAPTCHA_SITE_KEY CROWDSEC_CAPTCHA_SECRET_KEY; do \
			if grep -q "^$$var=" .env; then \
				sed -i -E "s|^$$var=.*|$$var=|" .env; \
			else \
				echo "$$var=" >> .env; \
			fi; \
		done; \
		printf "name: default_ip_remediation\nfilters:\n  - Alert.Remediation == true && Alert.GetScope() == \"Ip\"\ndecisions:\n  - type: ban\n    duration: 4h\non_success: break\n" > ./crowdsec/profiles.yaml; \
		echo -e "$(CLR_YELLOW)[✔] Captcha skipped/disabled (CrowdSec will enforce HTTP 403 Ban remediation).$(CLR_RESET)"; \
	else \
		read -p "Enter Captcha grace period in seconds [default 1800 (30m)]: " grace_sec </dev/tty; \
		grace_sec=$${grace_sec:-1800}; \
		echo "Select CrowdSec remediation profile mode:"; \
		echo "  1) Mixed: Captcha for first 3 HTTP alerts in 24h, then Ban [recommended]"; \
		echo "  2) Captcha-only for all HTTP scenario alerts"; \
		read -p "Choose [1/2, default 1]: " prof_choice </dev/tty; \
		if [ "$$prof_choice" = "2" ] && [ -f ./crowdsec/profiles_captcha_only.yaml ]; then \
			cp ./crowdsec/profiles_captcha_only.yaml ./crowdsec/profiles.yaml; \
			echo -e "$(CLR_GREEN)[✔] Activated Captcha-only HTTP profile in crowdsec/profiles.yaml.$(CLR_RESET)"; \
		else \
			printf "name: captcha_remediation\nfilters:\n  - Alert.Remediation == true && Alert.GetScope() == \"Ip\" && Alert.GetScenario() contains \"http\" && GetDecisionsSinceCount(Alert.GetValue(), \"24h\") <= 3\ndecisions:\n  - type: captcha\n    duration: 4h\non_success: break\n---\nname: default_ip_remediation\nfilters:\n  - Alert.Remediation == true && Alert.GetScope() == \"Ip\"\ndecisions:\n  - type: ban\n    duration: 4h\non_success: break\n" > ./crowdsec/profiles.yaml; \
			echo -e "$(CLR_GREEN)[✔] Activated Mixed (Captcha + Ban) profile in crowdsec/profiles.yaml.$(CLR_RESET)"; \
		fi; \
		grep -q '^CROWDSEC_CAPTCHA_PROVIDER=' .env && sed -i -E "s|^CROWDSEC_CAPTCHA_PROVIDER=.*|CROWDSEC_CAPTCHA_PROVIDER=$$selected_prov|" .env || echo "CROWDSEC_CAPTCHA_PROVIDER=$$selected_prov" >> .env; \
		grep -q '^CROWDSEC_CAPTCHA_SITE_KEY=' .env && sed -i -E "s|^CROWDSEC_CAPTCHA_SITE_KEY=.*|CROWDSEC_CAPTCHA_SITE_KEY=$$site_key|" .env || echo "CROWDSEC_CAPTCHA_SITE_KEY=$$site_key" >> .env; \
		grep -q '^CROWDSEC_CAPTCHA_SECRET_KEY=' .env && sed -i -E "s|^CROWDSEC_CAPTCHA_SECRET_KEY=.*|CROWDSEC_CAPTCHA_SECRET_KEY=$$secret_key|" .env || echo "CROWDSEC_CAPTCHA_SECRET_KEY=$$secret_key" >> .env; \
		grep -q '^CROWDSEC_CAPTCHA_GRACE_PERIOD=' .env && sed -i -E "s|^CROWDSEC_CAPTCHA_GRACE_PERIOD=.*|CROWDSEC_CAPTCHA_GRACE_PERIOD=$$grace_sec|" .env || echo "CROWDSEC_CAPTCHA_GRACE_PERIOD=$$grace_sec" >> .env; \
		echo -e "$(CLR_GREEN)[✔] CrowdSec Captcha configured with provider '$$selected_prov' (grace period: $${grace_sec}s).$(CLR_RESET)"; \
	fi
	@if [ "$(SKIP_RELOAD)" != "1" ]; then \
		$(MAKE) --no-print-directory reload-if-running; \
	fi

# Enable CrowdSec middleware globally for all endpoints on websecure entrypoint
enable-crowdsec-all: init-env
	@echo -e "$(CLR_YELLOW)[*] Enabling CrowdSec middleware globally for all websecure endpoints...$(CLR_RESET)"
	@if grep -q '^[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"' docker-compose.yml; then \
		echo -e "$(CLR_GREEN)[✔] Global CrowdSec entrypoint middleware is already active.$(CLR_RESET)"; \
	else \
		sed -i -E 's|^[[:space:]]*#[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|      - "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|' docker-compose.yml; \
		echo -e "$(CLR_GREEN)[✔] Added global entrypoint middleware to docker-compose.yml.$(CLR_RESET)"; \
	fi
	@if [ "$$(grep -E '^CROWDSEC_ENABLED=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]')" != "true" ]; then \
		echo -e "$(CLR_YELLOW)[*] CrowdSec core is currently disabled. Starting CrowdSec setup...$(CLR_RESET)"; \
		$(MAKE) --no-print-directory setup-crowdsec; \
	else \
		$(MAKE) --no-print-directory reload-if-running; \
	fi
	@echo -e "$(CLR_GREEN)[✔] All endpoints and routers on websecure are now automatically protected by CrowdSec.$(CLR_RESET)"

enable-crowdsec-global: enable-crowdsec-all

# Disable global CrowdSec middleware on entrypoint (revert to per-service)
disable-crowdsec-all: init-env
	@echo -e "$(CLR_YELLOW)[*] Disabling global entrypoint middleware in docker-compose.yml...$(CLR_RESET)"
	@if grep -q '^[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"' docker-compose.yml; then \
		sed -i -E 's|^[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|      # - "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|' docker-compose.yml; \
		echo -e "$(CLR_GREEN)[✔] Global entrypoint middleware commented out.$(CLR_RESET)"; \
		$(MAKE) --no-print-directory reload-if-running; \
		echo -e "$(CLR_GREEN)[✔] Reverted to per-service protection (services can still use router labels).$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_GREEN)[✔] Global entrypoint middleware is already disabled.$(CLR_RESET)"; \
	fi

disable-crowdsec-global: disable-crowdsec-all

# Tail live logs from CrowdSec container
logs-crowdsec:
	@if command -v docker >/dev/null 2>&1; then \
		sudo docker compose logs -f crowdsec; \
	else \
		echo -e "$(CLR_RED)[!] Docker command not found.$(CLR_RESET)"; \
	fi

# Detailed CrowdSec Security Report
crowdsec-report: init-env
	@echo ""
	@echo -e "$(CLR_CYAN)╔══════════════════════════════════════════════════════════════════════════════╗$(CLR_RESET)"
	@echo -e "$(CLR_CYAN)║$(CLR_RESET)                   $(CLR_BOLD)$(CLR_WHITE)CROWDSEC DETAILED SECURITY REPORT$(CLR_RESET)                         $(CLR_CYAN)║$(CLR_RESET)"
	@echo -e "$(CLR_CYAN)╚══════════════════════════════════════════════════════════════════════════════╝$(CLR_RESET)"
	@if ! command -v docker >/dev/null 2>&1; then \
		echo -e "$(CLR_RED)[!] Docker is not installed or running.$(CLR_RESET)"; \
		exit 1; \
	fi
	@CS_ID=$$(sudo docker compose ps -q crowdsec 2>/dev/null || sudo docker ps -q -f name=^/crowdsec$$ 2>/dev/null); \
	if [ -z "$$CS_ID" ]; then \
		echo -e "$(CLR_RED)[!] CrowdSec container is not currently running.$(CLR_RESET)"; \
		echo -e "    Run $(CLR_GREEN)make setup-crowdsec$(CLR_RESET) to configure and start CrowdSec."; \
		exit 0; \
	fi
	@echo -e "$(CLR_YELLOW)[1] Registered Bouncers:$(CLR_RESET)"
	@sudo docker exec crowdsec cscli bouncers list 2>/dev/null || echo "Unable to query bouncers"
	@echo ""
	@echo -e "$(CLR_YELLOW)[2] Active Decisions (Bans & Captchas):$(CLR_RESET)"
	@sudo docker exec crowdsec cscli decisions list 2>/dev/null || echo "Unable to query decisions"
	@echo ""
	@echo -e "$(CLR_YELLOW)[3] Log Acquisition & Metrics Summary:$(CLR_RESET)"
	@sudo docker exec crowdsec cscli metrics 2>/dev/null || echo "Unable to query metrics"
	@echo ""

cs-report: crowdsec-report

# List active CrowdSec IP bans and decisions
crowdsec-bans: init-env
	@if ! command -v docker >/dev/null 2>&1; then \
		echo -e "$(CLR_RED)[!] Docker is not installed or running.$(CLR_RESET)"; \
		exit 1; \
	fi
	@CS_ID=$$(sudo docker compose ps -q crowdsec 2>/dev/null || sudo docker ps -q -f name=^/crowdsec$$ 2>/dev/null); \
	if [ -z "$$CS_ID" ]; then \
		echo -e "$(CLR_RED)[!] CrowdSec container is not currently running.$(CLR_RESET)"; \
		exit 1; \
	fi
	@echo -e "$(CLR_CYAN)[*] Active CrowdSec IP Bans & Captcha Decisions:$(CLR_RESET)"
	@sudo docker exec crowdsec cscli decisions list

bans: crowdsec-bans
cs-bans: crowdsec-bans
crowdsec-decisions: crowdsec-bans

# Trigger a test Captcha decision for an IP (Usage: make captcha-test IP=1.2.3.4 or interactive)
crowdsec-captcha-test: init-env
	@if ! command -v docker >/dev/null 2>&1; then \
		echo -e "$(CLR_RED)[!] Docker is not installed or running.$(CLR_RESET)"; \
		exit 1; \
	fi
	@CS_ID=$$(sudo docker compose ps -q crowdsec 2>/dev/null || sudo docker ps -q -f name=^/crowdsec$$ 2>/dev/null); \
	if [ -z "$$CS_ID" ]; then \
		echo -e "$(CLR_RED)[!] CrowdSec container is not currently running.$(CLR_RESET)"; \
		exit 1; \
	fi
	@target_ip="$(IP)"; \
	if [ -z "$$target_ip" ]; then \
		read -p "Enter IP address to challenge with Captcha (4h): " target_ip </dev/tty; \
	fi; \
	if [ -z "$$target_ip" ]; then \
		echo -e "$(CLR_RED)[!] No IP address specified.$(CLR_RESET)"; \
		exit 1; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Adding 4h Captcha decision for IP $$target_ip...$(CLR_RESET)"; \
	if sudo docker exec crowdsec cscli decisions add --ip "$$target_ip" -d 4h --type captcha; then \
		echo -e "$(CLR_GREEN)[✔] Captcha decision added for $$target_ip (note: if $$target_ip is in clientTrustedIPs, remove it from clientTrustedIPs to test).$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_RED)[!] Failed to add Captcha decision for IP $$target_ip.$(CLR_RESET)"; \
	fi

captcha-test: crowdsec-captcha-test

# Unban / remove decisions for an IP address (Usage: make crowdsec-unban IP=1.2.3.4 or interactive)
crowdsec-unban: init-env
	@if ! command -v docker >/dev/null 2>&1; then \
		echo -e "$(CLR_RED)[!] Docker is not installed or running.$(CLR_RESET)"; \
		exit 1; \
	fi
	@CS_ID=$$(sudo docker compose ps -q crowdsec 2>/dev/null || sudo docker ps -q -f name=^/crowdsec$$ 2>/dev/null); \
	if [ -z "$$CS_ID" ]; then \
		echo -e "$(CLR_RED)[!] CrowdSec container is not currently running.$(CLR_RESET)"; \
		exit 1; \
	fi
	@target_ip="$(IP)"; \
	if [ -z "$$target_ip" ]; then \
		read -p "Enter IP address to unban / clear decisions: " target_ip </dev/tty; \
	fi; \
	if [ -z "$$target_ip" ]; then \
		echo -e "$(CLR_RED)[!] No IP address specified.$(CLR_RESET)"; \
		exit 1; \
	fi; \
	echo -e "$(CLR_YELLOW)[*] Removing active ban/captcha decisions for IP $$target_ip...$(CLR_RESET)"; \
	if sudo docker exec crowdsec cscli decisions delete --ip "$$target_ip"; then \
		echo -e "$(CLR_GREEN)[✔] Decisions for IP $$target_ip successfully removed.$(CLR_RESET)"; \
	else \
		echo -e "$(CLR_RED)[!] Failed to remove decisions for IP $$target_ip.$(CLR_RESET)"; \
	fi

unban: crowdsec-unban

# Disable CrowdSec and stop container
disable-crowdsec: init-env
	@echo -e "$(CLR_YELLOW)[*] Disabling CrowdSec Intrusion Prevention...$(CLR_RESET)"
	@if grep -q '^CROWDSEC_ENABLED=' .env; then \
		sed -i -E "s|^CROWDSEC_ENABLED=.*|CROWDSEC_ENABLED=false|" .env; \
	else \
		echo "CROWDSEC_ENABLED=false" >> .env; \
	fi
	@if grep -q '^COMPOSE_PROFILES=' .env; then \
		sed -i -E "s|^COMPOSE_PROFILES=.*|COMPOSE_PROFILES=|" .env; \
	else \
		echo "COMPOSE_PROFILES=" >> .env; \
	fi
	@if grep -q '^[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"' docker-compose.yml; then \
		sed -i -E 's|^[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|      # - "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"|' docker-compose.yml; \
	fi
	@if command -v docker >/dev/null 2>&1; then \
		if [ -n "$$(sudo docker compose ps -q crowdsec 2>/dev/null)" ] || [ -n "$$(sudo docker ps -q -f name=^/crowdsec$$ 2>/dev/null)" ]; then \
			echo -e "$(CLR_YELLOW)[*] Stopping and removing CrowdSec container...$(CLR_RESET)"; \
			sudo docker compose stop crowdsec 2>/dev/null || true; \
			sudo docker compose rm -f crowdsec 2>/dev/null || true; \
		fi; \
	fi
	@echo -e "$(CLR_GREEN)[✔] CrowdSec disabled successfully.$(CLR_RESET)"
	@$(MAKE) --no-print-directory reload-if-running

# Color formatted status report box
report: init-env
	@AUTH_SET=$$(grep -E '^TRAEFIK_BASIC_AUTH_USERS=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	ACME_SET=$$(grep -E '^ACME_EMAIL=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	CF_SET=$$(grep -E '^CF_DNS_API_TOKEN=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	DOM_SET=$$(grep -E '^TRAEFIK_DASHBOARD_DOMAIN=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	RES_SET=$$(grep -E '^TRAEFIK_DASHBOARD_CERTRESOLVER=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	CS_ENABLED=$$(grep -E '^CROWDSEC_ENABLED=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	CS_KEY=$$(grep -E '^CROWDSEC_BOUNCER_KEY=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	CAP_PROV=$$(grep -E '^CROWDSEC_CAPTCHA_PROVIDER=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	CAP_SITE=$$(grep -E '^CROWDSEC_CAPTCHA_SITE_KEY=' .env 2>/dev/null | cut -d '=' -f2- | tr -d '[:space:]'); \
	PORT_CHECK="Open (80, 443)"; \
	sudo iptables -C INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT 2>/dev/null || PORT_CHECK="Needs Attention"; \
	PERM_CHECK="Not Set"; \
	[ -f ./acme.json ] && PERM_CHECK="$$(stat -c '%a' ./acme.json 2>/dev/null || stat -f '%Lp' ./acme.json 2>/dev/null)"; \
	[ -z "$$AUTH_SET" ] || [ "$$AUTH_SET" = 'admin:$$apr1$$8cvG1.rX$$1pE7aV6.Dph7H9z1oJbXQ0' ] && AUTH_STATUS="Default/Unset" || AUTH_STATUS="Configured"; \
	[ -z "$$ACME_SET" ] || [ "$$ACME_SET" = "admin@example.com" ] && ACME_STATUS="Not Set (Skipped)" || ACME_STATUS="$$ACME_SET"; \
	[ -z "$$CF_SET" ] || [ "$$CF_SET" = "your_cloudflare_api_token_here" ] && CF_STATUS="Disabled (Skipped)" || CF_STATUS="Configured"; \
	[ -z "$$DOM_SET" ] || [ "$$DOM_SET" = "traefik.example.com" ] && DOM_STATUS="Default (traefik.example.com)" || DOM_STATUS="$$DOM_SET"; \
	[ "$$RES_SET" = "cloudflare_resolver" ] && RES_STATUS="Cloudflare DNS-01" || RES_STATUS="Let's Encrypt HTTP-01"; \
	[ "$$CS_ENABLED" = "true" ] && [ -n "$$CS_KEY" ] && CS_STATUS="Enabled" || CS_STATUS="Disabled"; \
	[ -n "$$CAP_PROV" ] && [ -n "$$CAP_SITE" ] && CAP_STATUS="Enabled ($$CAP_PROV)" || CAP_STATUS="Disabled (Ban only)"; \
	CS_SCOPE="Per-Service"; \
	grep -q '^[[:space:]]*- "--entrypoints.websecure.http.middlewares=crowdsec-bouncer@docker"' docker-compose.yml 2>/dev/null && CS_SCOPE="All Endpoints (Global)"; \
	CS_RUNNING="Stopped"; \
	command -v docker >/dev/null 2>&1 && [ -n "$$(sudo docker compose ps -q crowdsec 2>/dev/null || sudo docker ps -q -f name=^/crowdsec$$ 2>/dev/null)" ] && CS_RUNNING="Running"; \
	echo ""; \
	echo -e "$(CLR_CYAN)╔══════════════════════════════════════════════════════════════════════════════╗$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)║$(CLR_RESET)                   $(CLR_BOLD)$(CLR_WHITE)TRAEFIK CONFIGURATION & STATUS REPORT$(CLR_RESET)                      $(CLR_CYAN)║$(CLR_RESET)"; \
	echo -e "$(CLR_CYAN)╠══════════════════════════════════════════════════════════════════════════════╣$(CLR_RESET)"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Dashboard Domain" "$$DOM_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Dashboard TLS Resolver" "$$RES_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Basic Auth Status" "$$AUTH_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "ACME Notification Email" "$$ACME_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Cloudflare DNS Token" "$$CF_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "CrowdSec IPS (Bouncer)" "$$CS_STATUS ($$CS_RUNNING)"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "CrowdSec Captcha" "$$CAP_STATUS"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "CrowdSec Scope" "$$CS_SCOPE"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)%-45s$(CLR_RESET)$(CLR_CYAN)║$(CLR_RESET)\n" "Firewall Ports" "$$PORT_CHECK"; \
	printf "$(CLR_CYAN)║$(CLR_RESET)  $(CLR_YELLOW)%-25s$(CLR_RESET) : $(CLR_WHITE)acme.json (perms: %-27s)$(CLR_CYAN)║$(CLR_RESET)\n" "ACME Storage" "$$PERM_CHECK"; \
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
setup-all: init-env setup-firewall setup-certs setup-auth setup-acme setup-cloudflare setup-dashboard setup-crowdsec report reload-if-running

install-traefik: check-docker setup-all
	@if [ -z "$$(sudo docker compose ps -q traefik 2>/dev/null)" ] && [ -z "$$(sudo docker ps -q -f name=^/traefik$$ 2>/dev/null)" ]; then \
		echo -e "$(CLR_GREEN)[*] Starting Traefik via Docker Compose...$(CLR_RESET)"; \
		sudo docker compose up -d; \
		echo -e "$(CLR_GREEN)[✔] Traefik deployed successfully.$(CLR_RESET)"; \
	fi
