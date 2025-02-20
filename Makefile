machine:= $(shell uname -m)
ifeq ($(machine),aarch64)
arch:=arm64
else
arch:=amd64
endif
kompose_download_link=https://github.com/kubernetes/kompose/releases/download/v1.35.0/kompose-linux-$(arch)

kubernetes:

kompose:
	curl -L "$(kompose_download_link)" -o kompose
	chmod +x kompose
	sudo mv ./kompose /usr/local/bin/kompose

test:
	echo $(arch)
	echo $(download_link)
