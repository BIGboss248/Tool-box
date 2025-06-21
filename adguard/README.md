# Adguard dns over HTTPS and SNI proxy

This project will deploy an adguard DNS over HTTPS server with certificates you get using certbot

## Overide DNS requests

Remember you can override dns requests by

1. Cloudflare gateway: which supports filtering requests by application for example override all dns for Telegram to 10.0.0.1
2. Adguard DNS rewrite: You can rewrite dns requests using domain or regex in adguard

## Deploy with NGINX

You can deploy adguard and adguard DOH with nginx after you deployed adguard and setup adguard on port 3000 go to confdir/AdGuardHome.yaml in tls settings set:

```python
tls:
  enabled: true
  port_https: 0
  allow_unencrypted_doh: true
```

leave the rest as is now you can resolve dns requests on http port so we can point nginx to adguard http port and resolve dns requests with https provided by nginx
