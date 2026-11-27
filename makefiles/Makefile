SHELL = /bin/bash  # Force Make to use Bash
machine:= $(shell uname -m)
ifeq ($(machine),x86_64)
arch:=amd64
else ifeq ($(machine),aarch64)
arch:=arm64
else
$(error Unsupported architecture: $(machine). Supported: x86_64, aarch64)
endif
kompose_download_link=https://github.com/kubernetes/kompose/releases/download/v1.35.0/kompose-linux-$(arch)

# --- Security / hardening knobs ---
ADMIN_USER ?= $(shell id -un)
ADMIN_HOME := $(shell getent passwd $(ADMIN_USER) | cut -d: -f6)
SSH_PORT   ?= 22
SRC_ARG    := $(if $(SRC),-s $(SRC),)
CURL       := curl -fsSL --proto '=https' --proto-redir '=https' --tlsv1.2
ZT_SUBNET  ?= 10.147.17.0/24
KUBEADM_INIT_ARGS ?= --pod-network-cidr=10.244.0.0/16
NODE_EXPORTER_VERSION ?= 1.9.0

.PHONY: harden harden_updates harden_ssh harden_fail2ban harden_firewall harden_kernel \
        kubernetes kompose docker docker_repo docker_rootless docker_rootful fail2ban \
        minikube kubeadm open_ports vscode_extention zerotier zerotier_vpn webmin nginx \
        certbot certbot_cloudflare certbot_nginx node_exporter ssr starship fast_fetch \
        install_neovim install-zsh zshell-set-default install-ohmyzsh install-zshell-plugins \
        install-zshell-starship zshell-setup setup

# Apply hardening steps in order, even under `make -j`.
.NOTPARALLEL: harden

# ============================================================
# Security baseline — run this first on a fresh VPS.
# If SSH is not on port 22: make harden SSH_PORT=2222
# Keep your current SSH session open and verify a new login
# before closing it.
# ============================================================
harden: harden_updates harden_ssh harden_fail2ban harden_firewall harden_kernel
	@echo -e "\e[32mBaseline applied. Test a NEW SSH login before closing this session.\e[0m"

harden_updates:
	sudo apt-get update
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y unattended-upgrades apt-listchanges
	sudo dpkg-reconfigure -f noninteractive unattended-upgrades
	sudo systemctl enable --now unattended-upgrades

harden_ssh:
	@test "$(ADMIN_USER)" != "root" || { echo "Refusing: run as a non-root sudo user, or set ADMIN_USER=<user>"; exit 1; }
	@test -s "$(ADMIN_HOME)/.ssh/authorized_keys" || { echo "Refusing: no $(ADMIN_HOME)/.ssh/authorized_keys"; exit 1; }
	@grep -q '^Include /etc/ssh/sshd_config.d/' /etc/ssh/sshd_config || { echo "sshd_config does not include sshd_config.d; add it manually"; exit 1; }
	sudo install -d -m 0755 /etc/ssh/sshd_config.d
	printf '%s\n' \
	  'PermitRootLogin no' \
	  'PasswordAuthentication no' \
	  'KbdInteractiveAuthentication no' \
	  'PubkeyAuthentication yes' \
	  'PermitEmptyPasswords no' \
	  'X11Forwarding no' \
	  'AllowAgentForwarding no' \
	  'MaxAuthTries 3' \
	  'LoginGraceTime 20' \
	  'ClientAliveInterval 300' \
	  'ClientAliveCountMax 2' \
	  'Port $(SSH_PORT)' \
	  | sudo tee /etc/ssh/sshd_config.d/99-hardening.conf >/dev/null
	sudo sshd -t
	sudo systemctl reload ssh 2>/dev/null || sudo systemctl reload sshd
	sudo passwd -l root

harden_fail2ban:
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y fail2ban
	printf '%s\n' \
	  '[DEFAULT]' \
	  'bantime = 1h' \
	  'findtime = 10m' \
	  'maxretry = 5' \
	  'ignoreip = 127.0.0.1/8 ::1' \
	  '' \
	  '[sshd]' \
	  'enabled = true' \
	  'port = $(SSH_PORT)' \
	  'backend = systemd' \
	  'mode = aggressive' \
	  'maxretry = 3' \
	  '' \
	  '[recidive]' \
	  'enabled = true' \
	  'bantime = 1w' \
	  'findtime = 1d' \
	  'maxretry = 5' \
	  | sudo tee /etc/fail2ban/jail.d/sshd.local >/dev/null
	sudo systemctl enable --now fail2ban
	sudo systemctl is-active fail2ban
	sudo fail2ban-client status || true

