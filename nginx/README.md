
# Nginx

Config options and how to get ssl and host services and expose them with certificate are in vs code snippets
You can deploy nginx and get ssl certificates using Makefile

## Check if nginx is reciveing any request

To see if nginx is getting any request we can tail the access log which helps with trouble shooting

```shell
sudo tail -f /var/log/nginx/access.log

```

## Where to put config files?

Nginx main configuration is at /etc/nginx/nginx.conf while nginx after installation will put a default configuraion here you can add your sites config file at /etc/nginx/sites-awailble/ directory and nginx will read and apply it
