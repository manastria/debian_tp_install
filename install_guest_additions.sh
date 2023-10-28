#!/bin/bash

# Installer les paquets nécessaires pour la compilation
sudo apt-get update
sudo apt-get install -y dkms build-essential linux-headers-$(uname -r)

# Etape 1 : Récupérer la dernière version
LATEST_VERSION=$(curl -s https://download.virtualbox.org/virtualbox/LATEST.TXT)

# Etape 2 : Construire l'URL
ISO_URL="https://download.virtualbox.org/virtualbox/$LATEST_VERSION/VBoxGuestAdditions_$LATEST_VERSION.iso"

# Etape 3 : Télécharger le fichier ISO
curl -o VBoxGuestAdditions.iso $ISO_URL

# Vérifier si le répertoire de montage existe
MOUNT_DIR="/mnt/VBoxGuestAdditions"
if [ ! -d "$MOUNT_DIR" ]; then
    mkdir $MOUNT_DIR
fi

# Etape 4 : Monter le fichier ISO
sudo mount -o loop VBoxGuestAdditions.iso $MOUNT_DIR

# Etape 5 : Exécuter le script d'installation
sudo sh $MOUNT_DIR/VBoxLinuxAdditions.run

# Etape 6 : Démonter le fichier ISO
sudo umount $MOUNT_DIR

# Nettoyer
rm VBoxGuestAdditions.iso
rmdir $MOUNT_DIR

# Vériier si l'installation a réussi
if lsmod | grep -q "vboxguest"; then
    echo "Guest Additions semble avoir été installé avec succès."
else
    echo "Erreur : Guest Additions n'a pas été installé correctement."
    exit 1
fi


echo "Installation des Guest Additions terminée!"