# Standalone alias used by `setup`.
fail2ban: harden_fail2ban

harden_firewall:
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ufw
	sudo ufw default deny incoming
	sudo ufw default allow outgoing
	sudo ufw allow $(SSH_PORT)/tcp comment 'ssh'
	sudo ufw --force enable
	sudo ufw status verbose

harden_kernel:
	printf '%s\n' \
	  'kernel.kptr_restrict=2' \
	  'kernel.dmesg_restrict=1' \
	  'kernel.yama.ptrace_scope=1' \
	  'net.ipv4.conf.all.rp_filter=1' \
	  'net.ipv4.conf.all.accept_redirects=0' \
	  'net.ipv4.conf.all.send_redirects=0' \
	  'net.ipv4.conf.all.accept_source_route=0' \
	  'net.ipv4.tcp_syncookies=1' \
	  'net.ipv6.conf.all.accept_redirects=0' \
	  | sudo tee /etc/sysctl.d/99-hardening.conf >/dev/null
	sudo sysctl --system

ssr:
	@test -n "$(PORT)" || { echo "usage: make ssr PORT=8388 [SRC=203.0.113.10]"; exit 1; }
	@if command -v ufw >/dev/null 2>&1; then \
		if [ -n "$(SRC)" ]; then sudo ufw allow from $(SRC) to any port $(PORT) proto tcp; else sudo ufw allow $(PORT)/tcp; fi; \
	else \
		sudo iptables -A INPUT -p tcp $(SRC_ARG) --dport $(PORT) -j ACCEPT; \
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent; \
		sudo netfilter-persistent save; \
	fi
	@echo -e "\e[33mWARNING: ShadowsocksR is unmaintained. Prefer Xray/sing-box with TLS.\e[0m"
	$(CURL) -o /tmp/shadowsocksR.sh https://raw.githubusercontent.com/teddysun/shadowsocks_install/master/shadowsocksR.sh
	sudo apt-get install -y gcc
	sudo bash /tmp/shadowsocksR.sh 2>&1 | tee shadowsocksR.log

kubernetes: docker_rootful
	if command -v kubectl >/dev/null 2>&1; \
	then \
		echo -e "\e[32mKubernetes already installed\e[0m"; \
	else \
		sudo apt-get update; \
		sudo apt-get install -y apt-transport-https ca-certificates curl gnupg; \
		sudo install -d -m 0755 /etc/apt/keyrings; \
		$(CURL) https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null; \
		sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list; \
		sudo apt-get update; \
		sudo apt-get install -y kubectl; \
	fi

kompose:
	if command -v kompose >/dev/null 2>&1; \
	then \
		echo -e "\e[32mKompose already installed\e[0m"; \
	else \
		$(CURL) -o kompose "$(kompose_download_link)"; \
		chmod +x kompose; \
		sudo install -m 0755 ./kompose /usr/local/bin/kompose; \
		rm -f ./kompose; \
	fi

# Rootless Docker is the default: the daemon runs as your user, so the
# docker group (root-equivalent) is not needed.
docker: docker_rootless

# Shared Docker apt repository setup.
docker_repo:
	sudo apt-get update
	sudo apt-get install -y ca-certificates curl gnupg
	sudo install -m 0755 -d /etc/apt/keyrings
	$(CURL) https://download.docker.com/linux/$$(. /etc/os-release && echo $$ID)/gpg | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/docker.gpg
	sudo chmod a+r /etc/apt/keyrings/docker.gpg
	echo "deb [arch=$(arch) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$$(. /etc/os-release && echo $$ID) $$(. /etc/os-release && echo $$VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
	sudo apt-get update

