#!/bin/bash
#
# diag-ad.sh — Diagnostic de la jonction Active Directory (Samba-AD edgand.fr)
# et de la résolution des utilisateurs via SSSD/NSS.
#
# LECTURE SEULE : ce script ne modifie RIEN sur le système. Il doit être lancé
# AVANT toute tentative de correction, sinon on perd l'information sur l'état
# réel du poste après "join-ad.sh".
#
# Produit un rapport horodaté dans /tmp/ à transmettre tel quel.
#
# Usage : ./diag-ad.sh [utilisateur_ad_de_test]
#

if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

# Volontairement PAS de "set -e" : le but du script est justement de continuer
# à collecter des informations même quand une commande échoue (c'est souvent
# l'échec lui-même qui est l'information recherchée).
set -u

AD_DOMAIN="edgand.fr"
AD_REALM="EDGAND.FR"

# La saisie se fait AVANT la redirection vers tee, sinon l'invite reste
# bloquée dans le tampon du pipe et l'utilisateur ne voit rien s'afficher.
TEST_USER="${1:-}"
if [ -z "$TEST_USER" ]; then
    read -rp "Nom d'un utilisateur AD existant (pour les tests de résolution) : " TEST_USER
fi
TEST_GROUP="${2:-adminposte}"

REPORT="/tmp/rapport-ad-$(hostname -s)-$(date +%Y%m%d-%H%M%S).txt"

section() { printf '\n\n========== %s ==========\n' "$1"; }

# Exécute une commande en affichant la ligne de commande avant sa sortie, et
# sans jamais interrompre le diagnostic si elle échoue ou n'existe pas.
run() {
    printf '\n$ %s\n' "$*"
    if ! command -v "$1" >/dev/null 2>&1; then
        printf '[diag] commande "%s" introuvable sur ce système.\n' "$1"
        return 0
    fi
    "$@" 2>&1
    local rc=$?
    [ $rc -ne 0 ] && printf '[diag] --> code de retour %s\n' "$rc"
    return 0
}

# Variante pour les pipelines / redirections, qui ne passent pas par "run".
runsh() {
    printf '\n$ %s\n' "$1"
    bash -c "$1" 2>&1
    local rc=$?
    [ $rc -ne 0 ] && printf '[diag] --> code de retour %s\n' "$rc"
    return 0
}

