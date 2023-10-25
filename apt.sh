#/bin/bash

cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian/ bullseye main contrib non-free
deb http://security.debian.org/debian-security bullseye-security main contrib non-free
deb http://deb.debian.org/debian/ bullseye-updates main contrib non-free
deb http://deb.debian.org/debian/ bullseye-proposed-updates main contrib non-free
deb http://deb.debian.org/debian/ bullseye-backports main contrib non-free

EOF


#cat > /etc/apt/apt.conf.d/20norecommends <<EOF
#APT {
#  Install-Recommends "false";
#  Install-Suggests "false";
#};
#EOF
