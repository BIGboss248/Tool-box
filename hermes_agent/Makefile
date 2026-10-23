.PHONY: up down restart logs status shell setup

# Detect OS to handle directory creation correctly
ifeq ($(OS),Windows_NT)
    CREATE_DIR = if not exist data mkdir data
else
    CREATE_DIR = mkdir -p data && chmod -R 775 data 2>/dev/null || true
endif

# Run initial setup wizard inside an ephemeral container
setup:
	@$(CREATE_DIR)
	docker run -it --rm -v $(CURDIR)/data:/opt/data nousresearch/hermes-agent setup

# Start Hermes Agent gateway in detached mode
up:
	@$(CREATE_DIR)
	docker compose up -d

# Stop and remove containers
down:
	docker compose down

# Restart the Hermes container
restart:
	docker compose restart

# Follow real-time logs
logs:
	docker compose logs -f

# Check container status
status:
	docker compose ps

# Access the container shell
shell:
	docker compose exec -it hermes /bin/bash

# Access the Hermes CLI inside the running container
cli:
	docker compose exec -it hermes hermes
