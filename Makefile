SHELL = /bin/bash  # Force Make to use Bash
machine:= $(shell uname -m)
ifeq ($(machine),aarch64)
arch:=arm64
else
arch:=amd64
endif
kompose_download_link=https://github.com/kubernetes/kompose/releases/download/v1.35.0/kompose-linux-$(arch)
.PHONY: kubernetes kompose docker minikube kubeadm open_ports vscode_extention zerotier zerotier_vpn webmin nginx certbot certbot_cloudflare certbot_nginx node_exporter

ssr:
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport $(PORT)
	wget https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocksR.sh
	sudo chmod +x shadowsocksR.sh
	sudo apt install gcc
	sudo ./shadowsocksR.sh 2>&1 | tee shadowsocksR.log

kubernetes: docker
	if kubectl; \
	then \
		echo -e "\e[32mKubernetes already installed\e[0m"; \
	else \
		sudo apt-get update; \
		sudo apt-get install -y apt-transport-https ca-certificates curl gnupg; \
		curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list; \
		sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list; \
		sudo apt-get update; \
		sudo apt-get install -y kubectl; \
	fi

kompose:
	if kompose version;\
	then \
		echo -e "\e[32mKompose already installed\e[0m"; \
	else \
		curl -L "$(kompose_download_link)" -o kompose; \
		chmod +x kompose; \
		sudo mv ./kompose /usr/local/bin/kompose; \
	fi

docker:
	@if command -v docker >/dev/null 2>&1; \
	then \
		echo -e "\e[32mDocker already installed\e[0m"; \
	else \
		for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $$pkg -y; done; \
		# Add Docker's official GPG key: \
		sudo apt-get update -y; \
		sudo apt-get install ca-certificates curl -y; \
		sudo install -m 0755 -d /etc/apt/keyrings; \
		sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; \
		sudo chmod a+r /etc/apt/keyrings/docker.asc; \
		# Add the repository to Apt sources: \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $$(. /etc/os-release && echo "$$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null; \
		sudo apt-get update -y; \
		sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y --fix-missing; \
		sudo groupadd docker || true; \
		sudo usermod -aG docker $$USER && newgrp docker; \
		sudo chown "$$USER":"$$USER" /home/"$$USER"/.docker -R || true; \
		sudo chmod g+rwx "$$HOME/.docker" -R || true; \
		sudo systemctl enable docker.service; \
		sudo systemctl enable containerd.service; \
		code --install-extension ms-azuretools.vscode-docker; \
		echo -e "\e[32mFor vscode extentions reboot is needed\e[0m"; \
		sudo iptables -I FORWARD -p tcp -j ACCEPT -i docker0; \
	fi

minikube: kubernetes
	if minikube version;\
	then\
		echo -e "\e[32mMinikube already installed\e[0m";\
	else\
		curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-$(arch);\
		sudo install minikube-linux-$(arch) /usr/local/bin/minikube && rm minikube-linux-$(arch);\
		sudo usermod -aG docker $$USER && newgrp docker;\
	fi

kubeadm: kubernetes
	if kubeadm version; \
	then\
		echo -e "\e[32mKubeadm is already installed\e[0m"; \
	else\
		sudo swapoff -a; \
		sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab; \
		sudo lsmod | grep br_netfilter; \
		sudo sudo modprobe br_netfilter; \
		sudo cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf; \
		net.bridge.bridge-nf-call-ip6tables = 1; \
		net.bridge.bridge-nf-call-iptables = 1; \
		EOF; \
		sudo sysctl --system; \
		cat <<EOF | sudo tee /etc/docker/daemon.json; \
		{\
		"exec-opts": ["native.cgroupdriver=systemd"],; \
		"log-driver": "json-file",; \
		"log-opts": {; \
			"max-size": "100m"; \
		},\
		"storage-driver": "overlay2"; \
		}\
		EOF; \
		sudo systemctl daemon-reload; \
		sudo systemctl enable docker; \
		sudo systemctl restart docker; \
		sudo systemctl status docker; \
		sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gpg; \
		sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list; \
		sudo apt-get update; \
		sudo apt-get install -y kubelet kubeadm; \
		sudo apt-mark hold kubelet kubeadm; \
		sudo systemctl daemon-reload; \
		sudo systemctl enable kubelet; \
		sudo systemctl restart kubelet; \
		sudo systemctl status kubelet; \
		sudo rm /etc/containerd/config.toml; \
		sudo systemctl restart containerd; \
		sudo kubeadm init; \
		mkdir -p HOME/.kube; \
		sudo cp -i /etc/kubernetes/admin.conf HOME/.kube/config; \
		sudo chown $(id -u):$(id -g) HOME/.kube/config; \
	fi

open_ports:	# make open_ports port=80
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport $(PORT)

vscode_extention:
	code --install-extension ms-azuretools.vscode-docker
	code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
	code --install-extension ms-vscode.makefile-tools
	code --install-extension aaron-bond.better-comments
	code --install-extension mutantdino.resourcemonitor

zerotier:
	curl -s https://install.zerotier.com/ | sudo bash
	sudo zerotier-cli join $(ZEROTIER_NETWORK_ID)

