#!/bin/bash
# https://github.com/bepass-org/smartSNI
sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT
bash <(curl -fsSL https://raw.githubusercontent.com/bepass-org/smartSNI/main/install.sh)
