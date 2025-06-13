


include ../Makefile

install_script:
	echo "What you'll need:"
	echo "TCP ports 80, 443, and UDP port 51820 exposed to your Linux instance."
	echo "A domain name pointed to your server's IP address"
	echo "Press enter when your done."
	read
	echo "Opening ports"
	sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
	sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
	sudo iptables -A INPUT -p udp --dport 51820 -j ACCEPT
	sudo iptables-save | sudo tee /etc/iptables/rules.v4
	echo "Installing pangolin"
	wget -O installer "https://github.com/fosrl/pangolin/releases/download/1.5.1/installer_linux_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')" && chmod +x ./installer
	sudo ./installer
