# Gcore

fjhsakldhflkwenauidnsalkfn.org

gcore > sign up > cdn service
enter a random domain and enter your server ip as host and continue
then create a vless with websocket enter the domain u set in host
in gcore edit origin pull protocol group and enter your config port number
then change the address to a gcore backed site or gcore dns
for example
ns2.gcdn.services
and change the port to 80

another config will be same as above but u change port to 443 enable tls and put gcore.com as sni

the config will come online when status of cdn in gocre turns to active and sometimes u need to w8 20 to 30 minutes

a smaple config is below
vless://c4099958-224b-4298-a37b-9372af44cbd9@ns2.gcdn.services:80?encryption=none&security=none&type=ws&host=fjhsakldhflkwenauidnsalkfn.org&path=%2F#Gcore-7ocf7vkb9
