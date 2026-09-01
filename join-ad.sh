#!/bin/bash

MARKER=/root/run_join.txt

echo "[join-ad] Démarrage du script."

# Si déjà exécuté, sortir
if [ ! -f "$MARKER" ]; then
  echo "[join-ad] Marqueur $MARKER absent : jonction déjà effectuée (ou non requise). Sortie."
  exit 0
fi

echo "[join-ad] Marqueur $MARKER présent : jonction au domaine à effectuer."

if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en root (ou via sudo)." >&2
  exit 1
fi

echo "[join-ad] Droits root confirmés."

echo "[join-ad] En attente de la saisie du nom d'hôte..."
while true; do
  read -rp "Nom d'hôte : " nomhote
  if [[ $nomhote =~ ^N(110|112|212)-.*$ ]]; then
    echo "Nom d'hôte accepté : $nomhote"
    break
  else
    echo "Format invalide. Exemple : N110-01, N110-18, N112-Prof, N212-XXX"
  fi
done

echo "[join-ad] Application du nom d'hôte $nomhote..."
hostname $nomhote

echo "[join-ad] Sortie du domaine AD actuel (realm leave)..."
realm leave

echo "[join-ad] Jonction au domaine edgand.fr (realm join)..."
echo 'HugFimNot%837' | realm join -v --user=fog edgand.fr

echo "[join-ad] Mise à jour de /etc/sssd/sssd.conf..."
sed -i -e 's+^fallback_homedir.*+fallback_homedir = /home/%u+'    /etc/sssd/sssd.conf
sed -i -e 's+^use_fully_qualified_names.*+use_fully_qualified_names = False+'    /etc/sssd/sssd.conf

echo "[join-ad] Redémarrage de sssd..."
systemctl restart sssd

echo "[join-ad] Suppression du marqueur $MARKER et désactivation de firstboot.service..."
/bin/rm "$MARKER"
systemctl disable firstboot.service
sync
echo "Reboot dans 10 secondes ........"
sleep 10
echo reboot
