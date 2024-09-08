#!/bin/bash
sudo docker run -d -p443:443 --name=mtproto-proxy --restart=always -v proxy-config:/data telegrammessenger/proxy:latest
sudo docker logs mtproto-proxy
