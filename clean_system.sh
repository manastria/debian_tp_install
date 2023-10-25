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


apt-get autoremove
apt-get autoclean
apt-get clean


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

# cleanup proxy
awk 'BEGIN{IGNORECASE = 1}!/^Acquire::\w+::proxy/' /etc/apt/apt.conf > temp && chmod 0644 temp && mv -f temp /etc/apt/apt.conf

#cleanup persistent udev rules
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
    rm -f /etc/udev/rules.d/70-persistent-net.rules
fi

#cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*

#cleanup current ssh keys
rm -f /etc/ssh/ssh_host_*

#add check for ssh keys on reboot...regenerate if neccessary
sed -i -e '\|test -f /etc/ssh/ssh_host_dsa_key|d' /etc/rc.local
sed -i -e '\|test -f /etc/hostname|d' /etc/rc.local
sed -i -e '\|^[[:blank:]]*exit 0[[:blank:]]*$|d' /etc/rc.local

bash -c 'echo "test -f /etc/hostname || (h=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 10 | head -n 1); hostnamectl set-hostname \$h; sed -i -e \"\\|^[[:blank:]]*127.0.1.1|d\" /etc/hosts; sed -i -e \"1i 127.0.1.1       \$h\" /etc/hosts)" >> /etc/rc.local'
bash -c 'echo "test -f /etc/ssh/ssh_host_dsa_key || dpkg-reconfigure openssh-server" >> /etc/rc.local'
bash -c 'echo "exit 0" >> /etc/rc.local'


# Suppression du machine-id
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id


#reset hostname
rm -f /etc/hostname

#cleanup shell history
history -w
history -c
find /home /root -name ".bash_history" -exec rm -f {} \;
find /home /root -name ".zhistory" -exec rm -f {} \;



# The following command spews out a list of packages marked by priority.
# Everything that’s not essential, required or important can be safely removed.
# Use apt purge $PACKAGENAME for uninstallation to also get rid of any config files.

#dpkg-query -Wf '${Package;-40}${Priority}\n' | sort -b -k2,2 -k1,1

echo "A taper pour effacer completement l'historique :

unset HISTFILE
"

echo "Fin !"
