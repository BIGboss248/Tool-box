
include ../Makefile

install:
	sudo apt install postgresql -y
	wget -q -O - https://nightly.odoo.com/odoo.key | sudo gpg --dearmor -o /usr/share/keyrings/odoo-archive-keyring.gpg
	echo 'deb [signed-by=/usr/share/keyrings/odoo-archive-keyring.gpg] https://nightly.odoo.com/18.0/nightly/deb/ ./' | sudo tee /etc/apt/sources.list.d/odoo.list
	sudo apt-get update && sudo apt-get install odoo
	echo "Visit http://$(curl -s ifconfig.me):8069/app"

install_docker: docker
	sudo docker compose up -d
	echo "Visit http://$(curl -s ifconfig.me):8069/app"
