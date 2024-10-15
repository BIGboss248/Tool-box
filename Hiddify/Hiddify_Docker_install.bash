#!/bin/bash
git clone https://github.com/hiddify/hiddify-config
cd hiddify-config || exit
touch hiddify-panel/hiddifypanel.db
docker compose up -d
