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

# cleanup proxy
awk 'BEGIN{IGNORECASE = 1}!/^Acquire::\w+::proxy/' /etc/apt/apt.conf > temp && chmod 0644 temp && mv -f temp /etc/apt/apt.conf

#cleanup persistent udev rules
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
    rm -f /etc/udev/rules.d/70-persistent-net.rules
fi

#cleanup /tmp directories
rm -rf /tmp/*
rm -rf /var/tmp/*

#!/bin/bash

# Suppression des clés SSH actuelles pour s'assurer qu'une nouvelle paire sera générée
# lors du prochain démarrage. Ceci permet à chaque machine virtuelle d'avoir des clés uniques.
rm -f /etc/ssh/ssh_host_*

# Nettoyage des lignes spécifiques dans le fichier /etc/rc.local pour éviter des duplications.
# Suppression des lignes qui vérifient ou régénèrent les clés SSH et le hostname.
sed -i -e '\|test -f /etc/ssh/ssh_host_rsa_key|d' /etc/rc.local
# Suppression des anciennes vérifications du hostname dans /etc/rc.local
sed -i -e '\|test -f /etc/hostname|d' /etc/rc.local
# Suppression des lignes contenant "exit 0" pour pouvoir le repositionner à la fin du script.
sed -i -e '\|^[[:blank:]]*exit 0[[:blank:]]*$|d' /etc/rc.local

# Ajout d'une commande dans /etc/rc.local pour générer un nom de machine unique
# si le fichier /etc/hostname n'existe pas. Le nom est aléatoire et ajouté à /etc/hosts.
bash -c 'echo "test -f /etc/hostname || ( \
  h=\$(cat /dev/urandom | tr -dc "a-z0-9" | fold -w 10 | head -n 1); \
  hostnamectl set-hostname \$h; \
  sed -i -e \"\\|^[[:blank:]]*127.0.1.1|d\" /etc/hosts; \
  sed -i -e \"1i 127.0.1.1       \$h\" /etc/hosts; \
  echo \"\$(date +%Y-%m-%d_%H:%M:%S) Hostname generated: \$h\" >> /var/log/hostname-regenerate.log)" >> /etc/rc.local'

# Ajout d'une commande dans /etc/rc.local pour régénérer les clés SSH si elles n'existent pas.
# Un log est également ajouté pour confirmer la régénération des clés SSH.
bash -c 'echo "test -f /etc/ssh/ssh_host_rsa_key || ( \
  dpkg-reconfigure openssh-server; \
  echo \"\$(date +%Y-%m-%d_%H:%M:%S) SSH keys regenerated.\" >> /var/log/hostname-regenerate.log)" >> /etc/rc.local'

# Ajout de la ligne "exit 0" à la fin de /etc/rc.local pour garantir une exécution correcte.
bash -c 'echo "exit 0" >> /etc/rc.local'

# Suppression du fichier /etc/hostname pour forcer la régénération du nom de machine
# au prochain démarrage. Cela permet de ne pas conserver le nom de machine de l'image initiale.
rm -f /etc/hostname

# Création d'un fichier flag /etc/first_boot_complete pour marquer que ce script a été exécuté.
# Cela empêche le script de s'exécuter plus d'une fois.
touch /etc/first_boot_complete



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

echo "A taper pour effacer completement l'historique :

unset HISTFILE
"

echo "Fin !"