zerotier_vpn:
	sudo sysctl -w net.ipv4.ip_forward=1
	sudo sysctl -p
	sudo sysctl net.ipv4.ip_forward
	# ip link show
	sudo iptables -t nat -I POSTROUTING -o "$(PHY_IFACE)" -j MASQUERADE
	sudo iptables -I FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -I FORWARD -i "$(PHY_IFACE)" -o "$(ZT_IFACE)" -m state --state RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -I FORWARD -i "$(ZT_IFACE)" -o "$(PHY_IFACE)" -j ACCEPT
	sudo apt install iptables-persistent
	sudo bash -c iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
	sudo netfilter-persistent save

webmin:
	curl -o webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
	sudo sh webmin-setup-repo.sh
	sudo apt-get install webmin --install-recommends
	echo -e "\e[32mSetting root password to be able to login\e[0m"
	sudo passwd root

nginx:
	code --install-extension ahmadalli.vscode-nginx-conf
	if nginx -v; then \
		echo -e "\e[32mNginx already installed\e[0m"; \
	else \
		sudo apt update; \
		sudo apt install -y nginx; \
	fi

certbot:
	sudo snap install core; sudo snap refresh core
	sudo snap install --classic certbot
	sudo ln -s /snap/bin/certbot /usr/bin/certbot || true
	sudo snap set certbot trust-plugin-with-root=ok

certbot_cloudflare: certbot
	if [ -f ~/.cloudflare/credentials.ini ]; then \
		echo -e "\e[32mCloudflare credentials already exist\e[0m"; \
	else \
	mkdir ~/.cloudflare || true; \
	touch ~/.cloudflare/credentials.ini; \
	echo "dns_cloudflare_api_token = $(CLOUDFLARE_API_TOKEN)" > ~/.cloudflare/credentials.ini; \
	chmod 600 ~/.cloudflare/credentials.ini; \
	sudo snap install certbot-dns-cloudflare; \
	fi

certbot_nginx: certbot_cloudflare nginx
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport 80
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport 443
	sudo certbot certonly --dns-cloudflare --agree-tos --no-eff-email --dns-cloudflare --dns-cloudflare-credentials ~/.cloudflare/credentials.ini -d $(DOMAIN)
	sudo certbot renew --dry-run

node_exporter:
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport 9100
	if [ -f /usr/local/bin/node_exporter ]; then \
		echo -e "\e[32mNode Exporter already installed\e[0m"; \
	else \
	sudo wget https://github.com/prometheus/node_exporter/releases/download/v1.9.0/node_exporter-1.9.0.linux-$(arch).tar.gz; \
	sudo tar xvfz node_exporter-1.9.0.linux-$(arch).tar.gz; \
	sudo cp node_exporter-1.9.0.linux-$(arch)/node_exporter /usr/local/bin/; \
	sudo rm -rf node_exporter-1.9.0.linux-$(arch) node_exporter-1.9.0.linux-$(arch).tar.gz; \
	fi
	if [ -f /etc/systemd/system/node_exporter.service ]; then \
		echo -e "\e[32mNode Exporter service already exists\e[0m"; \
	else \
		sudo touch /etc/systemd/system/node_exporter.service; \
	echo "[Unit]" | sudo tee /etc/systemd/system/node_exporter.service; \
	echo "Description=Node Exporter" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	echo "After=network.target" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	echo "" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	echo "[Service]" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	echo "Type=simple" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	echo "ExecStart=/usr/local/bin/node_exporter" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	echo "" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	echo "[Install]" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	echo "WantedBy=multi-user.target" | sudo tee -a /etc/systemd/system/node_exporter.service; \
	fi
	sudo systemctl daemon-reload
	sudo systemctl enable node_exporter
	sudo systemctl start node_exporter
	sudo systemctl status node_exporter

