#!/bin/bash

#add VMware package keys
# wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-DSA-KEY.pub -O - | apt-key add -
# wget http://packages.vmware.com/tools/keys/VMWARE-PACKAGING-GPG-RSA-KEY.pub -O - | apt-key add -

#grab Ubuntu Codename
#codename="$(lsb_release -c | awk {'print $2'})"

#add VMware repository to install open-vm-tools-deploypkg
# echo "deb http://packages.vmware.com/packages/ubuntu $codename main" > /etc/apt/sources.list.d/vmware-tools.list

#update apt-cache
#apt-get update


apt-get autoremove -y
apt-get autoclean -y
apt-get clean -y


#Stop services for cleanup
service rsyslog stop

#clear audit logs
rm -f /var/log/*.log.*
rm -f /var/log/apt/*.*
cat /dev/null > /var/log/btmp
rm -f /var/log/btmp.*
cat /dev/null > /var/log/dmesg
rm -f /var/log/dmesg.*
cat /dev/null > /var/log/lastlog

find /var/log -name "*.gz" -exec rm -f {} \;
find /var/log -name "*.1" -exec rm -f {} \;


#cleanup persistent udev rules
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
    rm -f /etc/udev/rules.d/70-persistent-net.rules
fi

#cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*

# La présence de ce fichier déclenche la réinitialisation du nom d’hôte et des clés SSH au prochain démarrage via /etc/rc.local
touch /etc/do_first_boot

# Suppression du machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

#cleanup shell history
history -w
history -c
find /home /root -name ".bash_history" -exec rm -f {} \;
find /home /root -name ".zhistory" -exec rm -f {} \;


# The following command spews out a list of packages marked by priority.
# Everything that’s not essential, required or important can be safely removed.
# Use apt purge $PACKAGENAME for uninstallation to also get rid of any config files.

#dpkg-query -Wf '${Package;-40}${Priority}\n' | sort -b -k2,2 -k1,1

echo "Historique en mémoire effacé. Pour le vider complètement, exécuter :"
echo "unset HISTFILE"

echo "Fin du script de nettoyage !"
