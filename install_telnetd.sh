#!/usr/bin/env bash
# =============================================================================
# NAME
#     install_telnetd.sh — Installe telnet (client et serveur) en laissant le
#                          service désactivé
#
# SYNOPSIS
#     ./install_telnetd.sh [-h|--help]
#
# DESCRIPTION
#     Prépare l'image distribuée aux étudiants pour le cours SSH
#     (015-ssh-fondamentaux, partie 1, étapes 3 à 6) : le client telnet, le
#     serveur telnetd et le superserveur inetutils-inetd qui le lance sont
#     présents, mais rien n'attend sur le port 23.
#
#     telnet transmet les mots de passe en clair. Le serveur ne doit donc
#     jamais tourner hors séance : à l'étape 3 du cours, l'étudiant l'active
#     lui-même avec « sudo update-inetd --enable telnet » puis
#     « sudo systemctl restart inetutils-inetd ».
#
#     Le script fait, dans l'ordre :
#       1. installe telnet et telnetd (apt-get), s'ils manquent ;
#       2. désactive la ligne telnet de inetd avec « update-inetd --disable »
#          (la ligne est conservée, préfixée de « #<off># », ce qui permet de
#          la réactiver) ;
#       3. arrête inetutils-inetd, qui avait pu démarrer avec telnet actif
#          juste après l'installation du paquet ;
#       4. vérifie le résultat : paquets présents, ligne « #<off># telnet »,
#          port 23 fermé.
#
#     Il peut être relancé sans risque : il remet à chaque fois telnet à l'état
#     « installé mais désactivé ».
#
# OPTIONS
#     -h, --help   Affiche cette aide et quitte.
#
# EXAMPLES
#     ./install_telnetd.sh
#         Prépare l'image : telnet installé, service désactivé.
#
#     sudo -i ; ./install_telnetd.sh
#         Même résultat depuis un shell root (aucun compte à indiquer).
#
# FILES
#     /etc/inetd.conf                              Ligne telnet, commentée
#         par « #<off># » une fois le script passé.
#     /var/log/tp-install/install_telnetd.log      Trace persistante des
#         exécutions.
#
# EXIT CODES
#     0   Succès : telnet installé, désactivé, port 23 fermé.
#     1   Option inconnue, apt-get ou systemctl absent, échec d'installation,
#         ligne telnet introuvable dans inetd, ou port 23 encore ouvert.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
# telnetd et telnet sont des paquets de transition qui tirent inetutils-telnetd
# et inetutils-telnet : on nomme ceux que le cours cite et que verifier-vm.sh
# contrôle.
readonly PACKAGES=(telnet telnetd)
readonly INETD_SERVICE="inetutils-inetd.service"
readonly INETD_NAME="telnet"
readonly PORT=23

# Tier 1 : le script tourne en root, apt ne doit poser aucune question.
export DEBIAN_FRONTEND=noninteractive

# Arguments d'origine, conservés pour l'auto-relance sudo : le parsing ci-dessous
# les consomme avec shift.
readonly ORIG_ARGS=("$@")
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

    # Tout ce que produit le script — y compris apt et systemctl — part à
    # l'écran ET dans le fichier, débarrassé des séquences ANSI.
    exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1
    _TEE_PID=$!

    # Le trap n'est posé qu'une fois la redirection active (pas sur le chemin -h).
    trap cleanup EXIT

    echo "===== $(date '+%F %T') | $(basename "$0") $* | $(id -un)@$(uname -n) ====="
}