# Rootless Docker. Notes:
#   - Ports below 1024 (80/443) cannot be bound by an unprivileged user.
#     Use a reverse proxy or set net.ipv4.ip_unprivileged_port_start=80.
#   - Ubuntu 24.04+ restricts unprivileged user namespaces via AppArmor.
#     If rootlesskit fails with "Operation not permitted", add an AppArmor
#     profile for rootlesskit or set kernel.apparmor_restrict_unprivileged_userns=0.
docker_rootless: docker_repo
	@echo -e "\e[32mConfiguring rootless Docker for $$USER...\e[0m"
	sudo apt-get install -y uidmap dbus-user-session slirp4netns fuse-overlayfs \
	  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
	  docker-ce-rootless-extras
	@if ! grep -q "^$$USER:" /etc/subuid; then \
		sudo usermod --add-subuids 100000-165535 "$$USER"; \
	fi
	@if ! grep -q "^$$USER:" /etc/subgid; then \
		sudo usermod --add-subgids 100000-165535 "$$USER"; \
	fi
	# Rootless mode does not need the rootful daemon or the docker group.
	sudo systemctl disable --now docker.service docker.socket containerd.service || true
	sudo gpasswd -d "$$USER" docker 2>/dev/null || true
	sudo loginctl enable-linger "$$USER"
	@if [ ! -f "$$HOME/.config/systemd/user/docker.service" ]; then \
		XDG_RUNTIME_DIR=/run/user/$$(id -u) dockerd-rootless-setuptool.sh install; \
	fi
	XDG_RUNTIME_DIR=/run/user/$$(id -u) systemctl --user enable --now docker || true
	@grep -q 'DOCKER_HOST=unix:///run/user/' $$HOME/.bashrc || echo 'export DOCKER_HOST=unix:///run/user/$$(id -u)/docker.sock' >> $$HOME/.bashrc
	@grep -q 'DOCKER_HOST=unix:///run/user/' $$HOME/.zshrc 2>/dev/null || echo 'export DOCKER_HOST=unix:///run/user/$$(id -u)/docker.sock' >> $$HOME/.zshrc
	@echo -e "\e[32mRootless Docker configured. Open a new shell and run: docker info\e[0m"

# Rootful Docker, needed only by the Kubernetes targets.
docker_rootful: docker_repo
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
	sudo systemctl enable --now docker.service containerd.service
	sudo groupadd docker || true
	sudo usermod -aG docker $$USER
	@echo -e "\e[33mNOTE: docker group membership is root-equivalent. Use 'make docker' for rootless mode.\e[0m"
	[ -d "$$HOME/.docker" ] && sudo chown -R "$$USER":"$$USER" "$$HOME/.docker" && chmod -R go-rwx "$$HOME/.docker" || true
	code --install-extension ms-azuretools.vscode-docker || true
	@echo -e "\e[32mRootful Docker configured for user $$USER. Relog or run 'newgrp docker' to apply.\e[0m"

minikube: kubernetes
	if command -v minikube >/dev/null 2>&1; \
	then \
		echo -e "\e[32mMinikube already installed\e[0m"; \
	else \
		$(CURL) -o minikube-linux-$(arch) https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-$(arch); \
		sudo install -m 0755 minikube-linux-$(arch) /usr/local/bin/minikube; \
		rm -f minikube-linux-$(arch); \
		sudo usermod -aG docker $$USER; \
	fi

kubeadm: kubernetes
	if command -v kubeadm >/dev/null 2>&1; \
	then \
		echo -e "\e[32mKubeadm is already installed\e[0m"; \
	else \
		sudo swapoff -a; \
		sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab; \
		sudo modprobe br_netfilter; \
		printf '%s\n' \
		  'net.bridge.bridge-nf-call-ip6tables = 1' \
		  'net.bridge.bridge-nf-call-iptables = 1' \
		  | sudo tee /etc/sysctl.d/k8s.conf >/dev/null; \
		sudo sysctl --system; \
		printf '%s\n' \
		  '{' \
		  '  "exec-opts": ["native.cgroupdriver=systemd"],' \
		  '  "log-driver": "json-file",' \
		  '  "log-opts": { "max-size": "100m" },' \
		  '  "storage-driver": "overlay2"' \
		  '}' \
		  | sudo tee /etc/docker/daemon.json >/dev/null; \
		sudo systemctl daemon-reload; \
		sudo systemctl enable docker; \
		sudo systemctl restart docker; \
		sudo systemctl --no-pager status docker; \
		sudo apt-get update; \
		sudo apt-get install -y apt-transport-https ca-certificates curl gpg; \
		sudo install -d -m 0755 /etc/apt/keyrings; \
		$(CURL) https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg; \
		echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null; \
		sudo apt-get update; \
		sudo apt-get install -y kubelet kubeadm; \
		sudo apt-mark hold kubelet kubeadm kubectl; \
		sudo systemctl daemon-reload; \
		sudo systemctl enable kubelet; \
		sudo systemctl restart kubelet; \
		sudo systemctl --no-pager status kubelet; \
		sudo mkdir -p /etc/containerd; \
		sudo containerd config default | sudo tee /etc/containerd/config.toml >/dev/null; \
		sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml; \
		sudo systemctl restart containerd; \
		sudo kubeadm init $(KUBEADM_INIT_ARGS); \
		mkdir -p "$$HOME/.kube"; \
		sudo cp -f /etc/kubernetes/admin.conf "$$HOME/.kube/config"; \
		sudo chown "$$(id -u):$$(id -g)" "$$HOME/.kube/config"; \
		chmod 600 "$$HOME/.kube/config"; \
	fi

