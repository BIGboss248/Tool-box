#!/bin/bash
sudo apt update
sudo apt install snapd
sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
sudo apt install iptables-persistent
sudo bash -c iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
sudo netfilter-persistent save
sudo snap install --classic certbot
sudo ln -s /snap/bin/certbot /usr/bin/certbot
sudo certbot certonly --standalone --config-dir ./ssl
