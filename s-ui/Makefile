


include ../Makefile


install_docker: docker
	echo "deploying with docker compsoe"
	sudo docker compose up -d

install:
	bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh)

uninstall:
	sudo systemctl disable s-ui  --now
	sudo rm -f /etc/systemd/system/sing-box.service
	sudo systemctl daemon-reload
	sudo rm -fr /usr/local/s-ui
	sudo rm /usr/bin/s-ui

uninstall_docker:
	sudo docker compose down
