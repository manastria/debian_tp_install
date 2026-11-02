#!/usr/bin/env bash
# =============================================================================
# NAME
#     install_wireshark.sh — Installe Wireshark et autorise la capture sans root
#
# SYNOPSIS
#     ./install_wireshark.sh [-u|--user NOM]... [-h|--help]
#
# DESCRIPTION
#     Installe Wireshark s'il est absent, puis répond « oui » à la question
#     debconf « Should non-superusers be able to capture packets? » du paquet
#     wireshark-common, sans interaction : le groupe système wireshark est
#     créé, dumpcap n'est exécutable que par ce groupe et reçoit les
#     capacités de capture (cap_net_raw, cap_net_admin). Le ou les comptes
#     indiqués sont ensuite ajoutés au groupe wireshark.
#
#     La configuration est appliquée à chaque exécution, y compris si
#     Wireshark était déjà installé avec la réponse « non » (cas d'une image
#     installée à la main) : c'est l'équivalent scripté de
#     « sudo dpkg-reconfigure wireshark-common ».
#
#     Le script vérifie le résultat par une vraie capture d'une seconde sur
#     l'interface lo, lancée sous l'identité de chaque compte.
#
#     L'appartenance au groupe ne prend effet qu'à la prochaine ouverture de
#     session du compte (déconnexion, ou redémarrage de la VM).
#
# OPTIONS
#     -u, --user NOM   Compte à ajouter au groupe wireshark. Répétable.
#                      Défaut : le compte qui a lancé le script (étudiant
#                      sur sa propre VM). Obligatoire depuis un shell root
#                      (« sudo -i », su) : le script s'arrête sinon.
#     -h, --help       Affiche cette aide et quitte.
#
# EXAMPLES
#     ./install_wireshark.sh
#         Étudiant, sur sa VM : configure la capture et s'ajoute au groupe.
#
#     ./install_wireshark.sh -u sysadmin
#         Enseignant, depuis un shell « sudo -i », pour préparer l'image :
#         ajoute le compte étudiant sysadmin au groupe.
#
#     ./install_wireshark.sh -u sysadmin -u profadmin
#         Ajoute les deux comptes au groupe wireshark.
#
# FILES
#     /usr/bin/dumpcap                          Programme de capture utilisé
#         par Wireshark et tshark ; reçoit le groupe et les capacités.
#     /var/log/tp-install/install_wireshark.log  Trace persistante des
#         exécutions.
#
# EXIT CODES
#     0   Succès.
#     1   Option inconnue, lancé depuis un shell root sans -u, compte
#         inexistant, apt-get absent, échec d'installation ou de
#         reconfiguration, ou capture de vérification impossible.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PACKAGE="wireshark"
readonly DEBCONF_QUESTION="wireshark-common/install-setuid"
readonly GROUP="wireshark"
readonly DUMPCAP="/usr/bin/dumpcap"

# Tier 1 : le script tourne en root, apt ne doit poser aucune question.
export DEBIAN_FRONTEND=noninteractive

# Arguments d'origine, conservés pour l'auto-relance sudo : le parsing ci-dessous
# les consomme avec shift.
readonly ORIG_ARGS=("$@")
USERS=()
TMP_DIR=""
_TEE_PID=""

# -----------------------------------------------------------------------------
# Couleurs et fonctions de log
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}      $*"; }
success() { echo -e "${GREEN}[OK]${RESET}        $*"; }
warn()    { echo -e "${YELLOW}[ATTENTION]${RESET} $*"; }
error()   { echo -e "${RED}[ERREUR]${RESET}    $*" >&2; }
die()     { error "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Trace persistante (/var/log/tp-install)
# -----------------------------------------------------------------------------
readonly LOG_DIR="/var/log/tp-install"
readonly LOG_FILE="${LOG_DIR}/$(basename "$0" .sh).log"

setup_logging() {
    install -d -m 0750 -o root -g adm "$LOG_DIR"
    [ -e "$LOG_FILE" ] || install -m 0640 -o root -g adm /dev/null "$LOG_FILE"

    # Sauvegarde des descripteurs d'origine, pour les restaurer en fin de script.
    exec 3>&1 4>&2

    # Tout ce que produit le script — y compris apt et dpkg-reconfigure — part à
    # l'écran ET dans le fichier, débarrassé des séquences ANSI.
    exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1
    _TEE_PID=$!

    # Le trap n'est posé qu'une fois la redirection active (pas sur le chemin -h).
    trap cleanup EXIT

    echo "===== $(date '+%F %T') | $(basename "$0") $* | $(id -un)@$(uname -n) ====="
}

cleanup() {
    [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
    exec 1>&3 2>&4
    wait "$_TEE_PID" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -u|--user)
      [ -n "${2:-}" ] || die "$1 attend un nom de compte."
      USERS+=("$2"); shift 2 ;;
    -h|--help) sed -n '2,/^# =\{10,\}$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Option inconnue : $1 (voir -h)" ;;
  esac
done

# -----------------------------------------------------------------------------
# Élévation de privilèges (Tier 1 — opérations exclusivement système)
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "${ORIG_ARGS[@]}"
fi

# Sans -u, le compte qui a lancé le script. SUDO_USER ne suffit pas à le
# désigner : dans un shell ouvert par « sudo -i », il vaut aussi le compte qui a
# ouvert ce shell (l'enseignant), pas le compte étudiant. SUDO_COMMAND tranche :
# il contient le nom du script quand sudo a lancé le script lui-même (auto-
# relance, « sudo ./install_wireshark.sh »), et seulement le shell sinon.
if [ "${#USERS[@]}" -eq 0 ]; then
    if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != root ] \
        && [[ "${SUDO_COMMAND:-}" == *"$(basename "$0")"* ]]; then
        USERS=("$SUDO_USER")
        readonly USERS_SOURCE="compte qui a lancé le script"
    else
        die "Lancé depuis un shell root : préciser le compte étudiant avec -u NOM (ex. -u sysadmin)."
    fi
