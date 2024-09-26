#!/bin/bash

# Fonction pour afficher les messages en bleu si la sortie est un terminal
function info_message {
  if [ -t 1 ]; then
    echo -e "\e[34m$1\e[0m"
  else
    echo "$1"
  fi
}

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
  info_message "L'utilisateur $USERNAME existe déjà, il ne sera pas recréé."
else
  # Création de l'utilisateur avec son répertoire personnel
  info_message "Création de l'utilisateur $USERNAME..."
  useradd -m -s /bin/bash $USERNAME

  # Définition du mot de passe pour l'utilisateur
  info_message "Définition du mot de passe pour $USERNAME..."
  echo "$USERNAME:$PASSWORD" | chpasswd
fi

# Définition du mot de passe pour l'utilisateur root
info_message "Définition du mot de passe pour l'utilisateur root..."
echo "root:admin321" | chpasswd


# Vérification de l'existence de l'archive
if [ ! -f "$TAR_FILE" ]; then
  error_message "Le fichier $TAR_FILE n'existe pas dans le répertoire courant."
  exit 1
fi

# Décompression de l'archive dans le répertoire racine
info_message "Décompression de l'archive $TAR_FILE..."
tar -x -C / -f "$TAR_FILE"

# Changement de propriétaire des fichiers décompressés dans /home/sysadmin
info_message "Changement du propriétaire des fichiers dans /home/$USERNAME..."
chown -R $USERNAME:$USERNAME /home/$USERNAME

# Installation du paquet 'sl'
info_message "Installation du paquet 'sl'..."
apt update && apt install -y sl

# Réglage des permissions pour le programme `sl`
chown root:root /usr/games/sl
chmod 700 /usr/games/sl

info_message "Le script a été exécuté avec succès."
