SHELL := /bin/bash

.PHONY: help deploy install setup open-ports up down restart logs status credentials creds

.DEFAULT_GOAL := help

help:
	@echo "Available commands:"
	@echo "  make deploy       - Open ports and deploy Nova node container"
	@echo "  make install      - Open ports and install Nova node via shell script"
	@echo "  make open-ports   - Open required ports persistently across reboots"
	@echo "  make credentials  - Show admin credentials and panel info"
	@echo "  make logs         - View container logs"
	@echo "  make status       - Show container status"
	@echo "  make down         - Stop and remove container"
	@echo "  make restart      - Restart container"

deploy: open-ports up

install: open-ports
	bash <(curl -fsSL https://raw.githubusercontent.com/IRNova/Nova-Server/main/nova-node.sh)

setup: install

open-ports:
	@echo "\033[1;36mOpening required ports (80/tcp, 443/tcp, 443/udp, 2053/tcp, 2083/tcp, 2087/tcp, 2096/tcp, 8443/tcp) persistently...\033[0m"
	@if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q "Status: active"; then \
		echo "Detected active UFW firewall. Adding persistent rules..."; \
		for port in 80 443 2053 2083 2087 2096 8443; do \
			sudo ufw allow $$port/tcp; \
		done; \
		sudo ufw allow 443/udp; \
	elif command -v firewall-cmd >/dev/null 2>&1 && sudo systemctl is-active --quiet firewalld; then \
		echo "Detected active firewalld. Adding permanent rules..."; \
		for port in 80 443 2053 2083 2087 2096 8443; do \
			sudo firewall-cmd --permanent --add-port=$$port/tcp; \
		done; \
		sudo firewall-cmd --permanent --add-port=443/udp; \
		sudo firewall-cmd --reload; \
	elif command -v iptables >/dev/null 2>&1; then \
		echo "Applying iptables rules..."; \
		for port in 80 443 2053 2083 2087 2096 8443; do \
			sudo iptables -C INPUT -p tcp --dport $$port -j ACCEPT >/dev/null 2>&1 || sudo iptables -I INPUT -p tcp --dport $$port -j ACCEPT; \
		done; \
		sudo iptables -C INPUT -p udp --dport 443 -j ACCEPT >/dev/null 2>&1 || sudo iptables -I INPUT -p udp --dport 443 -j ACCEPT; \
		if command -v netfilter-persistent >/dev/null 2>&1; then \
			sudo netfilter-persistent save; \
		elif command -v iptables-save >/dev/null 2>&1; then \
			sudo mkdir -p /etc/iptables && sudo iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null 2>&1 || true; \
		fi; \
	else \
		echo "No supported firewall management tool (ufw, firewalld, iptables) active. Ensure ports 80, 443, 2053, 2083, 2087, 2096, 8443 are open on host."; \
	fi

up:
	@printf "\033[1;33m┌────────────────────────────────────────────────────────────────┐\033[0m\n"
	@printf "\033[1;33m│                                                                │\033[0m\n"
	@printf "\033[1;33m│  The container downloads dependencies and might take up to     │\033[0m\n"
	@printf "\033[1;33m│  5 minutes to deploy.                                          │\033[0m\n"
	@printf "\033[1;33m│                                                                │\033[0m\n"
	@printf "\033[1;33m└────────────────────────────────────────────────────────────────┘\033[0m\n"
	sudo docker compose up -d

credentials: creds

creds:
	sudo docker exec nova-node journalctl -u nova-firstboot.service --no-pager | grep -E "(Server address|Admin password|Web panel|Subscription)"

logs:
	sudo docker compose logs -f nova-node

status:
	sudo docker compose ps

down:
	sudo docker compose down

restart:
	sudo docker compose restart
