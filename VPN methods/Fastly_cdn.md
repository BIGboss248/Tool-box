# Fastly

https://www.youtube.com/watch?v=Fpn6ZIP-8UU



## Create steps

sign up for fastly trial with temp mail
temp-mail.org

cdn service > new cdn service > domain
enter a random domain
enter server ip in host and enter config port in host
go to vcs and enter this script

if (req.http.Upgrade) {
  return (upgrade);
}

Change config address to fatly.com port to 80 allow insecure and
change path to: ws/?ed=2048
camouflage domain: random domain u created in fastly

Another config is the same as above only you need to activate tls and place your domain in sni
and allow insecure and change the port to 443
