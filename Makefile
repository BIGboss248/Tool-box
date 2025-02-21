machine:= $(shell uname -m)
ifeq ($(machine),aarch64)
arch:=arm64
else
arch:=amd64
endif
kompose_download_link=https://github.com/kubernetes/kompose/releases/download/v1.35.0/kompose-linux-$(arch)

kubernetes: docker
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

kompose:
	curl -L "$(kompose_download_link)" -o kompose
	chmod +x kompose
	sudo mv ./kompose /usr/local/bin/kompose

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
	fi
minikube: kubernetes
	sudo usermod -aG docker $USER && newgrp docker
	curl -LO https://github.com/kubernetes/minikube/releases/latest/download/minikube-linux-$(arch)
	sudo install minikube-linux-$(arch) /usr/local/bin/minikube && rm minikube-linux-$(arch)
