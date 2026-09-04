#!/usr/bin/env bash
# =============================================================================
# NAME
#     make_rclocal.sh — Installe le relais de réinitialisation au premier
#     démarrage (rc.local + rc-local.service)
#
# SYNOPSIS
#     ./make_rclocal.sh [--arm] [--force] [-h|--help]
#
# DESCRIPTION
#     Installe les trois pièces du relais de réinitialisation :
#
#       - /etc/rc.local, copie du rc.local du dépôt ;
#       - rc-local.service, qui l'exécute à chaque démarrage ;
#       - ssh-regen-keys.service, qui régénère les clés d'hôte SSH avant le
#         démarrage de ssh.service, dès lors qu'elles ont été supprimées.
#
#     Le rc.local installé ne fait rien tant que /etc/do_first_boot n'existe
#     pas. Ce drapeau est planté juste avant l'export d'un template — par
#     clean_system.sh, ou par ce script avec --arm — et déclenche, au
#     démarrage suivant, la génération d'un nom d'hôte aléatoire et la
#     régénération des clés d'hôte SSH.
#
#     C'est ce mécanisme que clean_system.sh et prepare-ova-export.sh
#     vérifient avant d'accepter de supprimer les clés d'hôte SSH d'un
#     template : sans lui, le clone redémarrerait sans clé et serait
#     inaccessible en SSH. Le script vérifie ce contrat en fin d'exécution et
#     le signale explicitement. Aucun de ces deux scripts n'installe le
#     relais : ils se contentent de l'armer, l'installation est faite ici.
#
#     Idempotent : si /etc/rc.local est déjà identique au fichier du dépôt et
#     que le service est activé, il n'y a rien à faire.
#
# OPTIONS
#     --arm        Plante /etc/do_first_boot : la réinitialisation aura lieu
#                  au prochain démarrage. À utiliser juste avant d'éteindre
#                  une VM destinée au clonage, ou pour tester le mécanisme.
#     --force      Réinstalle rc.local et l'unité systemd même si tout est
#                  déjà en place.
#     -h, --help   Affiche cette aide et quitte.
#
# EXAMPLES
#     sudo ./make_rclocal.sh
#         Installe le relais sur la VM (à faire une fois, à la construction
#         du template).
#
#     sudo ./make_rclocal.sh --arm
#         Installe le relais si besoin, puis arme la réinitialisation pour le
#         prochain démarrage.
#
#     sudo ./make_rclocal.sh --arm && sudo shutdown -h now
#         Séquence type avant clonage ou export d'un template.
#
# FILES
#     /etc/rc.local                            Copie du rc.local du dépôt.
#     /etc/systemd/system/rc-local.service     Unité systemd créée.
#     /etc/systemd/system/ssh-regen-keys.service   Unité systemd créée.
#     /etc/do_first_boot                       Drapeau, avec --arm.
#     /var/log/tp-install/make_rclocal.log     Trace persistante.
#     /var/log/tp-install/first-boot.log       Trace écrite par rc.local au
#                                              démarrage.
#
# EXIT CODES
#     0   Succès, ou installation déjà en place (rien à faire).
#     1   Option inconnue, rc.local introuvable dans le dépôt, systemd absent,
#         ou échec de l'activation du service.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
readonly RC_LOCAL_SRC="${SCRIPT_DIR}/rc.local"
readonly RC_LOCAL_DEST="/etc/rc.local"
readonly SERVICE_NAME="rc-local.service"
readonly SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}"
readonly SSH_UNIT_NAME="ssh-regen-keys.service"
readonly SSH_UNIT_FILE="/etc/systemd/system/${SSH_UNIT_NAME}"
readonly FIRST_BOOT_FLAG="/etc/do_first_boot"

ARM=0
FORCE=0

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

    # Tout ce que produit le script — y compris systemctl — part à l'écran ET
    # dans le fichier, débarrassé des séquences ANSI qui le rendraient illisible
    # dans un éditeur.
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
    --arm)     ARM=1; shift ;;
    --force)   FORCE=1; shift ;;
    -h|--help) sed -n '2,/^# =\{10,\}$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Option inconnue : $1 (voir -h)" ;;
  esac
done

# -----------------------------------------------------------------------------
# Élévation de privilèges (Tier 1 — opérations exclusivement système)
# -----------------------------------------------------------------------------
# L'ancienne version refusait de tourner hors root avec un simple message, ce
# que CLAUDE.md range parmi les motifs interdits : l'utilisateur devait alors
# retaper le chemin complet, sudo n'ayant pas ~/.local/bin dans son secure_path.
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$(readlink -f "$0")" "$@"
fi

# -----------------------------------------------------------------------------
# Vérifications préalables
# -----------------------------------------------------------------------------
check_prerequisites() {
    [ -f "$RC_LOCAL_SRC" ] \
        || die "rc.local introuvable dans $SCRIPT_DIR : le dépôt est incomplet."
    command -v systemctl >/dev/null 2>&1 \
        || die "systemctl introuvable : ce script suppose une machine systemd."
}

# Vrai si le relais est déjà installé à l'identique et activé.
is_already_installed() {
    [ -x "$RC_LOCAL_DEST" ] || return 1
    cmp -s "$RC_LOCAL_SRC" "$RC_LOCAL_DEST" || return 1
    [ -f "$SERVICE_FILE" ] || return 1
    systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null || return 1
    [ -f "$SSH_UNIT_FILE" ] || return 1
    systemctl is-enabled --quiet "$SSH_UNIT_NAME" 2>/dev/null || return 1
}