cleanup() {
    exec 1>&3 2>&4
    wait "$_TEE_PID" 2>/dev/null
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
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

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_prerequisites() {
    local cmd
    for cmd in apt-get dpkg systemctl ss; do
        command -v "$cmd" >/dev/null 2>&1 || die "$cmd introuvable : ce script cible Debian et Ubuntu."
    done
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
install_packages() {
    local pkg missing=()
    for pkg in "${PACKAGES[@]}"; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done

    if [ "${#missing[@]}" -eq 0 ]; then
        info "${PACKAGES[*]} déjà installés."
        return 0
    fi
    info "Rafraîchissement du cache APT (apt-get update)..."
    apt-get update -q || die "Échec de « apt-get update »."
    info "Installation de ${missing[*]}..."
    apt-get install -y "${missing[@]}" || die "Échec de l'installation de ${missing[*]}."
    success "${missing[*]} installé(s)."
}

# -----------------------------------------------------------------------------
# Désactivation
# -----------------------------------------------------------------------------
# Fichiers de configuration d'inetd qui existent (inetutils-inetd lit aussi
# /etc/inetd.d/, que update-inetd ne gère pas : verifier-vm.sh les parcourt tous).
inetd_files() {
    local f
    [ -r /etc/inetd.conf ] && echo /etc/inetd.conf
    for f in /etc/inetd.d/*; do
        [ -f "$f" ] && [ -r "$f" ] && echo "$f"
    done
    return 0
}

disable_telnet() {
    command -v update-inetd >/dev/null 2>&1 \
        || die "update-inetd introuvable : le paquet telnetd ne l'a pas installé ?"

    # grep -s : un fichier illisible ne doit pas faire échouer le script.
    local files
    mapfile -t files < <(inetd_files)
    [ "${#files[@]}" -gt 0 ] || die "Ni /etc/inetd.conf ni /etc/inetd.d/ : aucun superserveur inetd."

    if grep -qsE "^[[:space:]]*${INETD_NAME}[[:space:]]" "${files[@]}"; then
        info "Ligne $INETD_NAME active dans inetd : désactivation."
        update-inetd --disable "$INETD_NAME" || die "Échec de « update-inetd --disable $INETD_NAME »."
    elif grep -qsE "^#<off>#[[:space:]]*${INETD_NAME}[[:space:]]" "${files[@]}"; then
        info "Ligne $INETD_NAME déjà désactivée dans inetd."
    else
        die "Aucune ligne $INETD_NAME dans inetd : le paquet telnetd ne l'a pas enregistrée."
    fi

    # inetd a pu démarrer avec telnet actif juste après l'installation, et ne
    # relit sa configuration qu'au redémarrage : on l'arrête. Sans ligne active,
    # sa condition de démarrage (ExecCondition) l'empêche de repartir au boot ;
    # l'étudiant le relance à l'étape 3 du cours, une fois telnet réactivé.
    if systemctl is-active --quiet "$INETD_SERVICE"; then
        info "Arrêt de $INETD_SERVICE (il écoutait peut-être sur le port $PORT)..."
        systemctl stop "$INETD_SERVICE" || die "Échec de « systemctl stop $INETD_SERVICE »."
    fi
    success "telnet désactivé dans inetd."
}

# -----------------------------------------------------------------------------
# Vérification
# -----------------------------------------------------------------------------
verify_state() {
    local pkg files
    for pkg in "${PACKAGES[@]}"; do
        dpkg -s "$pkg" >/dev/null 2>&1 || die "Paquet $pkg absent après l'installation."
    done
    success "Paquets présents : ${PACKAGES[*]}."

    mapfile -t files < <(inetd_files)
    grep -qsE "^#<off>#[[:space:]]*${INETD_NAME}[[:space:]]" "${files[@]}" \
        || die "Pas de ligne « #<off># $INETD_NAME » : « update-inetd --enable $INETD_NAME » n'aurait rien à activer."
    grep -qsE "^[[:space:]]*${INETD_NAME}[[:space:]]" "${files[@]}" \
        && die "La ligne $INETD_NAME est encore active dans inetd."
    success "Ligne $INETD_NAME présente et commentée (« #<off># »)."

    # ss -H : sans en-tête, pour que la sortie vide signifie « rien n'écoute ».
    if [ -n "$(ss -H -ltn "sport = :$PORT")" ]; then
        die "Quelque chose écoute encore sur le port $PORT."
    fi
    success "Rien n'attend sur le port $PORT."
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}telnet installé, serveur désactivé.${RESET}"
    echo ""
    echo "  Activation (cours SSH, étape 3) :"
    echo "    sudo update-inetd --enable telnet"
    echo "    sudo systemctl restart inetutils-inetd"
    echo "  Fermeture :"
    echo "    sudo update-inetd --disable telnet"
    echo "    sudo systemctl stop inetutils-inetd"
    echo ""
    echo "  Journal      : $LOG_FILE"
    echo "  Contrôle     : bash public/vm/verifier-vm.sh 015-ssh-fondamentaux"
    echo ""
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    setup_logging "${ORIG_ARGS[@]}"

    echo -e "\n${BOLD}=== Installation de telnet (serveur désactivé) ===${RESET}\n"

    check_prerequisites
    install_packages
    disable_telnet
    verify_state
    print_summary
}

main "$@"