open_ports:	# make open_ports PORT=80 [SRC=203.0.113.10]
	@test -n "$(PORT)" || { echo "usage: make open_ports PORT=8080 [SRC=203.0.113.10]"; exit 1; }
	@if command -v ufw >/dev/null 2>&1; then \
		if [ -n "$(SRC)" ]; then sudo ufw allow from $(SRC) to any port $(PORT) proto tcp; else sudo ufw allow $(PORT)/tcp; fi; \
		sudo ufw status numbered; \
	else \
		sudo iptables -A INPUT -p tcp $(SRC_ARG) --dport $(PORT) -j ACCEPT; \
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent; \
		sudo netfilter-persistent save; \
	fi

vscode_extention:
	code --install-extension ms-azuretools.vscode-containers
	code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
	code --install-extension ms-vscode.makefile-tools
	code --install-extension aaron-bond.better-comments
	code --install-extension mutantdino.resourcemonitor

zerotier:
	@test -n "$(ZEROTIER_NETWORK_ID)" || { echo "usage: make zerotier ZEROTIER_NETWORK_ID=<16-hex-id>"; exit 1; }
	$(CURL) -o /tmp/zerotier-install.sh https://install.zerotier.com/
	sudo bash /tmp/zerotier-install.sh
	sudo zerotier-cli join $(ZEROTIER_NETWORK_ID)

zerotier_vpn:
	@test -n "$(PHY_IFACE)" -a -n "$(ZT_IFACE)" || { echo "usage: make zerotier_vpn PHY_IFACE=eth0 ZT_IFACE=ztxxxx"; exit 1; }
	sudo sysctl -w net.ipv4.ip_forward=1
	printf '%s\n' 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-zerotier.conf >/dev/null
	sudo sysctl --system
	# Only NAT the ZeroTier subnet; never masquerade the whole interface.
	sudo iptables -t nat -A POSTROUTING -s $(ZT_SUBNET) -o "$(PHY_IFACE)" -j MASQUERADE
	sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
	sudo iptables -A FORWARD -i "$(ZT_IFACE)" -o "$(PHY_IFACE)" -s $(ZT_SUBNET) -j ACCEPT
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
	sudo netfilter-persistent save
	@echo -e "\e[33mIf ufw is active, add these rules to /etc/ufw/before.rules instead.\e[0m"

webmin:
	@echo -e "\e[33mInstalling Webmin bound to localhost. Use an SSH tunnel, not a public port.\e[0m"
	$(CURL) -o /tmp/webmin-setup-repo.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repo.sh
	sudo sh /tmp/webmin-setup-repo.sh
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends webmin
	sudo sed -i '/^listen=/d;/^ssl=/d' /etc/webmin/miniserv.conf
	printf '%s\n' 'listen=127.0.0.1' 'ssl=1' | sudo tee -a /etc/webmin/miniserv.conf >/dev/null
	sudo systemctl restart webmin
	@echo -e "\e[32mWebmin is on 127.0.0.1:10000. Tunnel: ssh -L 10000:127.0.0.1:10000 $(ADMIN_USER)@<host>\e[0m"