starship:
	curl -sS https://starship.rs/install.sh | sudo sh
	echo 'eval "$$(starship init bash)"' >> ~/.bashrc
	mkdir -p ~/.config && sudo touch ~/.config/starship.toml
	export STARSHIP_CONFIG=~/example/non/default/path/starship.toml
	echo '# ~/.config/starship.toml' | sudo tee ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo 'add_newline = false' | sudo tee -a ~/.config/starship.toml
	echo 'command_timeout = 1000' | sudo tee -a ~/.config/starship.toml
	echo 'format = """$$os$$username$$hostname$$kubernetes$$git_branch$$git_status' | sudo tee -a ~/.config/starship.toml
	echo '|$$directory' | sudo tee -a ~/.config/starship.toml
	echo '└─> """' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# Drop ugly default prompt characters' | sudo tee -a ~/.config/starship.toml
	echo '[character]' | sudo tee -a ~/.config/starship.toml
	echo "success_symbol = ''" | sudo tee -a ~/.config/starship.toml
	echo "error_symbol = ''" | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# ---' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[os]' | sudo tee -a ~/.config/starship.toml
	echo "format = '[$$symbol](bold white) '" | sudo tee -a ~/.config/starship.toml
	echo 'disabled = false' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[os.symbols]' | sudo tee -a ~/.config/starship.toml
	echo "Windows = ''" | sudo tee -a ~/.config/starship.toml
	echo "Arch = '󰣇'" | sudo tee -a ~/.config/starship.toml
	echo "Ubuntu = ''" | sudo tee -a ~/.config/starship.toml
	echo "Macos = '󰀵'" | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# ---' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# Shows the username' | sudo tee -a ~/.config/starship.toml
	echo '[username]' | sudo tee -a ~/.config/starship.toml
	echo "style_user = 'white bold'" | sudo tee -a ~/.config/starship.toml
	echo "style_root = 'black bold'" | sudo tee -a ~/.config/starship.toml
	echo "format = '[$$user]($$style) '" | sudo tee -a ~/.config/starship.toml
	echo 'disabled = false' | sudo tee -a ~/.config/starship.toml
	echo 'show_always = true' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# Shows the hostname' | sudo tee -a ~/.config/starship.toml
	echo '[hostname]' | sudo tee -a ~/.config/starship.toml
	echo 'ssh_only = false' | sudo tee -a ~/.config/starship.toml
	echo "format = 'host=>[$$hostname](bold yellow) '" | sudo tee -a ~/.config/starship.toml
	echo 'disabled = false' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# Shows current directory' | sudo tee -a ~/.config/starship.toml
	echo '[directory]' | sudo tee -a ~/.config/starship.toml
	echo 'truncation_length = 70' | sudo tee -a ~/.config/starship.toml
	echo "truncation_symbol = '…/'" | sudo tee -a ~/.config/starship.toml
	echo "home_symbol = '󰋜 ~'" | sudo tee -a ~/.config/starship.toml
	echo "read_only_style = '197'" | sudo tee -a ~/.config/starship.toml
	echo "read_only = '  '" | sudo tee -a ~/.config/starship.toml
	echo "format = 'at [$$path]($$style)[$$read_only]($$read_only_style) '" | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# Shows current git branch' | sudo tee -a ~/.config/starship.toml
	echo '[git_branch]' | sudo tee -a ~/.config/starship.toml
	echo "symbol = ''" | sudo tee -a ~/.config/starship.toml
	echo "format = 'via [$$symbol$$branch]($$style)'" | sudo tee -a ~/.config/starship.toml
	echo "# truncation_length = 4" | sudo tee -a ~/.config/starship.toml
	echo "truncation_symbol = '…/'" | sudo tee -a ~/.config/starship.toml
	echo "style = 'bold green'" | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# Shows current git status' | sudo tee -a ~/.config/starship.toml
	echo '[git_status]' | sudo tee -a ~/.config/starship.toml
	echo "format = '([ \( $$all_status$$ahead_behind\)]($$style) )'" | sudo tee -a ~/.config/starship.toml
	echo "style = 'bold green'" | sudo tee -a ~/.config/starship.toml
	echo "conflicted = '🏳'" | sudo tee -a ~/.config/starship.toml
	echo "up_to_date = ''" | sudo tee -a ~/.config/starship.toml
	echo "untracked = ' '" | sudo tee -a ~/.config/starship.toml
	echo "ahead = '⇡\$${count}'" | sudo tee -a ~/.config/starship.toml
	echo "diverged = '⇕⇡\$${ahead_count}⇣\$${behind_count}'" | sudo tee -a ~/.config/starship.toml
	echo "behind = '⇣\$${count}'" | sudo tee -a ~/.config/starship.toml
	echo "stashed = ' '" | sudo tee -a ~/.config/starship.toml
	echo "modified = ' '" | sudo tee -a ~/.config/starship.toml
	echo "staged = '[++\(\$$count\)](green)'" | sudo tee -a ~/.config/starship.toml
	echo "renamed = '襁 '" | sudo tee -a ~/.config/starship.toml
	echo "deleted = ' '" | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# Shows kubernetes context and namespace' | sudo tee -a ~/.config/starship.toml
	echo '[kubernetes]' | sudo tee -a ~/.config/starship.toml
	echo "format = 'via [󱃾 \$$context\(\$$namespace\)](bold purple) '" | sudo tee -a ~/.config/starship.toml
	echo 'disabled = false' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '# ---' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[package]' | sudo tee -a ~/.config/starship.toml
	echo 'symbol = "󰏗 "' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[pijul_channel]' | sudo tee -a ~/.config/starship.toml
	echo 'symbol = " "' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[python]' | sudo tee -a ~/.config/starship.toml
	echo 'symbol = " "' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[rlang]' | sudo tee -a ~/.config/starship.toml
	echo 'symbol = "󰟔 "' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[ruby]' | sudo tee -a ~/.config/starship.toml
	echo 'symbol = " "' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[rust]' | sudo tee -a ~/.config/starship.toml
	echo 'symbol = " "' | sudo tee -a ~/.config/starship.toml
	echo '' | sudo tee -a ~/.config/starship.toml
	echo '[scala]' | sudo tee -a ~/.config/starship.toml
	echo 'symbol = " "' | sudo tee -a ~/.config/starship.toml
