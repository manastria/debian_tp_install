#!/bin/bash
#
# join-ad.sh — Jonction au domaine Active Directory (Samba-AD) edgand.fr.
#

set -eu

AD_DOMAIN="edgand.fr"
AD_JOIN_USER="fog"
AD_JOIN_PASSWORD="HugFimNot%837"

if [ "$EUID" -ne 0 ]; then
  echo "Ce script doit être exécuté en root (ou via sudo)." >&2
  exit 1
fi

# S'assure qu'une clé "key = value" existe dans la section [section] d'un
# fichier ini (sssd.conf) : la remplace si elle existe déjà, l'ajoute en fin
# de section sinon. Un simple "sed s/^key.*/.../ " ne fait rien quand la clé
# n'existe pas encore dans le fichier généré par "realm join" — d'où ce
# helper, qui couvre les deux cas. N'échoue que si la section est absente.
set_ini_option() {
    local file="$1" section="$2" key="$3" value="$4"
    if ! grep -qF "[$section]" "$file" 2>/dev/null; then
        echo "[join-ad] Section [$section] absente de $file, configuration ignorée." >&2
        return 1
    fi
    # umask serré : le fichier temporaire ne doit jamais être plus permissif
    # que l'original, même brièvement (sssd.conf est souvent en 600).
    ( umask 077 && awk -v section="[$section]" -v key="$key" -v value="$value" '
        BEGIN { in_section = 0; done = 0 }
        /^\[/ {
            if (in_section && !done) { print key " = " value; done = 1 }
            in_section = ($0 == section)
            print
            next
        }
        {
            if (in_section && $0 ~ "^" key "[ \t]*=") {
                print key " = " value
                done = 1
                next
            }
            print
        }
        END { if (in_section && !done) print key " = " value }
    ' "$file" > "${file}.tmp" )
    # "mv" ne restaure pas le mode/propriétaire de l'ancien fichier : sans ce
    # calage explicite, sssd.conf perd ses permissions strictes (600) et
    # sssd refuse ensuite de le lire ("Unexpected access ... by other users").
    chmod --reference="$file" "${file}.tmp"
    chown --reference="$file" "${file}.tmp"
    mv "${file}.tmp" "$file"
}

echo "[join-ad] En attente de la saisie du nom d'hôte..."
while true; do
  read -rp "Nom d'hôte : " nomhote
  if [[ $nomhote =~ ^N(110|112|212)-[0-9]{2}$ ]]; then
    echo "Nom d'hôte accepté : $nomhote"
    break
  else
    echo "Format invalide. Exemple : N110-01, N112-18, N212-99 (deux chiffres obligatoires après le tiret)"
  fi
done

echo "[join-ad] Application du nom d'hôte $nomhote..."
hostnamectl set-hostname "$nomhote"

# On (re)joint systématiquement, plutôt que de sauter l'étape si "realm
# list" rapporte déjà le domaine : cette information ne reflète que la
# config locale, pas la validité réelle du compte machine/keytab côté AD, ni
# le hostname sous lequel il a été enregistré. Idempotent quand même : l'état
# final (jointure fraîche sous le hostname actuel) est le même à chaque run.
echo "[join-ad] Sortie du domaine actuel si applicable..."
realm leave 2>/dev/null || true

echo "[join-ad] Jonction au domaine $AD_DOMAIN..."
realm join -v --user="$AD_JOIN_USER" "$AD_DOMAIN" <<< "$AD_JOIN_PASSWORD"

echo "[join-ad] Configuration de /etc/sssd/sssd.conf pour le domaine $AD_DOMAIN..."
SSSD_SECTION="domain/${AD_DOMAIN}"
if ! grep -qF "[$SSSD_SECTION]" /etc/sssd/sssd.conf 2>/dev/null; then
    SSSD_DETECTED="$(grep -oE '^\[domain/[^]]+\]' /etc/sssd/sssd.conf 2>/dev/null | head -n1 | tr -d '[]')"
    if [ -n "$SSSD_DETECTED" ]; then
        echo "[join-ad] Section [$SSSD_SECTION] introuvable, utilisation de [$SSSD_DETECTED] à la place." >&2
        SSSD_SECTION="$SSSD_DETECTED"
    fi
fi
set_ini_option /etc/sssd/sssd.conf "$SSSD_SECTION" "fallback_homedir" "/home/%u"
set_ini_option /etc/sssd/sssd.conf "$SSSD_SECTION" "use_fully_qualified_names" "False"

# fallback_homedir indique seulement le CHEMIN attendu ; sans pam_mkhomedir,
# le répertoire n'est jamais créé au premier login. pam-auth-update est la
# façon Debian-native (et idempotente) de l'activer, plutôt qu'éditer
# /etc/pam.d/common-session à la main.
echo "[join-ad] Activation de la création automatique du home directory (pam_mkhomedir)..."
if [ -f /usr/share/pam-configs/mkhomedir ]; then
    pam-auth-update --enable mkhomedir
else
    echo "[join-ad] Profil PAM mkhomedir introuvable (paquet libpam-modules manquant ?), étape ignorée." >&2
fi

echo "[join-ad] Redémarrage de sssd..."
systemctl restart sssd

echo "[join-ad] Terminé."
