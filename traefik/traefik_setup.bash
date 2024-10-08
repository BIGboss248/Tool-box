#!/bin/bash
sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
sudo touch ./acme.json
sudo chmod 600 acme.json
sudo touch ./acme_cloudflare.json
sudo chmod 600 acme_cloudflare.json
