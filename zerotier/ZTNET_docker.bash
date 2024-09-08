#!/bin/bash
# Documentaion:https://ztnet.network/installation/docker-compose
sudo wget -O docker-compose.yml https://raw.githubusercontent.com/sinamics/ztnet/main/docker-compose.yml
sudo sed -i "s|http://localhost:3000|http://$(hostname -I | cut -d' ' -f1):3000|" docker-compose.yml
sudo docker compose up -d
