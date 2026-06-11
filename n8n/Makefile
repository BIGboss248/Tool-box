.PHONY: up down restart logs status shell

# Detect OS to handle directory creation and permissions correctly
ifeq ($(OS),Windows_NT)
    CREATE_DIR = if not exist n8n_data mkdir n8n_data
else
    # On Linux/macOS, we pre-create the directory and set permissions/ownership
    # n8n container runs as user 'node' (UID/GID 1000)
    CREATE_DIR = mkdir -p n8n_data && (chown -R 1000:1000 n8n_data 2>/dev/null || chmod -R 775 n8n_data 2>/dev/null || true)
endif

# Start n8n in detached mode
up:
	@$(CREATE_DIR)
	docker compose up -d

# Stop and remove containers
down:
	docker compose down

# Restart n8n container
restart:
	docker compose restart

# Follow real-time logs
logs:
	docker compose logs -f

# Check container status
status:
	docker compose ps

# Access the container's shell
shell:
	docker compose exec -it n8n /bin/sh
