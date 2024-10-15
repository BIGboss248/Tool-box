#!/bin/bash
sudo apt update && sudo apt upgrade -y
sudo su
bash <(curl https://bash.ooo/nami.sh)
nami install brook
sudo apt install tmux
sudo tmux
BROOK_PORT=${1:9999}
sudo brook server --listen :"$BROOK_PORT" --password kevin
sudo brook wssserver --domainaddress "$BROOK_DOMAIN":443 --password "$BROOK_PASS"
