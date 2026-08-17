# Tool-box 🧰

[![Quality gate](https://sonarcloud.io/api/project_badges/quality_gate?project=BIGboss248_Tool-box)](https://sonarcloud.io/summary/new_code?id=BIGboss248_Tool-box) [![MegaLinter](https://github.com/BIGboss248/Tool-box/workflows/MegaLinter/badge.svg?branch=main)](https://github.com/BIGboss248/Tool-box/actions?query=workflow%3AMegaLinter+branch%3Amain)

A curated collection of production-ready **Docker Compose stacks**, deployment scripts, and DevOps configurations for self-hosting, networking, observability, security, CI/CD, and productivity tools.

---

## 📑 Table of Contents

- [🌐 Networking, Proxies & VPNs](#-networking-proxies--vpns)
- [🛡️ Security, DNS & Identity](#️-security-dns--identity)
- [📊 Monitoring, Metrics & Observability](#-monitoring-metrics--observability)
- [🚀 Reverse Proxies & Ingress](#-reverse-proxies--ingress)
- [⚡ CI/CD, DevOps & System Utilities](#-cicd-devops--system-utilities)
- [💼 Business, Automation & CMS](#-business-automation--cms)
- [📦 Storage, Media & Productivity Hubs](#-storage-media--productivity-hubs)
- [🗄️ Databases & Database Management](#️-databases--database-management)
- [🛠️ Getting Started](#️-getting-started)

---

## 🌐 Networking, Proxies & VPNs

Anti-censorship protocols, proxy managers, mesh VPNs, and secure tunneling solutions.

| Stack / Tool | Primary Services & Images | Description |
| :--- | :--- | :--- |
| [Brook](./Brook/) | `teddysun/brook` | Lightweight cross-platform programmable proxy server designed for speed and bypassing network filtering. |
| [Cloudflare Tunnel](./Cloudflare_tunnel/) | `cloudflare/cloudflared` | Secure daemon to expose local web services directly to the Cloudflare network without opening public inbound ports. |
| [dnstt](./dnstt/) | *Documentation & Setup* | DNS Tunneling documentation and guide to establish encrypted proxy tunnels over DNS (DoH/DoT). |
| [Hiddify](./Hiddify/) | *Installation Script* | Multi-protocol anti-censorship proxy manager supporting Sing-box, Xray, Reality, VLESS, VMess, and automatic client config generation. |
| [Marzneshin](./marzneshin/) | `dawsh/marzneshin`, `dawsh/marznode` | Modern web-based proxy management panel and node agent for Xray-core with multi-node orchestration and user traffic management. |
| [MikroTik](./mikrotik/) | *RouterOS Bash Script* | Automated script for deploying MikroTik Cloud Hosted Router (CHR) instances on Linux VPS environments. |
| [Nova](./nova/) | `ghcr.io/irnova/nova-server` | High-performance proxy node server application for routing and traffic forwarding. |
| [Oblivion](./Oblivion/) | `ghcr.io/bepass-org/warp-plus` | Cloudflare WARP client / proxy gateway unlocking bypass routes via WARP+ over WireGuard/gRPC. |
| [Outline](./Outline/) | *Outline Server Script* | Self-hosted Shadowsocks VPN server managed via the official Outline Manager graphical interface. |
| [Pangolin](./pangolin/) | *Documentation & Config* | Self-hosted zero-trust reverse proxy and tunnel manager inspired by Cloudflare Tunnels and Authelia. |
| [S-UI](./s-ui/) | `alireza7/s-ui` | Web-based management dashboard for Sing-box proxy core with subscription links and user administration. |
| [Shadowsocks-R](./shadowsocks-r/) | `teddysun/shadowsocks-r` | ShadowsocksR (SSR) proxy server container for encrypted network traffic forwarding. |
| [Telegram Proxy](./Telegram_proxy/) | *Docker Setup Script* | Official Telegram MTProto proxy server deployment to bypass Telegram censorship. |
| [Tor](./Tor/) | `dperson/torproxy` | Tor anonymity network client providing SOCKS5 and HTTP proxy endpoints. |
| [VPN Methods](./VPN%20methods/) | *Documentation Guides* | Comprehensive guides on CDN fronting (Fastly, Gcore), Cloudflare Origin Rules, and Free VPS proxy setups. |
| [X-UI](./x-ui/) | `alireza7/x-ui` | Popular web UI panel for managing Xray/V2Ray protocols, client accounts, traffic statistics, and TLS certificates. |
| [Xray Core](./Xray_core/) | `ghcr.io/xtls/xray-core` | Bare Xray-core proxy service supporting VLESS, VMess, Trojan, Shadowsocks, and XTLS/Reality. |
| [ZeroTier](./zerotier/) | *ZTNET Scripts & Setup* | ZeroTier One mesh VPN client and self-hosted ZTNET controller for peer-to-peer virtual private networks. |

---

## 🛡️ Security, DNS & Identity

Authentication providers, DNS sinkholes, intrusion prevention, and vulnerability scanners.

| Stack / Tool | Primary Services & Images | Description |
| :--- | :--- | :--- |
| [AdGuard Home](./adguard/) | `adguard/adguardhome` | Network-wide DNS server and ad/tracker blocker with parental controls, encrypted DNS (DoH/DoT), and SNI proxy scripts. |
| [Authentik](./authentic/) | `ghcr.io/goauthentik/server`, `postgres:16-alpine`, `redis:alpine` | Open-source Identity Provider (IdP) providing SSO, OAuth2/OIDC, SAML, LDAP, and MFA user directory management. |
| [Certbot & SSL](./certbot%20and%20ssl/) | *ACME & Certbot Scripts* | Automated SSL/TLS certificate issuance and renewal scripts using Let's Encrypt with Cloudflare DNS challenge support. |
| [Checkmate](./checkmate/) | `bluewave-labs/checkmate-backend-mono-multiarch`, `mongo:6.0` | Microservice API testing, synthetic endpoint monitoring, and automated security audit framework. |
| [CrowdSec](./crowdsec/) | `crowdsecurity/crowdsec`, `traefik` | Collaborative open-source intrusion prevention system (IPS/WAF) analyzing logs and blocking malicious IPs. |
| [Pi-hole](./Pihole/) | `pihole/pihole` | Network-wide DNS sinkhole that blocks advertisements and tracking domains across your entire LAN. |
| [Wazuh](./wazuh/) | `wazuh/wazuh-manager`, `wazuh/wazuh-indexer`, `wazuh/wazuh-dashboard` | Enterprise-grade open-source SIEM and XDR platform for threat detection, integrity monitoring, incident response, and compliance. |
| [Web-Check](./web_check/) | `lissy93/web-check` | Comprehensive OSINT and website security reconnaissance dashboard for analyzing domains, DNS, headers, and certificates. |

---

## 📊 Monitoring, Metrics & Observability

Dashboards, telemetry collection, server metrics, and uptime monitoring.

| Stack / Tool | Primary Services & Images | Description |
| :--- | :--- | :--- |
| [cAdvisor](./cadvisor/) | `gcr.io/cadvisor/cadvisor` | Container resource usage and performance analysis tool (CPU, memory, filesystem, network) by Google. |
| [Deunhealth](./deunhealth/) | `qmcgaw/deunhealth` | Lightweight Docker daemon utility that monitors containers and automatically restarts any that become unhealthy. |
| [Grafana](./grafana/) | `grafana/grafana-oss` | Multi-source visualization and metrics dashboard for Prometheus, Zabbix, PostgreSQL, and log streams. |
| [Orb](./orb/) | `orbforge/orb` | Dynamic edge observability platform and fleet telemetry agent for network traffic inspection. |
| [pmacct](./pmacct/) | `pmacct/nfacctd`, `postgres`, `grafana/grafana` | Network traffic accounting pipeline collecting NetFlow/IPFIX/sFlow metrics with PostgreSQL storage and Grafana visualization. |
| [Prometheus](./Prometheus/) | `prom/prometheus` | Time-series database and monitoring platform with multidimensional data models and PromQL querying. |
| [Upptime Bot](./Upptime%20bot/) | *GitHub Actions & Config* | Open-source uptime monitor and status page powered entirely by GitHub Actions, Issues, and Pages. |
| [Uptime Kuma](./uptime%20kuma/) | `louislam/uptime-kuma` | Self-hosted monitoring tool tracking HTTP(s), TCP, Ping, DNS, and Docker containers with alerts and status pages. |
| [Zabbix](./zabbix/) | `zabbix/zabbix-server-pgsql`, `zabbix/zabbix-web-nginx-pgsql`, `zabbix/zabbix-snmptraps`, `postgres:17` | Enterprise-class network, server, and VM infrastructure monitoring suite with SNMP traps, triggers, and alerts. |

---

## 🚀 Reverse Proxies & Ingress

Edge routers, reverse proxies, and web-based Nginx configuration managers.

| Stack / Tool | Primary Services & Images | Description |
| :--- | :--- | :--- |
| [Nginx](./nginx/) | `nginx:latest`, `certbot/certbot` | High-performance Nginx web server and reverse proxy setup with automated Certbot SSL certificate issuance and SNI proxying. |
| [Nginx Proxy Manager](./nginx%20proxy%20manager/) | `jc21/nginx-proxy-manager` | Web management interface for Nginx reverse proxies, SSL certificates (Let's Encrypt), redirections, and access lists. |
| [Nginx UI](./nginx-ui/) | `uozi/nginx-ui` | Modern web GUI dashboard for managing Nginx configurations, editing virtual hosts, viewing access logs, and monitoring server metrics. |
| [Traefik](./traefik/) | `traefik` | Cloud-native edge router and reverse proxy with automated Docker service discovery and dynamic Let's Encrypt TLS termination. |

---

## ⚡ CI/CD, DevOps & System Utilities

Container registries, automation orchestration, network booting, and code scanners.

| Stack / Tool | Primary Services & Images | Description |
| :--- | :--- | :--- |
| [Ansible Semaphore](./Ansible%20semaphore/) | `semaphoreui/semaphore`, `mysql:8.0` | Modern, responsive web UI for Ansible playbooks, inventory management, user permissions, and scheduled runs. |
| [Docker Registry](./docker_registery/) | `registry:2` | Private, stateless Docker container image registry for storing and distributing custom Docker images. |
| [iVentoy](./iventoy/) | `iventoy` (Custom Build) | Enhanced network boot / PXE server enabling clients to boot Linux/Windows ISO images directly over LAN without extracting them. |
| [Jenkins](./jenkins/) | `jenkins/jenkins` | Industry-standard open-source CI/CD automation server for building, testing, and deploying software pipelines. |
| [Makefiles](./makefiles/) | *DevOps Automation Makefile* | Centralized Makefile for bootstrapping Docker, Kubernetes (kubectl, kubeadm, minikube), Kompose, Zsh, Starship, and system tools. |
| [netboot.xyz](./netboot_xyz/) | `linuxserver/netbootxyz` | Comprehensive iPXE network boot server providing unified deployment of numerous operating systems and utility ISOs. |
| [Portainer](./portainer/) | `portainer/portainer-ce` | Web-based container management UI for managing Docker standalone environments, Swarm clusters, and container stacks. |
| [SonarQube](./SonarQube/) | `sonarqube:10.6-community` | Continuous static code analysis and security inspection platform covering security vulnerabilities, bugs, and code smells. |
| [Watchtower](./Watchtower/) | `nickfedor/watchtower` | Automated container updater that checks for new base image versions and gracefully restarts running containers. |

---

## 💼 Business, Automation & CMS

Enterprise Resource Planning, CRM, low-code workflow automations, and content platforms.

| Stack / Tool | Primary Services & Images | Description |
| :--- | :--- | :--- |
| [Activepieces](./activepieces/) | `activepieces/activepieces` | Open-source no-code workflow automation tool (Zapier alternative) for connecting web apps, APIs, and business processes. |
| [ERPNext](./ERP_next/) | `frappe/erpnext`, `mariadb:10.6`, `redis:6.2-alpine` | Complete open-source ERP system covering accounting, inventory, manufacturing, CRM, HRMS, and project management. |
| [n8n](./n8n/) | `docker.n8n.io/n8nio/n8n` | Extendable node-based workflow automation tool integrating hundreds of services, AI nodes, and custom API webhooks. |
| [Odoo](./odoo/) | `odoo:17.0`, `postgres:15` | Modular open-source business management suite including CRM, Sales, Accounting, Point of Sale, and eCommerce. |
| [Strapi](./strapi/) | `strapi:latest`, `postgres:16.0-alpine` | Leading open-source headless CMS and REST/GraphQL API builder for Node.js. |
| [WordPress](./WordPress/) | `wordpress`, `mysql:8.0`, `redis` | Full-featured WordPress CMS platform with MySQL 8.0 database backend and Redis object caching. |

---

## 📦 Storage, Media & Productivity Hubs

Self-hosted cloud storage, document management, smart home hubs, and media streaming.

| Stack / Tool | Primary Services & Images | Description |
| :--- | :--- | :--- |
| [Dashy](./dashy/) | `lissy93/dashy` | Feature-rich, highly customizable dashboard and application homepage with status checks, widgets, and themes. |
| [Heimdall](./heimdal_dashboard/) | `lscr.io/linuxserver/heimdall` | Elegant application dashboard and launcher for organizing server links and home lab services. |
| [Home Assistant](./home_assistant/) | `ghcr.io/home-assistant/home-assistant:stable` | Open-source smart home automation hub integrating thousands of IoT devices, sensors, and home automation routines. |
| [Jellyfin](./jellyfin/) | `jellyfin/jellyfin` | Free software media system for streaming and organizing movies, TV shows, music, and live TV (Plex alternative). |
| [Nextcloud](./next_cloud/) | `nextcloud`, `mariadb:10.6`, `nextcloud/all-in-one` | Self-hosted cloud collaboration suite with file storage, calendar, contacts, Office integration, and Nextcloud AIO installer. |
| [Paperless-ngx](./paperless-ngx/) | `ghcr.io/paperless-ngx/paperless-ngx`, `redis`, `postgres:17`, `gotenberg`, `tika` | Document management system (DMS) that indexes, OCRs, tags, and archives physical and digital documents with searchable PDF storage. |
| [WebDAV](./Webdav/) | `derkades/webdav` | Lightweight WebDAV file server for cross-platform network file sharing and synchronization. |

---

## 🗄️ Databases & Database Management

Database engines and database administration web interfaces.

| Stack / Tool | Primary Services & Images | Description |
| :--- | :--- | :--- |
| [MongoDB](./mongo/) | `mongo` | High-performance NoSQL document-oriented database with environment variable configuration. |
| [pgAdmin 4](./pgadmin/) | `dpage/pgadmin4`, `postgres` | Web-based management and administration platform for PostgreSQL database servers. |

---

## 🛠️ Getting Started

### Prerequisites

Ensure you have Docker and Docker Compose installed. You can quickly bootstrap a Docker environment on Debian/Ubuntu using the Makefile in `makefiles/`:

```bash
cd makefiles
make docker
```

### Running a Stack

Navigate to the desired stack directory, configure the `.env` file (if provided), and launch the container stack:

```bash
cd <stack-directory>

# Copy and update the environment template (if available)
cp .env.example .env  # or edit .env directly

# Start the stack in the background
docker compose up -d

# View real-time logs
docker compose logs -f

# Stop the stack
docker compose down
```
