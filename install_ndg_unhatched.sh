#!/bin/bash

# Vérification si le script est exécuté avec sudo
if [ "$EUID" -ne 0 ]; then
  echo "Veuillez exécuter ce script en tant que root ou avec sudo."
  exit 1
fi

# Variables
USERNAME="sysadmin"
PASSWORD="netlab123"
TAR_FILE="ndg_unhatched.tar.bz2"

# Création de l'utilisateur avec son répertoire personnel
useradd -m -s /bin/bash $USERNAME

# Définition du mot de passe pour l'utilisateur
echo "$USERNAME:$PASSWORD" | chpasswd

# Décompression de l'archive dans le répertoire racine
if [ -f "$TAR_FILE" ]; then
  tar -x -C / -f "$TAR_FILE"
else
  echo "Le fichier $TAR_FILE n'existe pas dans le répertoire courant."
  exit 1
fi

# Changement de propriétaire des fichiers décompressés dans /home/sysadmin
chown -R $USERNAME:$USERNAME /home/$USERNAME

# Installation du paquet 'sl'
apt update && apt install -y sl

echo "Le script a été exécuté avec succès."

