
include ../makefiles/Makefile



orb_docker_install:
	sudo docker compose up -d
	echo "Orb deployed successfully"

orb_docker_stop:
	sudo docker compose down
	echo "Orb stopped successfully"

orb_docker_remove:
	sudo docker compose down
	sudo rm -rf ./orb-data
	echo "Orb removed successfully"
