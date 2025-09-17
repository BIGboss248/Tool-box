
include ../Makefile

install_nginx:
	if nginx -v; then \
		echo -e "\e[32mNginx already installed\e[0m"; \
	else \
		sudo apt update; \
		sudo apt install -y nginx; \
	fi

install_certbot:
	sudo apt update
	sudo apt install snapd -y
	sudo snap install core; sudo snap refresh core
	sudo snap install --classic certbot
	sudo ln -s /snap/bin/certbot /usr/bin/certbot || true
	sudo snap set certbot trust-plugin-with-root=ok

certbot_cloudflare_ssl_token: certbot
	if [ -f ~/.cloudflare/credentials.ini ]; then \
		echo -e "\e[32mCloudflare credentials already exist\e[0m"; \
	else \
	mkdir ~/.cloudflare || true; \
	touch ~/.cloudflare/credentials.ini; \
	echo "dns_cloudflare_api_token = $(CF_API_TOKEN)" > ~/.cloudflare/credentials.ini; \
	chmod 600 ~/.cloudflare/credentials.ini; \
	sudo snap install certbot-dns-cloudflare; \
	fi

nginx_setup_ssl_domain: certbot_cloudflare nginx
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport 80
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport 443
	sudo certbot certonly --dns-cloudflare --agree-tos --no-eff-email --dns-cloudflare --dns-cloudflare-credentials ~/.cloudflare/credentials.ini -d $(DOMAIN)
	sudo certbot renew --dry-run
	sudo apt install iptables-persistent -y
	sudo bash -c iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
	sudo netfilter-persistent save
	echo -e "\e[32m=================================================================================\e[0m"
	echo -e "\e[32mIF running a service on another port dont forget to open it in firewall\e[0m"
	echo -e "\e[32mchange configuration in /etc/nginx/sites-available/default and restart nginx\e[0m"
	echo -e "\e[32m=================================================================================\e[0m"
	code /etc/nginx/sites-available/default
	sudo systemctl restart nginx
