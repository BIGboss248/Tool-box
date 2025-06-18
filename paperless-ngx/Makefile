
include ../Makefile

postgres_docker_setup:
	code docker-compose.yml
	echo "Set env variables"
	read -p
	echo "Run docker compose"
	sudo docker compose up -d

sqlite_docker_setup:
	code docker-compose-sqlite.yml
	echo "Set env variables"
	read -p
	echo "Run docker compose"
	sudo docker compose -f docker-compose-sqlite.yml up -d
