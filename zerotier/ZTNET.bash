#!/bin/bash
sudo apt update &&sudo apt install -y sudo curl lsb-release
sudo curl -s http://install.ztnet.network | sudo bash
sudo systemctl enable ztnet
