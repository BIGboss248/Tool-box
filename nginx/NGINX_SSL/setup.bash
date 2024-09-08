#!/bin/bash
# Change Domain.com to domain name
DOMAIN=example.com
sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
sudo docker compose run --rm  certbot certonly --webroot --webroot-path /var/www/certbot/ -d $DOMAIN
