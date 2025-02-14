up:
	sudo docker compose up -d
down:
	sudo docker compose down
setup:
	touch .env
	echo "PG_PASS=$$(openssl rand -base64 36 | tr -d '\n')" >> .env
	echo "AUTHENTIK_SECRET_KEY=$$(openssl rand -base64 60 | tr -d '\n')" >> .env
