#!/bin/sh
#   SERVER MUST BE UBUNTU 20.04
#
#
#
sudo apt update
sudo git clone https://github.com/zabbix/zabbix-docker.git
cd zabbix-docker || exit
sudo docker compose -f ./docker-compose_v3_alpine_pgsql_latest.yaml up -d
# Attach contaienr to desired network
sudo docker network connect my_network zabbix-web-nginx-pgsql
# The host name is zabbix-web-nginx-pgsql
# Use: Admin Pass: zabbix
