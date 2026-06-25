#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

# ==============================================================================
# CONFIGURATION DE SUDO
# ==============================================================================
printf "\n"
echo -e "\033[32;1mConfiguration de sudo\033[0m"

# 1. Centralisation des variables d'environnement pour le labo
# Permet de conserver HOME et DISPLAY pour éviter les erreurs d'interface graphique en sudo
cat > /etc/sudoers.d/env_custom << EOF
Defaults        env_keep += "HOME"
Defaults        env_keep += "DISPLAY XAUTHORITY"
Defaults        env_keep += "SSH_AUTH_SOCK"
EOF

chown root:root /etc/sudoers.d/env_custom
chmod 0440 /etc/sudoers.d/env_custom

# Validation syntaxique du fichier d'environnement
if ! visudo -cf /etc/sudoers.d/env_custom > /dev/null 2>&1; then
    echo -e "\033[31;1mErreur de syntaxe dans /etc/sudoers.d/env_custom\033[0m"
fi


# 2. Configuration des droits d'accès pour les groupes de labo
# adminpwd : Avec mot de passe (béquille intermédiaire)
# admins   : Sans mot de passe (béquille débutant)
cat > /etc/sudoers.d/admins << EOF
# Configuration pour les étudiants débutants (béquilles)
%adminpwd   ALL=(ALL:ALL)   PASSWD: ALL
%admins     ALL=(ALL:ALL)   NOPASSWD: ALL
EOF

chown root:root /etc/sudoers.d/admins
chmod 0440 /etc/sudoers.d/admins

# Validation syntaxique du fichier des privilèges
if ! visudo -cf /etc/sudoers.d/admins > /dev/null 2>&1; then
    echo -e "\033[31;1mErreur de syntaxe dans /etc/sudoers.d/admins\033[0m"
fi

printf "\n"
echo -e "\033[32;1mConfiguration de sudo terminée avec succès !\033[0m"
