#!/bin/bash
git clone https://github.com/hiddify/hiddify-config
cd hiddify-config
touch hiddify-panel/hiddifypanel.db
docker compose up -d
