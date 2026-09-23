https://github.com/IzumiRain/HyperDNS/blob/main/docs/TUTORIAL.md

Port Protocol Purpose
53 UDP + TCP Plain DNS (what consoles and routers set)
80 TCP SNI proxy HTTP + the ACME challenge listener
443 TCP SNI proxy HTTPS (the actual game traffic)
853 TCP DNS-over-TLS (Android "Private DNS", iOS)
8443 TCP DNS-over-HTTPS
8080 TCP The admin dashboard
