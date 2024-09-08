#!/bin/sh
# Update and install docker
sudo apt update && sudo bash ./../docker/docker_setup_v2.bash
# Pull docker images
sudo docker network create my_network
sudo docker compose -f ./Pihole_compose.yml pull
# Reset dns resolver for pihole
sudo sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
sudo sh -c 'rm /etc/resolv.conf && ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf'
# Change pihole pass docker exec -it pihole pihole -a -p
sudo systemctl stop systemd-resolved
# Remember to change nginx server name to domain
sudo docker compose -f ./Pihole_compose.yml up -d
sudo systemctl restart systemd-resolved
