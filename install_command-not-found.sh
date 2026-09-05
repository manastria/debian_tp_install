#!/usr/bin/env bash
# =============================================================================
# NAME
#     install_command-not-found.sh — Installe et configure command-not-found
#
# SYNOPSIS
#     ./install_command-not-found.sh [-h|--help]
#
# DESCRIPTION
#     Installe le paquet command-not-found sur une machine Debian et
#     construit sa base de suggestions, celle qui propose « apt install
#     paquet-x » quand une commande tapée dans le shell n'existe pas.
#
#     Le script installe le paquet s'il est absent, rafraîchit le cache APT
#     (apt-get update) puis reconstruit la base via
#     /usr/sbin/update-command-not-found. Cette reconstruction est relancée
#     à chaque exécution, y compris si le paquet était déjà présent : c'est
#     elle qui tient la liste de suggestions à jour après l'ajout de
#     nouveaux dépôts ou de nouveaux paquets.
#
#     Ce script ne configure ni sudo, ni apt-file, ni aucun autre paquet de
#     install_tp.sh : il ne s'occupe que de command-not-found.
#
# OPTIONS
#     -h, --help   Affiche cette aide et quitte.
#
# EXAMPLES
#     sudo ./install_command-not-found.sh
#         Installe le paquet si besoin, puis reconstruit sa base.
#
# FILES
#     /usr/sbin/update-command-not-found                       Binaire de
#         reconstruction de la base, fourni par le paquet.
#     /var/log/tp-install/install_command-not-found.log         Trace
#         persistante des exécutions.
#
# EXIT CODES
#     0   Succès.
#     1   Option inconnue, apt-get absent, échec de « apt-get update », échec
#         de l'installation du paquet, ou échec de la reconstruction de la
#         base.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PACKAGE="command-not-found"
readonly UPDATE_BIN="/usr/sbin/update-command-not-found"

# Tier 1 : le script tourne en root, apt ne doit poser aucune question.
export DEBIAN_FRONTEND=noninteractive

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

    # Tout ce que produit le script — y compris apt et update-command-not-found —
    # part à l'écran ET dans le fichier, débarrassé des séquences ANSI qui le
    # rendraient illisible dans un éditeur.
    exec > >(tee >(sed -u 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE")) 2>&1
    _TEE_PID=$!

    # Le trap n'est posé qu'une fois la redirection active, pour ne pas tenter de
    # restaurer des descripteurs jamais dupliqués (ex. chemin -h/--help).
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
# La plage d'aide est délimitée par une expression régulière plutôt que par des
# numéros de ligne : le bloc d'en-tête peut être rallongé sans que l'aide se
# mette à tronquer silencieusement.
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
    exec sudo "$(readlink -f "$0")" "$@"
fi

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_prerequisites() {
    command -v apt-get >/dev/null 2>&1 \
        || die "apt-get introuvable : ce script cible Debian et ses dérivées."
}

# -----------------------------------------------------------------------------
# Installation du paquet
# -----------------------------------------------------------------------------
refresh_apt_cache() {
    info "Rafraîchissement du cache APT (apt-get update)..."
    apt-get update -q || die "Échec de « apt-get update »."
}

install_package() {
    if dpkg -s "$PACKAGE" >/dev/null 2>&1; then
        local version
        version="$(dpkg -s "$PACKAGE" | awk '/^Version:/ { print $2 }')"
        info "$PACKAGE déjà installé (version $version)."
        return 0
    fi

    info "Installation de $PACKAGE..."
    apt-get install -y "$PACKAGE" || die "Échec de l'installation de $PACKAGE."
    success "$PACKAGE installé."
}

# -----------------------------------------------------------------------------
# Configuration (reconstruction de la base de suggestions)
# -----------------------------------------------------------------------------
rebuild_database() {
    if [ ! -x "$UPDATE_BIN" ]; then
        warn "$UPDATE_BIN introuvable : base command-not-found non reconstruite."
        return 0
    fi

    info "Reconstruction de la base command-not-found..."
    "$UPDATE_BIN" || die "Échec de $UPDATE_BIN."
    success "Base command-not-found à jour."
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}command-not-found installé et configuré.${RESET}"
    echo ""
    echo "  Journal      : $LOG_FILE"
    echo ""
    echo "  Test rapide  : tapez une commande inexistante dans un nouveau shell"
    echo ""
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    setup_logging "$@"

    echo -e "\n${BOLD}=== Installation et configuration de command-not-found ===${RESET}\n"

    check_prerequisites
    refresh_apt_cache
    install_package
    rebuild_database
    print_summary
}

main "$@"