# -----------------------------------------------------------------------------
# Installation
# -----------------------------------------------------------------------------
install_rc_local() {
    install -m 0755 -o root -g root "$RC_LOCAL_SRC" "$RC_LOCAL_DEST"
    success "$RC_LOCAL_DEST installé (exécutable)."
}

install_service_unit() {
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=/etc/rc.local — réinitialisation au premier démarrage
ConditionFileIsExecutable=${RC_LOCAL_DEST}
After=network.target dbus.service

[Service]
Type=oneshot
# rc.local appelle hostnamectl, qui passe par dbus : la temporisation évite
# une course avec systemd-hostnamed sur les démarrages les plus rapides.
ExecStartPre=/bin/sleep 3
ExecStart=${RC_LOCAL_DEST} start
TimeoutSec=0
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    chown root:root "$SERVICE_FILE"
    chmod 0644 "$SERVICE_FILE"
    success "$SERVICE_FILE créé."

    # daemon-reload avant enable : sans lui, systemd travaille sur sa vue en
    # cache et peut ignorer une unité qui vient d'être réécrite.
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME" >/dev/null 2>&1 \
        || die "Échec de « systemctl enable $SERVICE_NAME »."
    success "$SERVICE_NAME activé au démarrage."
}

# Régénération des clés d'hôte SSH, confiée à une unité dédiée plutôt qu'à
# rc.local seul. La condition « clé ed25519 absente » suffit à l'armer : pas de
# drapeau à poser, et surtout l'ordonnancement Before=ssh.service évite la
# fenêtre où sshd démarre sans clé, échoue, et attend que rc.local le relance.
# rc.local appelle malgré tout ssh-keygen -A, sans effet quand cette unité a
# déjà fait le travail : c'est le filet pour les VM où l'unité manquerait.
install_ssh_regen_unit() {
    # Chemin canonique d'abord, « command -v » seulement en repli : l'unité est
    # écrite une fois pour toutes, il ne faut pas y figer un binaire trouvé en
    # tête d'un PATH inhabituel au moment de l'installation.
    local keygen="/usr/bin/ssh-keygen"
    if [ ! -x "$keygen" ]; then
        keygen="$(command -v ssh-keygen || echo /usr/bin/ssh-keygen)"
    fi

    cat > "$SSH_UNIT_FILE" <<EOF
[Unit]
Description=Régénération des clés d'hôte SSH au premier démarrage
Documentation=man:ssh-keygen(1)
Before=ssh.service sshd.service
ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key

[Service]
Type=oneshot
ExecStart=${keygen} -A
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    chown root:root "$SSH_UNIT_FILE"
    chmod 0644 "$SSH_UNIT_FILE"

    systemctl daemon-reload
    systemctl enable "$SSH_UNIT_NAME" >/dev/null 2>&1 \
        || die "Échec de « systemctl enable $SSH_UNIT_NAME »."
    success "$SSH_UNIT_NAME activé (régénération des clés avant ssh.service)."
}

arm_first_boot() {
    touch "$FIRST_BOOT_FLAG"
    success "Drapeau $FIRST_BOOT_FLAG planté."
    warn "Au prochain démarrage : nouveau nom d'hôte et nouvelles clés d'hôte SSH."
}

# -----------------------------------------------------------------------------
# Vérification du contrat attendu par clean_system.sh
# -----------------------------------------------------------------------------
# Ces trois tests sont exactement ceux de clean_system_rc_local_ready() dans
# clean_system.sh. Les rejouer ici évite de découvrir le problème au moment de
# l'export, quand clean_system.sh refuse de supprimer les clés SSH.
verify_contract() {
    local ok=1

    [ -x "$RC_LOCAL_DEST" ] || ok=0
    grep -q "do_first_boot" "$RC_LOCAL_DEST" 2>/dev/null || ok=0
    systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null || ok=0

    if [ "$ok" -eq 1 ]; then
        success "Contrat attendu par clean_system.sh satisfait."
    else
        die "Le contrat attendu par clean_system.sh n'est PAS satisfait — vérifier $RC_LOCAL_DEST et $SERVICE_NAME."
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}Relais de réinitialisation en place.${RESET}"
    echo ""
    echo "  Script au démarrage : $RC_LOCAL_DEST"
    echo "  Unité hostname      : $SERVICE_FILE"
    echo "  Unité clés SSH      : $SSH_UNIT_FILE"
    echo "  Journal de ce script: $LOG_FILE"
    echo "  Journal du 1er boot : ${LOG_DIR}/first-boot.log"
    echo ""
    if [ "$ARM" -eq 1 ]; then
        echo "  Drapeau planté : $FIRST_BOOT_FLAG"
        echo "  Étape suivante : sudo shutdown -h now, puis clonage / export."
    else
        echo "  Le relais est inerte tant que $FIRST_BOOT_FLAG n'existe pas."
        echo "  Pour armer : sudo ./make_rclocal.sh --arm   (ou clean_system.sh)"
    fi
    echo ""
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    setup_logging "$@"

    echo -e "\n${BOLD}=== Relais de réinitialisation au premier démarrage ===${RESET}\n"

    check_prerequisites

    if is_already_installed && [ "$FORCE" -eq 0 ]; then
        info "rc.local et $SERVICE_NAME sont déjà en place et à jour."
    else
        install_rc_local
        install_service_unit
        install_ssh_regen_unit
    fi

    verify_contract

    if [ "$ARM" -eq 1 ]; then
        arm_first_boot
    fi

    print_summary
}

main "$@"
