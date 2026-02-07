#!/bin/bash

# Relancer le script avec sudo si besoin
if [ "$EUID" -ne 0 ]; then
    exec sudo -E bash "$(readlink -f "$0")" "$@"
fi

set -e  # Arrêter le script à la première erreur

apt-get update
apt-get install -y dkms build-essential linux-headers-"$(uname -r)" curl

# Récupérer et télécharger la dernière version
LATEST_VERSION=$(curl -sf https://download.virtualbox.org/virtualbox/LATEST.TXT)
ISO_PATH="/tmp/VBoxGuestAdditions.iso"
curl -f -o "$ISO_PATH" "https://download.virtualbox.org/virtualbox/$LATEST_VERSION/VBoxGuestAdditions_$LATEST_VERSION.iso"

# Monter et installer
MOUNT_DIR="/mnt/VBoxGuestAdditions"
mkdir -p "$MOUNT_DIR"
mount -o loop "$ISO_PATH" "$MOUNT_DIR"
sh "$MOUNT_DIR/VBoxLinuxAdditions.run" || true  # Retourne souvent un code != 0 même en cas de succès
umount "$MOUNT_DIR"

# Nettoyage
rm -f "$ISO_PATH"
rmdir "$MOUNT_DIR"

echo "Installation terminée. Un redémarrage est recommandé."
