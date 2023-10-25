#!/bin/sh

## Configure le proxy pour APT
cat > /etc/apt/apt.conf.d/01proxy << EOF
# Acquire::http::Proxy "http://192.168.1.81:9999";
EOF

## Configure la clé SSH
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAguQl+vaaMp1KNGPIjnf64D/hhfV2XbcvnpUghSjen0Xr63G05shYYasLngdXbI9Hxr9BE456Qw1+Y78VUks88ZWat+wENCVvZpLHwyjTFk7yupExYpctZBgoPZyaTiTIILjVLAhIDKk6/gAXviRF6UwRKtltZJE0k0fiFnLwSFPw7b0MpjZnS8sUKQR4ZvK87yJhx+p5LVQRwRwVILBRWVAkdHLqtxACzoykac1GbtUFgpqkMzhF6kUfb75ozYkHoLSH7CLs5ac13SYml3Hl5DoIKsBQfoDlOoI7V1WKgH8G4yd9lYobEbc2hGZDkdcqSA2jvSNeKHpo1fEKpja/Cw== TP03" >> ~/.ssh/authorized_keys
ln -s ~/.ssh/authorized_keys ~/.ssh/authorized_keys2
chmod -R 700 ~/.ssh
chmod 0600 ~/.ssh/authorized_keys*

## Configure les paquets de base
apt update && apt install -y git zsh vim yadm etckeeper && etckeeper commit -m "Installation de Debian"
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
ssh-keyscan -H bitbucket.org >> ~/.ssh/known_hosts