main() {

printf 'RAPPORT DE DIAGNOSTIC AD — %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
printf 'Domaine attendu : %s / Realm : %s\n' "$AD_DOMAIN" "$AD_REALM"
printf 'Utilisateur AD de test : %s\n' "$TEST_USER"
printf 'Groupe AD de test      : %s\n' "$TEST_GROUP"

section "1. SYSTÈME"
run hostnamectl
run uname -a
runsh 'cat /etc/os-release'
# Kerberos refuse tout ticket au-delà de 5 minutes de dérive d'horloge : un
# poste désynchronisé se joint parfois encore (cache) mais ne résout plus rien.
run timedatectl

section "2. PAQUETS INSTALLÉS"
# Via "run" et non "runsh" : les ${...} du format dpkg ne doivent surtout pas
# être réinterprétés comme des expansions de variables par un "bash -c".
run dpkg-query -W -f='${binary:Package} ${Version} [${db:Status-Abbrev}]\n' \
    realmd sssd sssd-common sssd-ad sssd-tools libnss-sss libpam-sss adcli \
    krb5-user samba-common-bin packagekit libsss-sudo

section "3. NSS (nsswitch.conf)"
# Sans "sss" sur les lignes passwd/group, aucun utilisateur AD ne sera jamais
# résolu, même avec un sssd parfaitement fonctionnel.
runsh 'grep -E "^(passwd|group|shadow|hosts|sudoers):" /etc/nsswitch.conf'
runsh 'ls -l /usr/lib/*/libnss_sss.so* 2>&1'

section "4. PAM"
runsh 'ls -1 /usr/share/pam-configs/'
runsh 'grep -n "pam_sss\|mkhomedir" /etc/pam.d/common-auth /etc/pam.d/common-account /etc/pam.d/common-session /etc/pam.d/common-password'

section "5. REALMD"
run realm list
runsh 'cat /etc/realmd.conf 2>&1'

section "6. KERBEROS"
runsh 'ls -l /etc/krb5.keytab 2>&1'
# Le keytab prouve que le compte machine existe VRAIMENT côté AD, ce que
# "realm list" (purement local) ne dit pas.
run klist -k /etc/krb5.keytab
runsh 'cat /etc/krb5.conf 2>&1'

section "7. CONFIGURATION SSSD"
runsh 'ls -l /etc/sssd/ /etc/sssd/conf.d/ 2>&1'
# Masquage de tout secret éventuel avant écriture dans le rapport.
runsh 'sed -E "s/^(.*(authtok|password).*=).*/\1 ***MASQUÉ***/I" /etc/sssd/sssd.conf 2>&1'
runsh 'for f in /etc/sssd/conf.d/*.conf; do [ -e "$f" ] && echo "--- $f ---" && cat "$f"; done 2>&1'
run sssctl config-check

section "8. SERVICES SSSD"
runsh 'systemctl is-enabled sssd; systemctl is-active sssd'
# SSSD >= 2.9 active ses répondeurs par socket : un sssd "running" dont le
# socket nss est masqué ne résout rien du tout.
runsh 'systemctl list-unit-files "sssd*" --no-pager'
runsh 'systemctl status sssd --no-pager -l 2>&1 | head -n 40'
runsh 'journalctl -u sssd --no-pager -n 200 2>&1'

section "9. ÉTAT DU DOMAINE"
run sssctl domain-list
run sssctl domain-status "$AD_DOMAIN"

section "10. RÉSOLUTION DES UTILISATEURS (le cœur du problème)"
# Les deux formes sont testées séparément : si la forme longue fonctionne et
# pas la courte, c'est que "use_fully_qualified_names = False" n'a pas été
# appliqué (mauvaise section dans sssd.conf, ou cache non purgé) — diagnostic
# radicalement différent d'une résolution totalement absente.
run id "$TEST_USER"
run id "${TEST_USER}@${AD_DOMAIN}"
run getent passwd "$TEST_USER"
run getent passwd "${TEST_USER}@${AD_DOMAIN}"
run getent group "$TEST_GROUP"
run sssctl user-checks "$TEST_USER"
run sssctl user-checks "${TEST_USER}@${AD_DOMAIN}"
runsh 'getent passwd | wc -l'
runsh 'getent passwd | tail -n 5'

section "11. DNS ET CONNECTIVITÉ AU CONTRÔLEUR DE DOMAINE"
runsh 'cat /etc/resolv.conf'
run resolvectl status
runsh 'getent hosts '"$AD_DOMAIN"''
runsh 'dig +short SRV _ldap._tcp.'"$AD_DOMAIN"' 2>&1'
runsh 'dig +short SRV _kerberos._udp.'"$AD_DOMAIN"' 2>&1'
runsh 'host -t SRV _ldap._tcp.'"$AD_DOMAIN"' 2>&1'
# Repli si dnsutils/bind9-host ne sont pas installés : resolvectl est présent
# par défaut sur Ubuntu et sait aussi résoudre les enregistrements SRV.
run resolvectl service "_ldap._tcp.${AD_DOMAIN}"

section "12. SYNTHÈSE AUTOMATIQUE"
verdict() { printf '  [%s] %s\n' "$1" "$2"; }
check() { if eval "$1" >/dev/null 2>&1; then verdict "OK" "$2"; else verdict "KO" "$3"; fi; }

check 'dpkg-query -W -f="\${db:Status-Abbrev}" libnss-sss 2>/dev/null | grep -q "^ii"' \
      "libnss-sss est installé" \
      "libnss-sss ABSENT — aucune résolution AD possible (cause n°1)"
check 'dpkg-query -W -f="\${db:Status-Abbrev}" libpam-sss 2>/dev/null | grep -q "^ii"' \
      "libpam-sss est installé" \
      "libpam-sss ABSENT — l'authentification AD ne fonctionnera pas"
check 'grep -qE "^passwd:.*\bsss\b" /etc/nsswitch.conf' \
      "nsswitch.conf : sss présent sur passwd" \
      "nsswitch.conf : sss ABSENT de la ligne passwd (cause n°1 bis)"
check 'grep -qE "^group:.*\bsss\b" /etc/nsswitch.conf' \
      "nsswitch.conf : sss présent sur group" \
      "nsswitch.conf : sss ABSENT de la ligne group"
check 'grep -q pam_sss /etc/pam.d/common-auth' \
      "PAM : pam_sss actif dans common-auth" \
      "PAM : pam_sss ABSENT de common-auth (profil sss non activé)"
check 'systemctl is-active --quiet sssd' \
      "le service sssd tourne" \
      "le service sssd NE TOURNE PAS (voir section 8)"
check 'test -f /etc/krb5.keytab' \
      "keytab machine présent" \
      "keytab /etc/krb5.keytab ABSENT — la jonction n'a pas abouti"
check 'grep -qF "[domain/'"$AD_DOMAIN"']" /etc/sssd/sssd.conf' \
      "section [domain/$AD_DOMAIN] présente dans sssd.conf" \
      "section [domain/$AD_DOMAIN] ABSENTE de sssd.conf (join-ad.sh a pu écrire au mauvais endroit)"
check 'grep -qiE "^[[:space:]]*use_fully_qualified_names[[:space:]]*=[[:space:]]*(False|0)" /etc/sssd/sssd.conf' \
      "use_fully_qualified_names = False appliqué" \
      "use_fully_qualified_names non positionné à False (login = user@$AD_DOMAIN obligatoire)"
check 'id "'"$TEST_USER"'"' \
      "id $TEST_USER RÉSOUT" \
      "id $TEST_USER ne résout pas"
check 'id "'"$TEST_USER"'@'"$AD_DOMAIN"'"' \
      "id ${TEST_USER}@${AD_DOMAIN} RÉSOUT" \
      "id ${TEST_USER}@${AD_DOMAIN} ne résout pas"

printf '\n\n========== FIN DU RAPPORT ==========\n'

}

main | tee "$REPORT"

printf '\n\033[32;1mRapport écrit dans : %s\033[0m\n' "$REPORT"
printf 'Transmettez ce fichier tel quel.\n'
