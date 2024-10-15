#!/bin/bash

####### Setup zerotier #######

# "$NETWORK_ID" = zt network id
# Docker setup
docker run --name myzerotier --rm --cap-add NET_ADMIN --device /dev/net/tun zerotier/zerotier:latest "$NETWORK_ID"
# Linux setup
curl -s https://install.zerotier.com/ | sudo bash
zerotier-cli join "$NETWORK_ID"

####### ZT VPN exit node setup #######

# sudo nano /etc/sysctl.conf
# # uncomment net.ipv4.ip_forward = 1
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl -p
sudo sysctl net.ipv4.ip_forward
ip link show
export ZT_IFACE=  # Zerotier interface name
export PHY_IFACE= # Internet interface name
sudo iptables -t nat -I POSTROUTING -o "$PHY_IFACE" -j MASQUERADE
# sudo iptables -t nat -I POSTROUTING -o "$ZT_IFACE" -j MASQUERADE
sudo iptables -I FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I FORWARD -i "$PHY_IFACE" -o "$ZT_IFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
sudo iptables -I FORWARD -i "$ZT_IFACE" -o "$PHY_IFACE" -j ACCEPT
sudo apt install iptables-persistent
sudo bash -c iptables-save | sudo tee /etc/iptables/rules.v4 >/dev/null
sudo netfilter-persistent save
