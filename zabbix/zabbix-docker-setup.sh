#!/bin/sh
#   SERVER MUST BE UBUNTU 20.04
#
#
#
sudo apt update
sudo git clone https://github.com/zabbix/zabbix-docker.git
cd zabbix-docker || exit
git checkout 6.4
docker compose -f ./docker-compose_v3_ubuntu_pgsql_latest.yaml up -d
# Use: Admin Pass: zabbix
