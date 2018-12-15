#/bin/bash

echo -e "IP et port du proxy (example : 172.16.0.1:3128) ?"
read -r IPPROXY
echo "Acquire::http::Proxy \"http://${IPPROXY}\";" > /etc/apt/apt.conf.d/01proxy
