#!/usr/bin/zsh

#wget https://dev.mysql.com/get/mysql-apt-config_0.8.10-1_all.deb
apt install dirmngr
apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5
dpkg -i mysql-apt-config_0.8.10-1_all.deb
apt update
apt install -y mysql-server


# Tester la version installé avec la commande
# apt-cache policy mysql-server
#mysql-server:
#  Installé : (aucun)
#  Candidat : 5.6.43-1debian9
# Table de version :
#     5.6.43-1debian9 500
#        500 http://repo.mysql.com/apt/debian stretch/mysql-5.6 amd64 Packages
#     5.5.9999+default 500
#        500 http://debian.mirrors.ovh.net/debian stretch/main amd64 Packages
#
#
# 500 http://repo.mysql.com/apt/debian stretch/mysql-5.6 amd64 Packages
#     release o=MySQL,n=stretch,l=MySQL,c=mysql-5.6,b=amd64
#     origin repo.mysql.com
# 500 http://repo.mysql.com/apt/debian stretch/mysql-apt-config amd64 Packages
#     release o=MySQL,n=stretch,l=MySQL,c=mysql-apt-config,b=amd64
#     origin repo.mysql.com
#
#
#  https://debian-facile.org/doc:systeme:apt:pinning
#  Dans conseils et remarques
#
## cat /etc/apt/preferences.d/mysql-pin-1000
#Package: *
#Pin: release l=mysql
#Pin-priority: 1000
#


# apt-key del A4A9406876FCBD3C456770C88C718D3B5072E1F5 # Delete the old key
# export GNUPGHOME=$(mktemp -d) # This just sets it up so the key isn't added to your actual user
# gpg --keyserver ha.pool.sks-keyservers.net --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5 # Download the new one
# gpg --export A4A9406876FCBD3C456770C88C718D3B5072E1F5 /etc/apt/trusted.gpg.d/mysql.gpg # Add it to the list of apt keys
# apt-key list # This should now show the updated key
