
include ../Makefile



help:
	@echo "Available make targets:"
	@echo "  help: Display this help message"
	@echo "  xui_docker_setup: Setup x-ui using docker compose"
	@echo "  xui_docker_stop: Stop x-ui docker containers"
	@echo "  xui_docker_remove: Remove x-ui docker containers and data"
	@echo "  xui_setup: Setup x-ui using the official script"

xui_docker_setup: docker
	sudo docker compose up -d
	echo "In local deployment make sure all trafic except api.telegram.org is routed directly"

xui_docker_stop:
	sudo docker compose stop

xui_docker_remove: docker
	sudo docker compose down
	sudo rm -rf ./db ./cert

xui_setup:
	bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
