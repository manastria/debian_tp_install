#!/bin/bash


# Chemin réel du script
real_script_dir=$(readlink -f "$0")
real_script_dir=$(dirname "${real_script_dir}")

YADM_HELPER="${HOME}/debian_tp_install/yadm_helper.sh"

# Vérification de l'existence du fichier
if [ ! -f "$YADM_HELPER" ]; then
    echo "Erreur : $YADM_HELPER n'existe pas."
    exit 1
fi

source "$YADM_HELPER"



printf "\n"
echo -e "\033[32;1mInstallation des paquets\033[0m"
${real_script_dir}/debian_config/install_packages.py -c debian_12 -s basenet tp gpg


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
"${real_script_dir}/configure-sudo.sh"


# GROUPES ET UTILISATEURS
printf "\n"
echo -e "\033[32;1mConfiguration des groupes et utilisateurs\033[0m"

if ! getent group admins > /dev/null 2>&1; then
    groupadd admins
    echo "Groupe 'admins' créé."
fi

if ! getent group adminpwd > /dev/null 2>&1; then
    groupadd adminpwd
    echo "Groupe 'adminpwd' créé."
fi

if ! id -u sysadmin > /dev/null 2>&1; then
    useradd -m -s /bin/bash sysadmin
    echo "sysadmin:netlab123" | chpasswd
    echo "Utilisateur 'sysadmin' créé avec son mot de passe."
fi

if ! id -Gn sysadmin | grep '\badminpwd\b' > /dev/null 2>&1; then
    usermod -aG adminpwd sysadmin
    echo "sysadmin ajouté au groupe adminpwd."
fi


# Pour le TP linuxunhatched
chown root:root /usr/games/sl
chmod 700 /usr/games/sl


# Environnement de sysadmin
echo -e "\033[32;1mEnvironnement yadm\033[0m"
sudo -H -u sysadmin bash -i <<EOF
$(declare -f yadm_manage)
yadm_url="$yadm_url"
yadm_manage
EOF
