# DNStt

DNS tunnel with DoH/DoT support.

You can get help from:

- [Youtube video deployment](https://www.youtube.com/watch?v=DI06-40qJms)
- [Official project site](https://www.bamsoftware.com/software/dnstt)
- [Use helper script](https://github.com/bugfloyd/dnstt-deploy/tree/main)

## What you need before setting up

You need a server and a domain name assuming:

- Your domain name: example.com
- Your server's IPv4 address: 203.0.113.2
- Your server's IPv6 address: 2001:db8::2 (optional)

You need to follow these steps:

## Setup

### DNS records

DNS Records Setup
Go into your name registrar's configuration panel and add these records and turn the proxy off:

| Type | Name             | Points to         |
|------|------------------|-------------------|
| A    | tns.example.com  | 203.0.113.2       |
| AAAA | tns.example.com  | 2001:db8::2       |
| NS   | t.example.com    | tns.example.com   |

**Important**: Wait for DNS propagation (can take up to 24 hours) before testing your tunnel. Check if DNS is deployed using [dnschecker.org](https://dnschecker.org/)

### Installtion script

```console
bash <(curl -Ls https://raw.githubusercontent.com/bugfloyd/dnstt-deploy/main/dnstt-deploy.sh)
```

### Deploy

On install use the command below to deploy server

```Shell
dnstt-deploy
```

on deployment it will prompt for nameserver domain which in our example is t.example.com

When the deployment is compelete save the public key you'll need to connect to the server

### Client software

Download and install client software go to https://dnstt.network/ to download the CLI based client software then save the public key in a file in the same directory as the client tool and run this command assumin you saved public key in pub.key file

```shell
./dnsttcli.exe --udp 8.8.8.8:53 -pubkey-file pub.key t.example.com 127.0.0.1:1080
```

make sure the message ***begin session xxxxxxx*** is displayed
now the software will expose a socks proxy on port 1080 serving requests through the tunnel
