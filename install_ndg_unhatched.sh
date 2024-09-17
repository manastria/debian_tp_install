#!/bin/bash

# Fonction pour afficher les messages d'erreur en rouge si la sortie est un terminal
function error_message {
  if [ -t 1 ]; then
    echo -e "\e[31m$1\e[0m" >&2
  else
    echo "$1" >&2
  fi
}

# Vérification si le script est exécuté avec sudo
if [ "$EUID" -ne 0 ]; then
  error_message "Veuillez exécuter ce script en tant que root ou avec sudo."
  exit 1
fi

# Variables
USERNAME="sysadmin"
PASSWORD="netlab123"
TAR_FILE="ndg_unhatched.tar.bz2"

# Vérification si l'utilisateur existe déjà
if id "$USERNAME" &>/dev/null; then
  error_message "L'utilisateur $USERNAME existe déjà."
  exit 1
fi

# Création de l'utilisateur avec son répertoire personnel
useradd -m -s /bin/bash $USERNAME

# Définition du mot de passe pour l'utilisateur
echo "$USERNAME:$PASSWORD" | chpasswd

# Vérification de l'existence de l'archive
if [ ! -f "$TAR_FILE" ]; then
  error_message "Le fichier $TAR_FILE n'existe pas dans le répertoire courant."
  exit 1
fi

# Décompression de l'archive dans le répertoire racine
tar -x -C / -f "$TAR_FILE"

# Changement de propriétaire des fichiers décompressés dans /home/sysadmin
chown -R $USERNAME:$USERNAME /home/$USERNAME

# Installation du paquet 'sl'
apt update && apt install -y sl

echo "Le script a été exécuté avec succès."
