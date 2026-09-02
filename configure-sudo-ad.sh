#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

set -eu

# ==============================================================================
# CONFIGURATION DE SUDO POUR LE GROUPE AD "adminposte"
# ==============================================================================
# Autorise les membres du groupe Active Directory "adminposte" (edgand.fr) à
# utiliser sudo sur cette machine. Le groupe est résolu via sssd/NSS ; il
# n'est PAS créé localement, contrairement à admins/adminpwd dans
# configure-sudo.sh — ce serait un groupe en conflit avec celui de l'AD.
# L'appartenance à adminposte se gère côté AD, pas avec usermod ici.
#
# Idempotent : peut être relancé sans risque, le fichier sudoers généré est
# toujours identique. Il est validé avec "visudo -c" sur une copie
# temporaire AVANT d'être installé — jamais écrit directement en place.

printf "\n"
echo -e "\033[32;1mConfiguration de sudo pour le groupe AD adminposte\033[0m"

AD_SUDO_GROUP="adminposte"
SUDOERS_FILE="/etc/sudoers.d/ad_${AD_SUDO_GROUP}"

# Vérification informative : le groupe PRIMAIRE d'un utilisateur AD
# n'apparaît jamais dans la liste des membres de "getent group <groupe>"
# (voir "id <utilisateur>" pour la liste réelle) — c'est normal et n'empêche
# pas sudo de fonctionner, qui résout l'appartenance différemment. Ce test
# échoue seulement si le NOM du groupe ne résout pas du tout via NSS, ce qui,
# là, empêcherait la règle sudoers de fonctionner pour qui que ce soit.
if getent group "$AD_SUDO_GROUP" > /dev/null 2>&1; then
    echo "Groupe '$AD_SUDO_GROUP' résolu via NSS (OK)."
else
    echo -e "\033[31;1mATTENTION : '$AD_SUDO_GROUP' ne résout pas via getent/NSS.\033[0m"
    echo -e "\033[31;1mLa règle sudoers ne fonctionnera pour personne tant que ce n'est pas résolu.\033[0m"
    echo "Vérifiez : systemctl status sssd, et que le groupe existe bien dans l'AD."
fi

SUDOERS_TMP="$(mktemp)"
trap 'rm -f "$SUDOERS_TMP"' EXIT

cat > "$SUDOERS_TMP" << EOF
# Membres du groupe AD adminposte (edgand.fr) : sudo avec mot de passe.
"%${AD_SUDO_GROUP}"   ALL=(ALL:ALL)   ALL
EOF

if ! visudo -cf "$SUDOERS_TMP" > /dev/null 2>&1; then
    echo -e "\033[31;1mErreur de syntaxe : règle sudoers non appliquée.\033[0m"
    exit 1
fi

install -m 0440 -o root -g root "$SUDOERS_TMP" "$SUDOERS_FILE"

printf "\n"
echo -e "\033[32;1mConfiguration de sudo terminée avec succès !\033[0m"

# ==============================================================================
# VÉRIFICATION
# ==============================================================================
printf "\n"
echo -e "\033[36;1mPour vérifier que ça fonctionne réellement :\033[0m"
cat << EOF

  En tant que membre de '${AD_SUDO_GROUP}' :

    sudo -l

  Doit lister la règle sudo, que ce membre ait ${AD_SUDO_GROUP} comme groupe
  secondaire OU comme groupe primaire côté AD — c'est le test qui fait foi
  (plus fiable que "getent group" pour ce cas précis).

EOF
