SHELL = /bin/bash  # Force Make to use Bash
machine:= $(shell uname -m)
ifeq ($(machine),aarch64)
arch:=arm64
else
arch:=amd64
endif
kompose_download_link=https://github.com/kubernetes/kompose/releases/download/v1.35.0/kompose-linux-$(arch)

kubernetes: docker
	if kubectl version
	then
	echo "Kubernetes is already installed"
	else
	sudo apt-get update
	# apt-transport-https may be a dummy package; if so, you can skip that package
	sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
	# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
	# sudo mkdir -p -m 755 /etc/apt/keyrings
	curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
	sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring
	# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
	echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
	sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly
	sudo apt-get update
	sudo apt-get install -y kubectl
	fi

kompose:
	if kompose version
	then
	echo "Kompose is already installed"
	else
	curl -L "$(kompose_download_link)" -o kompose
	chmod +x kompose
	sudo mv ./kompose /usr/local/bin/kompose
	fi

docker:
	@if command -v docker >/dev/null 2>&1; then \
		echo "Docker is already installed"; \
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
		sudo groupadd docker || true
		sudo usermod -aG docker $$USER
		newgrp docker
		sudo chown "$USER":"$USER" /home/"$USER"/.docker -R || true
		sudo chmod g+rwx "$HOME/.docker" -R || true
		sudo systemctl enable docker.service
		sudo systemctl enable containerd.service
		code --install-extension ms-azuretools.vscode-docker
		echo -e "\e[32mReboot if needed\e[0m"
	fi

minikube: kubernetes
	if minikube version
	then
	echo "Minikube is already installed"
	else
	curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-$(arch)
	sudo install minikube-linux-$(arch) /usr/local/bin/minikube && rm minikube-linux-$(arch)
	sudo usermod -aG docker $$USER && newgrp docker
	fi

kubeadm: kubernetes
	if kubeadm version
	then
	echo "Kubeadm is already installed"
	else
	sudo swapoff -a
	sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
	sudo lsmod | grep br_netfilter
	sudo sudo modprobe br_netfilter
	sudo cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
	net.bridge.bridge-nf-call-ip6tables = 1
	net.bridge.bridge-nf-call-iptables = 1
	EOF
	sudo sysctl --system
	cat <<EOF | sudo tee /etc/docker/daemon.json
	{
	"exec-opts": ["native.cgroupdriver=systemd"],
	"log-driver": "json-file",
	"log-opts": {
		"max-size": "100m"
	},
	"storage-driver": "overlay2"
	}
	EOF
	sudo systemctl daemon-reload
	sudo systemctl enable docker
	sudo systemctl restart docker
	sudo systemctl status docker
	sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl gpg
	sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
	echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
	sudo apt-get update
	sudo apt-get install -y kubelet kubeadm
	sudo apt-mark hold kubelet kubeadm
	sudo systemctl daemon-reload
	sudo systemctl enable kubelet
	sudo systemctl restart kubelet
	sudo systemctl status kubelet
	sudo rm /etc/containerd/config.toml
	sudo systemctl restart containerd
	sudo kubeadm init
	mkdir -p HOME/.kube
	sudo cp -i /etc/kubernetes/admin.conf HOME/.kube/config
	sudo chown $(id -u):$(id -g) HOME/.kube/config
	fi

open_ports:	# make open_ports port=80
	sudo iptables -I INPUT -p tcp -j ACCEPT --dport $(port)

vscode_extention:
	code --install-extension ms-azuretools.vscode-docker
	code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
	code --install-extension ms-vscode.makefile-tools
	code --install-extension aaron-bond.better-comments
	code --install-extension mutantdino.resourcemonitor

zerotier:
	curl -s https://install.zerotier.com/ | sudo bash
	sudo zerotier-cli join $(zerotier_network_id)

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
