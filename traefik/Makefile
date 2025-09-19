
include ../Makefile

prerequsite-makefile:
	sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
	sudo touch ./acme.json
	sudo chmod 600 acme.json
install-traefik: docker prerequsite-makefile
	code .env
	echo -e "\033[0;32mFill the .env file with your domain and email press enter to continue\033[0m"
	read -p "Press [Enter] key to continue..."
	sudo docker compose up -d
	echo -e "\033[0;32m==============================================================================================\033[0m"
	echo -e "\033[0;32mTraefik is deployed access logs are in /logs/access.log and prometheus is exposed on port 8082\033[0m"
	echo -e "\033[0;32m==============================================================================================\033[0m"
