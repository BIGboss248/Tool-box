# Cloudflare origin rules

in cloudflare create a dns record with ur server ip
then rules > origin rules and set the rule to equla ur host name
and rewrite the port to a vless port you will configure
in vless enable external proxy and enter your host name and port 80
and change transport to ws
a sample configuration is below
vless://d87da9d5-9735-45d5-88ac-485d21707ba4@domain:80?type=tcp&security=none#pomaemc0x
