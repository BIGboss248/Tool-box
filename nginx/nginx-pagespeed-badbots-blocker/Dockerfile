FROM pagespeed/nginx-pagespeed
# use image below instead if you need power of Lua in your Nginx
# FROM romanmelnyk/ngxpagespeed-lua

RUN addgroup -S nonroot \
    && adduser -S nonroot -G nonroot

USER nonroot

# Install curl
RUN apk add --no-cache curl

# Make sure folder exists
RUN mkdir /usr/local/sbin

# Step 1
RUN wget --max-redirect=0 https://raw.githubusercontent.com/mitchellkrogza/nginx-ultimate-bad-bot-blocker/master/install-ngxblocker -O /usr/local/sbin/install-ngxblocker
RUN chmod +x /usr/local/sbin/install-ngxblocker

# Step 2 - Skipped since it's a DRY run

# Step 3
RUN /usr/local/sbin/install-ngxblocker -x
RUN chmod +x /usr/local/sbin/setup-ngxblocker
RUN chmod +x /usr/local/sbin/update-ngxblocker

# Step 4 - Skipped since it's a DRY run

COPY bots_conf/whitelist-ips.conf /etc/nginx/bots.d/whitelist-ips.conf
COPY bots_conf/whitelist-domains.conf /etc/nginx/bots.d/whitelist-domains.conf
COPY bots_conf/blacklist-user-agents.conf /etc/nginx/bots.d/blacklist-user-agents.conf
COPY bots_conf/blacklist-ips.conf /etc/nginx/bots.d/blacklist-ips.conf
COPY bots_conf/bad-referrer-words.conf /etc/nginx/bots.d/bad-referrer-words.conf
COPY bots_conf/custom-bad-referrers.conf /etc/nginx/bots.d/custom-bad-referrers.conf

# Step 5
RUN /usr/local/sbin/setup-ngxblocker -x -e conf
