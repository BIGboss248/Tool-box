.PHONY: all volumes deploy down restart status clean logs deploy-capture down-capture logs-capture status-capture

# Load environment variables from .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

# Default target
all: deploy

# Create the host directories for bind-mounted volumes
volumes:
	@echo "Creating local volume directories..."
	mkdir -p mongo/data
	sudo chown -R 999:999 mongo/data

# Deploy the services
deploy: volumes
	@echo "Starting services..."
	docker compose up -d

# Take down the services
down:
	@echo "Stopping services..."
	docker compose down

# Restart the services
restart: down deploy

# Check container status
status:
	docker compose ps

# View service logs
logs:
	docker compose logs -f

# Clean up data (use with caution!)
clean: down
	@echo "Cleaning up local volume data..."
	rm -rf mongo/data

# Deploy the capture agent
deploy-capture:
	@if [ -z "$(API_SECRET)" ]; then \
		echo "API_SECRET is not set. Generating a random one..."; \
		generated_secret=$$(openssl rand -hex 32); \
		if [ -f $$HOME/.bashrc ]; then \
			if ! grep -q "API_SECRET=" $$HOME/.bashrc; then \
				echo "export API_SECRET=$$generated_secret" >> $$HOME/.bashrc; \
			fi; \
		fi; \
		if [ -f $$HOME/.zshrc ]; then \
			if ! grep -q "API_SECRET=" $$HOME/.zshrc; then \
				echo "export API_SECRET=$$generated_secret" >> $$HOME/.zshrc; \
			fi; \
		fi; \
		if [ -f $$HOME/.profile ]; then \
			if ! grep -q "API_SECRET=" $$HOME/.profile; then \
				echo "export API_SECRET=$$generated_secret" >> $$HOME/.profile; \
			fi; \
		fi; \
		printf "\033[32mGenerated and saved API_SECRET to host profile: %s\033[0m\n" "$$generated_secret"; \
		printf "\033[32mPlease run 'source ~/.bashrc' (or source your shell's config file) to update your current terminal session.\033[0m\n"; \
		API_SECRET_VAL=$$generated_secret; \
	else \
		API_SECRET_VAL="$(API_SECRET)"; \
	fi; \
	echo "Stopping and removing existing capture container if it exists..."; \
	docker rm -f capture || true; \
	echo "Deploying capture agent..."; \
	docker run \
	  --name capture \
	  -v /etc/os-release:/etc/os-release:ro \
	  -p 59232:59232 \
	  -e API_SECRET=$$API_SECRET_VAL \
	  -d ghcr.io/bluewave-labs/capture:latest; \
	vps_ip=$$(curl -s ifconfig.me || curl -s icanhazip.com || hostname -I | awk '{print $$1}' || echo "localhost"); \
	msg="Metrics are available at http://$$vps_ip:59232/api/v1/metrics"; \
	len=$${#msg}; \
	border=""; i=0; while [ $$i -lt $$((len + 4)) ]; do border="$${border}═"; i=$$((i+1)); done; \
	printf "\033[32m╔%s╗\033[0m\n" "$$border"; \
	printf "\033[32m║  %s  ║\033[0m\n" "$$msg"; \
	printf "\033[32m╚%s╝\033[0m\n" "$$border"

# Take down the capture agent
down-capture:
	@echo "Stopping capture agent..."
	docker rm -f capture || true

# View capture agent logs
logs-capture:
	docker logs -f capture

# Check capture agent status
status-capture:
	docker ps -f name=capture