node_exporter:
	$(CURL) -o /tmp/node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v$(NODE_EXPORTER_VERSION)/node_exporter-$(NODE_EXPORTER_VERSION).linux-$(arch).tar.gz
	$(CURL) -o /tmp/node_exporter.sha256 https://github.com/prometheus/node_exporter/releases/download/v$(NODE_EXPORTER_VERSION)/sha256sums.txt
	cd /tmp && grep " node_exporter-$(NODE_EXPORTER_VERSION).linux-$(arch).tar.gz$$" node_exporter.sha256 | sha256sum -c -
	tar -xzf /tmp/node_exporter.tar.gz -C /tmp
	sudo install -m 0755 /tmp/node_exporter-$(NODE_EXPORTER_VERSION).linux-$(arch)/node_exporter /usr/local/bin/node_exporter
	sudo groupadd --system node_exporter 2>/dev/null || true
	sudo useradd --system --no-create-home --shell /usr/sbin/nologin --gid node_exporter node_exporter 2>/dev/null || true
	printf '%s\n' \
	  '[Unit]' \
	  'Description=Prometheus Node Exporter' \
	  'After=network-online.target' \
	  '' \
	  '[Service]' \
	  'User=node_exporter' \
	  'Group=node_exporter' \
	  'ExecStart=/usr/local/bin/node_exporter --web.listen-address=127.0.0.1:9100' \
	  'NoNewPrivileges=true' \
	  'ProtectSystem=strict' \
	  'ProtectHome=true' \
	  'PrivateTmp=true' \
	  '' \
	  '[Install]' \
	  'WantedBy=multi-user.target' \
	  | sudo tee /etc/systemd/system/node_exporter.service >/dev/null
	sudo systemctl daemon-reload
	sudo systemctl enable --now node_exporter
	sudo systemctl is-active node_exporter
	sudo systemctl is-enabled node_exporter
	rm -rf /tmp/node_exporter.tar.gz /tmp/node_exporter.sha256 /tmp/node_exporter-$(NODE_EXPORTER_VERSION).linux-$(arch)
	@echo -e "\e[32mNode Exporter is listening on 127.0.0.1:9100. Scrape it over ZeroTier or an SSH tunnel.\e[0m"

starship:
	$(CURL) -o /tmp/starship-install.sh https://starship.rs/install.sh
	sudo sh /tmp/starship-install.sh -y
	grep -q 'starship init bash' ~/.bashrc || echo 'eval "$$(starship init bash)"' >> ~/.bashrc
	$(CURL) -o /tmp/starship.toml https://raw.githubusercontent.com/BIGboss248/Tool-box/refs/heads/main/.vscode/starship.toml
	mkdir -p ~/.config
	mv /tmp/starship.toml ~/.config/starship.toml

fast_fetch:
	sudo add-apt-repository -y ppa:zhangsongcui3371/fastfetch
	sudo apt-get update
	sudo apt-get install -y fastfetch

install_neovim:
	sudo apt-get install -y neovim

install-zsh:
	@echo "🔹 Installing Zsh..."
	@if command -v apt >/dev/null; then \
		sudo apt update && sudo apt install -y zsh git curl; \
	elif command -v dnf >/dev/null; then \
		sudo dnf install -y zsh git curl; \
	elif command -v pacman >/dev/null; then \
		sudo pacman -Sy --noconfirm zsh git curl; \
	else \
		echo "❌ Unsupported package manager. Install zsh manually."; \
		exit 1; \
	fi

zshell-set-default:
	@echo "🔹 Setting Zsh as default shell..."
	sudo chsh -s "$$(command -v zsh)" "$$USER" || true

install-ohmyzsh:
	@echo "🔹 Installing Oh My Zsh..."
	@if [ ! -d "$$HOME/.oh-my-zsh" ]; then \
		$(CURL) -o /tmp/ohmyzsh-install.sh https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh; \
		sh /tmp/ohmyzsh-install.sh --unattended || true; \
	else \
		echo "✅ Oh My Zsh already installed."; \
	fi

install-zshell-plugins:
	@echo "🔹 Installing plugins..."
	@ZSH_CUSTOM=$${ZSH_CUSTOM:-$$HOME/.oh-my-zsh/custom}; \
	if [ ! -d "$$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then \
		git clone https://github.com/zsh-users/zsh-autosuggestions $$ZSH_CUSTOM/plugins/zsh-autosuggestions; \
	fi; \
	if [ ! -d "$$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then \
		git clone https://github.com/zsh-users/zsh-syntax-highlighting $$ZSH_CUSTOM/plugins/zsh-syntax-highlighting; \
	fi; \
	if ! grep -q "zsh-autosuggestions" $$HOME/.zshrc; then \
		sed -i 's/^plugins=(\(.*\))/plugins=(\1 zsh-autosuggestions zsh-syntax-highlighting)/' $$HOME/.zshrc; \
	fi
install-zshell-starship:
	@echo "🔹 Installing Starship prompt..."
	@grep -q 'starship init zsh' $$HOME/.zshrc || echo 'eval "$$(starship init zsh)"' >> $$HOME/.zshrc

zshell-setup: install-zsh zshell-set-default install-ohmyzsh install-zshell-plugins install-zshell-starship

# Webmin is intentionally opt-in: `make webmin` (bound to 127.0.0.1).
setup: vscode_extention starship fast_fetch install_neovim zshell-setup fail2ban
