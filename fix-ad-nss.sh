#!/bin/bash
#
# fix-ad-nss.sh — Répare la chaîne de résolution des utilisateurs AD
# (paquets NSS/PAM, nsswitch.conf, profils PAM, cache SSSD).
#
# À lancer APRÈS diag-ad.sh (qui, lui, ne modifie rien) et APRÈS join-ad.sh.
# Ne rejoint PAS le domaine : ce script ne s'occupe que de la partie
# "les comptes AD sont-ils visibles depuis le système".
#
# Idempotent : relançable sans risque.
#
# Usage : ./fix-ad-nss.sh [utilisateur_ad_de_test]
#

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

set -eu

AD_DOMAIN="edgand.fr"
TEST_USER="${1:-}"

STAMP="$(date +%Y%m%d-%H%M%S)"

echo -e "\033[32;1m=== Réparation de la résolution des utilisateurs AD ===\033[0m"

# ---------------------------------------------------------------------------
# 1. Paquets
# ---------------------------------------------------------------------------
# "realm join" peut réussir sans libnss-sss / libpam-sss : la jonction est
# faite par adcli et ne dépend pas de NSS. C'est exactement le scénario
# "machine bien jointe mais aucun utilisateur visible".
echo
echo "[fix-ad] Installation des paquets nécessaires..."
export DEBIAN_FRONTEND=noninteractive
apt-get update || echo "[fix-ad] apt-get update en échec, poursuite avec le cache local." >&2
apt-get install -y \
    realmd sssd sssd-tools sssd-ad \
    libnss-sss libpam-sss libsss-sudo \
    adcli samba-common-bin krb5-user packagekit

# ---------------------------------------------------------------------------
# 2. NSS
# ---------------------------------------------------------------------------
# Ajoute "sss" à une base de nsswitch.conf si absent. L'installation de
# libnss-sss le fait normalement toute seule, mais pas si le fichier a été
# remplacé par une image système ou un post-install maison.
ensure_nss_sss() {
    local db="$1" file="/etc/nsswitch.conf"
    if grep -qE "^${db}:.*(^|[[:space:]])sss([[:space:]]|$)" "$file"; then
        echo "[fix-ad] nsswitch : '$db' référence déjà sss."
        return 0
    fi
    if grep -qE "^${db}:" "$file"; then
        sed -i -E "s/^(${db}:.*)\$/\1 sss/" "$file"
        echo "[fix-ad] nsswitch : sss ajouté à la ligne '$db'."
    else
        printf '%s: files sss\n' "$db" >> "$file"
        echo "[fix-ad] nsswitch : ligne '$db' créée avec sss."
    fi
}

echo
echo "[fix-ad] Vérification de /etc/nsswitch.conf..."
cp -a /etc/nsswitch.conf "/etc/nsswitch.conf.bak-${STAMP}"
ensure_nss_sss passwd
ensure_nss_sss group
ensure_nss_sss shadow
echo "[fix-ad] Sauvegarde : /etc/nsswitch.conf.bak-${STAMP}"

# ---------------------------------------------------------------------------
# 3. PAM
# ---------------------------------------------------------------------------
# pam-auth-update est la voie Debian-native et idempotente ; éditer
# /etc/pam.d/common-* à la main serait écrasé au prochain update des paquets.
echo
echo "[fix-ad] Activation des profils PAM..."
for profile in sss mkhomedir; do
    if [ -f "/usr/share/pam-configs/$profile" ]; then
        pam-auth-update --enable "$profile"
        echo "[fix-ad] Profil PAM '$profile' activé."
    else
        echo "[fix-ad] Profil PAM '$profile' introuvable, ignoré." >&2
    fi
done

# ---------------------------------------------------------------------------
# 4. SSSD : redémarrage avec purge du cache
# ---------------------------------------------------------------------------
# Un simple "systemctl restart sssd" ne suffit pas quand on change le format
# des noms (use_fully_qualified_names) ou le mapping d'UID : les entrées
# négatives et les anciens UID restent en cache dans /var/lib/sss/db.
echo
echo "[fix-ad] Redémarrage de sssd avec purge du cache..."
systemctl stop sssd || true
rm -f /var/lib/sss/db/* /var/lib/sss/mc/* 2>/dev/null || true
systemctl enable --now sssd
systemctl restart sssd

# Les répondeurs de SSSD >= 2.9 sont activés par socket ; si les sockets sont
# désactivées, sssd tourne mais NSS n'obtient jamais de réponse.
for unit in sssd-nss.socket sssd-pam.socket; do
    if systemctl list-unit-files "$unit" >/dev/null 2>&1 && \
       systemctl cat "$unit" >/dev/null 2>&1; then
        systemctl enable --now "$unit" 2>/dev/null || true
    fi
done

echo
echo "[fix-ad] Attente de la disponibilité de sssd..."
for _ in $(seq 1 15); do
    if sssctl domain-status "$AD_DOMAIN" >/dev/null 2>&1; then break; fi
    sleep 1
done

# ---------------------------------------------------------------------------
# 5. Vérification
# ---------------------------------------------------------------------------
echo
echo -e "\033[36;1m=== Vérification ===\033[0m"
sssctl domain-status "$AD_DOMAIN" || true

if [ -z "$TEST_USER" ]; then
    read -rp "Nom d'un utilisateur AD pour le test final (vide = ignorer) : " TEST_USER
fi

if [ -n "$TEST_USER" ]; then
    echo
    echo "--- id $TEST_USER ---"
    if id "$TEST_USER"; then
        echo -e "\033[32;1mSUCCÈS : la résolution des utilisateurs AD fonctionne.\033[0m"
    else
        echo -e "\033[33;1mÉchec en nom court. Test en nom complet...\033[0m"
        if id "${TEST_USER}@${AD_DOMAIN}"; then
            echo -e "\033[33;1mLe nom COMPLET résout, mais pas le nom court.\033[0m"
            echo "=> use_fully_qualified_names n'est pas appliqué dans la bonne"
            echo "   section de /etc/sssd/sssd.conf. Relancez join-ad.sh, puis"
            echo "   ce script, et joignez le rapport de diag-ad.sh."
        else
            echo -e "\033[31;1mÉchec des deux formes : le problème n'est pas NSS/PAM.\033[0m"
            echo "=> Relancez ./diag-ad.sh et transmettez le rapport ; regardez"
            echo "   en priorité les sections 6 (Kerberos), 8 (journal sssd) et"
            echo "   11 (DNS vers le contrôleur de domaine)."
        fi
    fi
fi

echo
echo -e "\033[32;1m=== Terminé ===\033[0m"
