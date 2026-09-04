#!/usr/bin/env bash
# =============================================================================
# NAME
#     install_virt.sh — Installe les outils invité de l'hyperviseur détecté
#
# SYNOPSIS
#     ./install_virt.sh [-g|--desktop] [-h|--help]
#
# DESCRIPTION
#     Détecte l'hyperviseur avec systemd-detect-virt et installe les outils
#     invité correspondants :
#
#       - VirtualBox (« oracle ») : délègue à install_guest_additions.sh,
#         situé dans le même répertoire.
#       - VMware : paquet open-vm-tools, plus open-vm-tools-desktop si
#         l'option --desktop est donnée.
#
#     Sur une machine physique ou un hyperviseur non pris en charge, le
#     script n'installe rien et sort en succès : il est conçu pour être
#     enchaîné sans condition dans tp_cli.sh. Idempotent : les paquets déjà
#     installés ne sont pas réinstallés.
#
# OPTIONS
#     -g, --desktop  Ajoute open-vm-tools-desktop sur une VM VMware (session
#                    graphique : presse-papier partagé, redimensionnement).
#                    Sans effet sur les autres hyperviseurs.
#     -h, --help     Affiche cette aide et quitte.
#
# EXAMPLES
#     sudo ./install_virt.sh
#         Installe les outils invité adaptés à la VM courante.
#
#     sudo ./install_virt.sh --desktop
#         Idem, avec les extras graphiques VMware.
#
# FILES
#     /var/log/tp-install/install_virt.log   Trace persistante des exécutions.
#
# EXIT CODES
#     0   Succès, hyperviseur non pris en charge, ou machine physique.
#     1   Option inconnue, systemd-detect-virt absent, install_guest_additions.sh
#         introuvable, ou échec de l'installation des paquets.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
# Chemin absolu, résolu depuis celui du script : l'ancienne version appelait
# « ./install_guest_additions.sh » et échouait dès qu'on ne la lançait pas
# depuis le répertoire du dépôt.
readonly GUEST_ADDITIONS_SCRIPT="$(dirname "$(readlink -f "$0")")/install_guest_additions.sh"

DESKTOP=0

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

    # Tout ce que produit le script — y compris apt et install_guest_additions.sh
    # — part à l'écran ET dans le fichier, débarrassé des séquences ANSI qui le
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
while [[ $# -gt 0 ]]; do
  case "$1" in
    -g|--desktop) DESKTOP=1; shift ;;
    -h|--help)    sed -n '2,/^# =\{10,\}$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Option inconnue : $1 (voir -h)" ;;
  esac
done

# -----------------------------------------------------------------------------
# Élévation de privilèges (Tier 1 — opérations exclusivement système)
# -----------------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

# Tier 1 : le script tourne en root, apt ne doit poser aucune question.
export DEBIAN_FRONTEND=noninteractive

# -----------------------------------------------------------------------------
# Détection de l'hyperviseur
# -----------------------------------------------------------------------------
detect_hypervisor() {
    command -v systemd-detect-virt >/dev/null 2>&1 \
        || die "systemd-detect-virt introuvable (paquet systemd)."

    # systemd-detect-virt sort en code 1 quand il ne détecte aucune
    # virtualisation, tout en affichant « none » : sans le « || true », set -e
    # interromprait le script sur une machine physique, cas parfaitement normal.
    systemd-detect-virt || true
}

# -----------------------------------------------------------------------------
# Installation des paquets
# -----------------------------------------------------------------------------
# Installe les paquets manquants parmi ceux passés en argument, et ne fait rien
# si tous sont déjà là — un « apt-get update » coûte plus cher que le test.
install_packages() {
    local -a missing=()
    local pkg

    for pkg in "$@"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            info "$pkg déjà installé."
        else
            missing+=("$pkg")
        fi
    done

    if [ ${#missing[@]} -eq 0 ]; then
        return 0
    fi

    info "Installation de : ${missing[*]}"
    apt-get update -q || die "Échec de « apt-get update »."
    apt-get install -y "${missing[@]}" || die "Échec de l'installation de : ${missing[*]}"
    success "Installé : ${missing[*]}"
}

install_virtualbox_tools() {
    [ -x "$GUEST_ADDITIONS_SCRIPT" ] \
        || die "$GUEST_ADDITIONS_SCRIPT introuvable ou non exécutable."

    info "Délégation à install_guest_additions.sh..."
    "$GUEST_ADDITIONS_SCRIPT" || die "install_guest_additions.sh a échoué."
}

install_vmware_tools() {
    local -a packages=("open-vm-tools")
    if [ "$DESKTOP" -eq 1 ]; then
        packages+=("open-vm-tools-desktop")
    fi
    install_packages "${packages[@]}"
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    setup_logging "$@"

    echo -e "\n${BOLD}=== Outils invité de virtualisation ===${RESET}\n"

    local virt
    virt="$(detect_hypervisor)"
    info "Hyperviseur détecté : ${virt}"

    case "$virt" in
        oracle)
            install_virtualbox_tools
            ;;
        vmware)
            install_vmware_tools
            ;;
        none)
            info "Machine physique : aucun outil invité à installer."
            ;;
        *)
            warn "Hyperviseur « $virt » non pris en charge : rien à installer."
            ;;
    esac

    echo -e "\n${GREEN}${BOLD}Terminé.${RESET}\n"
}

main "$@"
