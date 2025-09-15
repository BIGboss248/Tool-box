
# Traefik

## Legacy setup

After a few trys and fails I changed the file the legacy configs are commented and crossed out in docker-compose file (install better comments in vs code to see the comments crossed) and its files are moved to legacy folder.

## Configs for containers

Container configs are saved in my snippet section of my vscode profile

## TLS certificate

There are several ways to get an https certificate

### HTTP challnege

For this to work you need to create an entry point on port 80 and open it on firewall note if there is a closed connection error
this means port is closed in firewall.
The domain should point to the server without any proxy or cdn.

### DNS challenge

For wild card certificates this option is mandatory you need to create an API key in cloudflare and then assign it in enviroment variable
in docker.
The cloudflare API key should have following permissions.:
    1- Zone.Zone edit
    2- Zone.DNS read
IMPORTANT
For dns to work if you use tokens with limited permissions you need to create it and place it in CF_DNS_API_TOKEN and CF_ZONE_API_TOKEN enviroment variables.

## Command vs traefik.yml

Traefik static configs can be done via adding commands in traefik compose file or by adding a traefik.yml to the volumes and configuring traefik there commands are easier and they work!