else
    readonly USERS_SOURCE="option -u"
fi

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_prerequisites() {
    local cmd user
    for cmd in apt-get debconf-set-selections dpkg-reconfigure runuser; do
        command -v "$cmd" >/dev/null 2>&1 || die "$cmd introuvable : ce script cible Debian et Ubuntu."
    done
    for user in "${USERS[@]}"; do
        id "$user" >/dev/null 2>&1 || die "Compte inexistant : $user"
    done
    info "Compte(s) à ajouter au groupe $GROUP : ${USERS[*]} ($USERS_SOURCE)"
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
preseed_debconf() {
    # La réponse est enregistrée avant l'installation : apt ne pose alors pas la
    # question, et dpkg-reconfigure la reprend plus bas si le paquet existait.
    info "Réponse debconf : $DEBCONF_QUESTION = true"
    echo "wireshark-common $DEBCONF_QUESTION boolean true" | debconf-set-selections \
        || die "Échec de debconf-set-selections."
}

install_packages() {
    local missing=()
    dpkg -s "$PACKAGE" >/dev/null 2>&1 || missing+=("$PACKAGE")
    # setcap vient de libcap2-bin ; sans lui, le postinst de wireshark-common
    # rend dumpcap setuid root au lieu de lui donner des capacités.
    command -v setcap >/dev/null 2>&1 || missing+=(libcap2-bin)

    if [ "${#missing[@]}" -eq 0 ]; then
        info "$PACKAGE déjà installé (version $(dpkg-query -W -f='${Version}' "$PACKAGE"))."
        return 0
    fi
    info "Rafraîchissement du cache APT (apt-get update)..."
    apt-get update -q || die "Échec de « apt-get update »."
    info "Installation de ${missing[*]}..."
    apt-get install -y "${missing[@]}" || die "Échec de l'installation de ${missing[*]}."
    success "${missing[*]} installé(s)."
}

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
configure_dumpcap() {
    # Le postinst ne touche pas à dumpcap si un dpkg-statoverride existe : un
    # réglage fait à la main l'emporte alors sur la réponse debconf.
    if dpkg-statoverride --list "$DUMPCAP" >/dev/null 2>&1; then
        warn "dpkg-statoverride présent sur $DUMPCAP : le paquet ne le modifiera pas."
        warn "  $(dpkg-statoverride --list "$DUMPCAP")"
    fi
    info "Reconfiguration de wireshark-common..."
    dpkg-reconfigure -f noninteractive wireshark-common \
        || die "Échec de dpkg-reconfigure wireshark-common."
    getent group "$GROUP" >/dev/null || die "Le groupe $GROUP n'a pas été créé."
    success "Groupe $GROUP présent ; dumpcap : $(stat -c '%A %U:%G' "$DUMPCAP")"
}

add_users() {
    local user
    for user in "${USERS[@]}"; do
        # Test sans pipe : avec pipefail, « | grep -q » peut échouer par SIGPIPE.
        if [[ " $(id -nG "$user") " == *" $GROUP "* ]]; then
            info "$user est déjà dans le groupe $GROUP."
        else
            usermod -aG "$GROUP" "$user" || die "Échec de usermod -aG $GROUP $user."
            success "$user ajouté au groupe $GROUP."
        fi
    done
}

# -----------------------------------------------------------------------------
# Vérification
# -----------------------------------------------------------------------------
verify_capture() {
    local caps user dir
    caps="$(getcap "$DUMPCAP" 2>/dev/null || true)"
    if [[ "$caps" == *cap_net_raw* ]]; then
        success "Capacités de dumpcap : ${caps#"$DUMPCAP" }"
    elif [ -u "$DUMPCAP" ]; then
        info "dumpcap est setuid root (pas de capacités de fichier)."
    else
        die "dumpcap n'a ni capacités ni setuid : la capture sans root est impossible."
    fi

    [ "${#USERS[@]}" -gt 0 ] || return 0
    TMP_DIR="$(mktemp -d)"
    chmod 0711 "$TMP_DIR"
    for user in "${USERS[@]}"; do
        # runuser recharge les groupes depuis /etc/group : l'ajout fait plus haut
        # compte déjà, sans attendre une nouvelle session.
        dir="$TMP_DIR/$user"
        install -d -m 0700 -o "$user" "$dir"
        if runuser -u "$user" -- dumpcap -q -i lo -a duration:1 -w "$dir/test.pcapng" \
            >"$TMP_DIR/$user.log" 2>&1; then
            success "Capture d'essai réussie sous l'identité de $user."
        else
            error "Capture d'essai impossible sous l'identité de $user :"
            sed 's/^/    /' "$TMP_DIR/$user.log" >&2
            die "Vérifier le groupe $GROUP et les droits de $DUMPCAP."
        fi
    done
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}Wireshark installé, capture autorisée au groupe $GROUP.${RESET}"
    echo ""
    echo "  Comptes      : ${USERS[*]:-aucun}"
    echo "  Journal      : $LOG_FILE"
    echo ""
    echo "  Le groupe ne compte qu'à la prochaine ouverture de session :"
    echo "  se déconnecter puis se reconnecter (ou redémarrer la VM)."
    echo ""
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    setup_logging "${ORIG_ARGS[@]}"

    echo -e "\n${BOLD}=== Installation de Wireshark (capture sans root) ===${RESET}\n"

    check_prerequisites
    preseed_debconf
    install_packages
    configure_dumpcap
    add_users
    verify_capture
    print_summary
}

main "$@"
