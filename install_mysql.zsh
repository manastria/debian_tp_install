#!/usr/bin/zsh

#wget https://dev.mysql.com/get/mysql-apt-config_0.8.10-1_all.deb
apt install dirmngr
apt-key adv --keyserver pgp.mit.edu --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5
dpkg -i mysql-apt-config_0.8.10-1_all.deb
apt update
apt install -y mysql-server
