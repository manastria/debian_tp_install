#!/bin/bash

cat > /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local

[Service]
Type=forking
ExecStartPre=/bin/sleep 3
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99

[Install]
WantedBy=multi-user.target
EOF

cat > /etc/rc.local <<EOF
#!/bin/sh
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

#!/bin/bash
#
# /etc/rc.local
# Script lancé à chaque démarrage. Si /etc/do_first_boot existe,
# on régénère le nom d’hôte et les clés SSH, puis on supprime ce flag.

# Si vous utilisez systemd, veillez à ce que rc.local soit bien exécuté
# (via un service systemd rc-local ou équivalent).

if [ -f /etc/do_first_boot ]; then
  echo "Premier démarrage : réinitialisation du nom d'hôte et des clés SSH."

  # 1) Suppression des clés SSH actuelles
  rm -f /etc/ssh/ssh_host_*

  # 2) Suppression du fichier /etc/hostname
  #    pour forcer la génération d'un nouveau nom (ou le paramétrer ci-dessous).
  rm -f /etc/hostname

  # 3) Génération d'un nouveau nom d'hôte
  #    (vous pouvez adapter la logique, par ex. un préfixe + suffixe aléatoire)
  newhost="vm-$(tr -dc 'a-z0-9' < /dev/urandom | head -c 10)"

  # Vérification que la variable est bien remplie
  if [ -z "$newhost" ]; then
  echo "Erreur : échec de la génération du nom d'hôte." >&2
  exit 1
  fi

  echo "Nouveau nom d'hôte généré : $newhost"

  hostnamectl set-hostname "$newhost"

  # Mise à jour /etc/hosts pour pointer 127.0.1.1 vers le nouveau nom
  sed -i '/^[[:blank:]]*127\.0\.1\.1/d' /etc/hosts
  echo "127.0.1.1       $newhost" >> /etc/hosts

  # Log
  echo "$(date +%Y-%m-%d_%H:%M:%S) - Nouveau hostname : $newhost" >> /var/log/hostname-regenerate.log

  # 4) Régénération des clés SSH
  dpkg-reconfigure openssh-server
  echo "$(date +%Y-%m-%d_%H:%M:%S) - Nouvelles clés SSH générées." >> /var/log/hostname-regenerate.log

  # 5) Suppression du flag pour éviter que ça ne se refasse à chaque démarrage
  rm -f /etc/do_first_boot

  echo "Réinitialisation terminée."
fi

exit 0
EOF

chmod +x /etc/rc.local
systemctl enable rc-local
