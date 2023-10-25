#/bin/bash

cat > /etc/apt/sources.list <<EOF
deb http://deb.debian.org/debian/ buster main contrib non-free
deb-src http://deb.debian.org/debian/ buster main contrib non-free

deb http://deb.debian.org/debian-security buster/updates main contrib non-free
deb-src http://deb.debian.org/debian-security buster/updates main contrib non-free

# buster-updates, previously known as 'volatile'
deb http://deb.debian.org/debian/ buster-updates main contrib non-free
deb-src http://deb.debian.org/debian/ buster-updates main contrib non-free
EOF


#cat > /etc/apt/apt.conf.d/20norecommends <<EOF
#APT {
#  Install-Recommends "false";
#  Install-Suggests "false";
#};
#EOF

