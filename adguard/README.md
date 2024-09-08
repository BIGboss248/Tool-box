# Adguard dns over HTTPS and SNI proxy

This project will deploy an adguard DNS over HTTPS server with certificates you get using certbot

Remember you can override dns requests by

1. Cloudflare gateway: which supports filtering requests by application for example override all dns for Telegram to 10.0.0.1
2. Adguard DNS rewrite: You can rewrite dns requests using domain or regex in adguard
