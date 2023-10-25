#!/usr/bin/zsh

#wget http://prdownloads.sourceforge.net/webadmin/webmin_1.900_all.deb
apt install -y perl libnet-ssleay-perl openssl libauthen-pam-perl libpam-runtime libio-pty-perl apt-show-versions python
dpkg --install webmin_1.920_all.deb
