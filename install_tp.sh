#!/bin/bash


# Chemin réel du script
real_script_dir=$(readlink -f "$0")
real_script_dir=$(dirname "${real_script_dir}")



printf "\n"
echo -e "\033[32;1mInstallation des paquets\033[0m"
${real_script_dir}/bin/install_packages.py -c debian_12 -s basenet tp gpg


printf "\n"
# read -p "Press key to continue.. " -n1 -s

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
echo -e "\033[32;1mConfiguration de command-not-found\033[0m"
apt update
/usr/sbin/update-command-not-found
printf "\n"
# read -p "Press key to continue.. " -n1 -s

# APTAPTFILE
printf "\n"
echo -e "\033[32;1mConfiguration de apt-file\033[0m"
apt-file update
printf "\n"
# read -p "Press key to continue.. " -n1 -s

# SUDO
printf "\n"
echo -e "\033[32;1mConfiguration de sudo\033[0m"
cat > /etc/sudoers.d/admins << EOF
Defaults        env_keep += "HOME"

# Ajouter sammy comme administrateur
# usermod -aG admins sammy

%adminpwd     ALL=(ALL:ALL)   PASSWD: ALL
%admins        ALL=(ALL:ALL)   NOPASSWD: ALL
EOF
chown root:root /etc/sudoers.d/admins
chmod 0440 /etc/sudoers.d/admins

cat > /etc/sudoers.d/sshagent << EOF
Defaults        env_keep += "SSH_AUTH_SOCK"
EOF
chown root:root /etc/sudoers.d/sshagent
chmod 0440 /etc/sudoers.d/sshagent


cat > /etc/sudoers << EOF
#
# This file MUST be edited with the 'visudo' command as root.
#
# Please consider adding local content in /etc/sudoers.d/ instead of
# directly modifying this file.
#
# See the man page for details on how to write a sudoers file.
#
Defaults        env_reset
Defaults        mail_badpass
Defaults        secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games"

# Host alias specification

# User alias specification

# Cmnd alias specification

# User privilege specification
root    ALL=(ALL:ALL) ALL

# Allow members of group sudo to execute any command
%sudo   ALL=(ALL:ALL) ALL

# See sudoers(5) for more information on "#include" directives:

#includedir /etc/sudoers.d

Defaults env_keep+="DISPLAY"
# Defaults env_keep="XAUTHORIZATION XAUTHORITY TZ PS2 PS1 PATH LS_COLORS KRB5CCNAME HOSTNAME HOME DISPLAY COLORS"
EOF
chown root:root /etc/sudoers
chmod 0440 /etc/sudoers



printf "\n"
echo -e "\033[32;1mConfiguration des groupes\033[0m"
if ! id -u sysadmin > /dev/null 2>&1
then
	useradd -m -p netlab123 sysadmin
fi

if ! getent group admins > /dev/null 2>&1
then
	groupadd admins
fi

if ! getent group adminpwd > /dev/null 2>&1
then
	groupadd adminpwd
fi

if ! id -Gn sysadmin | grep '\badmins\b' > /dev/null 2>&1
then
	usermod -aG adminpwd sysadmin
fi


# Pour le TP linuxunhatched
chown root:root /usr/games/sl
chmod 700 /usr/games/sl


# Environnement de sysadmin
echo -e "\033[32;1mEnvironnement yadm\033[0m"
sudo -u sysadmin --set-home yadm clone https://manastria@bitbucket.org/manastria/dotfile.git
sudo -u sysadmin --set-home yadm reset --hard origin/master
