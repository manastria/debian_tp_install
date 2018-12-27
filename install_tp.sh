#!/bin/bash

printf "\n"
echo -ne "\033[32;1mInstallation des paquets\033[0m"
./paquets.zsh basenet tp
printf "\n"
read -p "Press key to continue.. " -n1 -s

#=============================================================================
# Config reseau
#=============================================================================
cat > /etc/network/interfaces.exemple << EOF
# The primary network interface
#allow-hotplug eth0
#iface eth0 inet static
#	address 192.168.x.1
#	netmask 255.255.255.0
#	network 192.168.x.0
#	broadcast 192.168.x.255
#	gateway 192.168.x.254
#	dns-nameservers 192.168.x.1 x.x.x.x
#	dns-search domain.com

## Multi-IP ##
#auto eth0:0
#iface eth0:0 inet static
#    address 192.168.x.41
#    netmask 255.255.255.0
#    network 192.168.x.0
#    broadcast 192.168.x.255
#    gateway 192.168.x.254
#    dns-nameservers 192.168.x.1 x.x.x.x
#    dns-search domain.com
##

## Bonding ##
## apt-get install ifenslave-2.6
#iface bond0 inet static
#	address 192.168.x.1
#	netmask 255.255.255.0
#	network 192.168.x.0
#	broadcast 192.168.x.255
#	gateway 192.168.x.254
#	dns-nameservers 192.168.x.1 x.x.x.x
#	dns-search domain.com
#	bond-slaves eth0 eth1
#	bond-mode 1
#	bond-miimon 100
#	bond-primary eth0 eth1
##

## VLAN ##
# modprobe 8021q && apt-get install vlan
#iface vlanXX inet static
#        address 10.30.10.12
#        netmask 255.255.0.0
#        network 10.30.0.0
#        broadcast 10.30.255.255
#        vlan-raw-device eth0
##
EOF


# APTCOMMANDNOTFOUND
printf "\n"
echo -ne "\033[32;1mConfiguration de command-not-found\033[0m"
apt update
/usr/sbin/update-command-not-found
printf "\n"
read -p "Press key to continue.. " -n1 -s

# APTAPTFILE
printf "\n"
echo -ne "\033[32;1mConfiguration de apt-file\033[0m"
apt-file update
printf "\n"
read -p "Press key to continue.. " -n1 -s

# SUDO
printf "\n"
echo -ne "\033[32;1mConfiguration de sudo\033[0m"
cat > /etc/sudoers.d/admins << EOF
Defaults        env_keep += "HOME"

# Ajouter sammy comme administrateur
# usermod -aG admins sammy

%adminpwd     ALL=(ALL:ALL)   PASSWD: ALL
%admins        ALL=(ALL:ALL)   NOPASSWD: ALL
EOF
chmod 0440 /etc/sudoers.d/admins


printf "\n"
echo -ne "\033[32;1mConfiguration des groupes\033[0m"
if ! id -u sysadmin > /dev/null 2>&1
then
	useradd -m -p netlab123 sysadmin
fi

if ! getent group admins > /dev/null 2>&1
then
	groupadd admins
fi

if ! id -Gn sysadmin | grep '\badmins\b' > /dev/null 2>&1
then
	usermod -aG admins sysadmin
fi



