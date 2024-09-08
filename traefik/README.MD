
# Traefik

## TLS certificate

There are several ways to get an https certificate

### HTTP challnege

For this to work you need to create an entry point on port 80 and open it on firewall note if there is a closed connection error
this means port is closed in firewall.
The domain should point to the server without any proxy or cdn.

### DNS challenge

For wild card certificates this option is mandatory you need to create an API key in cloudflare and then assign it in enviroment variable
in docker.
The cloudflare API key should have 1- edit dns and 2- read zone permissions.
