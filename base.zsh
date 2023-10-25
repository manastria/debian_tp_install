#!/usr/bin/zsh

cat > /etc/apt/sources.list <<EOF
#deb cdrom:[Debian GNU/Linux 9.5.0 _Stretch_ - Official amd64 NETINST 20180714-10:25]/ stretch main

deb http://debian.mirrors.ovh.net/debian/ stretch main contrib non-free
deb-src http://debian.mirrors.ovh.net/debian/ stretch main contrib non-free

deb http://security.debian.org/debian-security stretch/updates main contrib non-free
deb-src http://security.debian.org/debian-security stretch/updates main contrib non-free

# stretch-updates, previously known as 'volatile'
deb http://debian.mirrors.ovh.net/debian/ stretch-updates main contrib non-free
deb-src http://debian.mirrors.ovh.net/debian/ stretch-updates main contrib non-free
EOF

#cat > /etc/apt/apt.conf.d/20norecommends <<EOF
#APT {
#  Install-Recommends "false";
#  Install-Suggests "false";
#};
#EOF

apt update

./paquets.zsh bases

systemctl disable rng-tools

yadm clone git@bitbucket.org:manastria/dotfile.git
yadm reset --hard origin/master
