#!/bin/bash
sudo su
Domain=example.com
Email=example@gmail.com
sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
sudo apt install curl socat -y
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --register-account -m $Email
~/.acme.sh/acme.sh --issue -d $Domain --standalone
~/.acme.sh/acme.sh --installcert -d $Domain --key-file /root/private.key --fullchain-file /root/cert.crt
