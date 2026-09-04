#!/usr/bin/env bash
# =============================================================================
# NAME
#     install_network-manager.sh — Confie le réseau Debian à NetworkManager
#
# SYNOPSIS
#     ./install_network-manager.sh [--force] [-y|--yes] [-h|--help]
#
# DESCRIPTION
#     Installe NetworkManager sur une machine Debian et lui confie la gestion
#     des interfaces réseau, jusque-là pilotées par ifupdown via
#     /etc/network/interfaces.
#
#     Le script installe le paquet network-manager, sauvegarde puis réduit
#     /etc/network/interfaces au seul loopback, dépose
#     /etc/NetworkManager/conf.d/99-tp-ifupdown-managed.conf contenant
#     « managed=true », et redémarre NetworkManager. Les interfaces sont
#     ensuite pilotées par nmcli / nmtui.
#
#     Ce script cible Debian et ifupdown. Sur une machine Ubuntu/XUbuntu
#     basée sur netplan, c'est switch-to-networkmanager.sh qu'il faut
#     utiliser : la présence de netplan interrompt ici l'exécution, sauf
#     --force. Il ne renomme pas les interfaces en eth0 — voir
#     install_eth0.sh pour cela. Idempotent : si NetworkManager est déjà
#     installé, actif et maître des interfaces, le script ne touche à rien.
#
# OPTIONS
#     --force      Réapplique toute la configuration même si elle est déjà en
#                  place, et passe outre la détection de netplan.
#     -y, --yes    Ne pose aucune question : utile pour un enchaînement non
#                  interactif (voir tp_cli.sh) ou une session SSH assumée.
#     -h, --help   Affiche cette aide et quitte.
#
# EXAMPLES
#     sudo ./install_network-manager.sh
#         Installation et bascule complète, depuis la console de la VM.
#
#     sudo ./install_network-manager.sh --yes
#         Idem sans confirmation, même si la session est distante (SSH).
#
#     sudo ./install_network-manager.sh --force
#         Réécrit la configuration d'une machine déjà basculée.
#
# FILES
#     /etc/network/interfaces                    Réduit au loopback.
#     /etc/network/interfaces.bak-<horodatage>   Sauvegarde, une par exécution.
#     /etc/NetworkManager/conf.d/99-tp-ifupdown-managed.conf   Déposé.
#     /var/log/tp-install/install_network-manager.log          Trace.
#
# EXIT CODES
#     0   Succès, ou configuration déjà en place (rien à faire).
#     1   Option inconnue, netplan détecté sans --force, refus à la
#         confirmation, échec de l'installation du paquet ou du redémarrage
#         de NetworkManager.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly PACKAGE="network-manager"
readonly INTERFACES_FILE="/etc/network/interfaces"
readonly INTERFACES_DIR="/etc/network/interfaces.d"
readonly NM_CONF_FILE="/etc/NetworkManager/NetworkManager.conf"
readonly NM_CONF_DIR="/etc/NetworkManager/conf.d"
readonly NM_SNIPPET="${NM_CONF_DIR}/99-tp-ifupdown-managed.conf"
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_FILE="${INTERFACES_FILE}.bak-${TIMESTAMP}"

FORCE=0
ASSUME_YES=0
BACKUP_DONE=0

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

    # Tout ce que produit le script — y compris apt et systemctl — part à l'écran
    # ET dans le fichier, débarrassé des séquences ANSI qui le rendraient
    # illisible dans un éditeur.
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
    --force)   FORCE=1; shift ;;
    -y|--yes)  ASSUME_YES=1; shift ;;
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

    # Garde-fou : sur une machine netplan, vider /etc/network/interfaces ne
    # change rien (netplan pilote le réseau) et la bascule doit se faire au
    # niveau du renderer, ce que fait switch-to-networkmanager.sh.
    if command -v netplan >/dev/null 2>&1; then
        warn "netplan est installé sur cette machine."
        warn "Ce script cible Debian/ifupdown ; sur Ubuntu/XUbuntu, utilisez plutôt"
        warn "    ./switch-to-networkmanager.sh"
        if [ "$FORCE" -eq 0 ]; then
            die "Interrompu. Relancez avec --force pour passer outre."
        fi
        warn "--force : exécution poursuivie malgré netplan."
    fi
}

# Liste les interfaces encore déclarées dans ifupdown, loopback exclu. Les
# commentaires sont ignorés ; interfaces.d est inspecté au même titre que le
# fichier principal, puisque ce dernier le source.
list_ifupdown_interfaces() {
    local -a files=("$INTERFACES_FILE")

    shopt -s nullglob
    files+=("$INTERFACES_DIR"/*)
    shopt -u nullglob

    # Bloc "if" plutôt que "[ -f … ] && existing+=…" : sous set -e, un test faux
    # sur le dernier fichier de la liste ferait sortir la fonction avant l'awk,
    # donc renvoyer une liste vide — soit exactement le contraire du vrai.
    local -a existing=()
    local f
    for f in "${files[@]}"; do
        if [ -f "$f" ]; then
            existing+=("$f")
        fi
    done
    [ ${#existing[@]} -gt 0 ] || return 0

    awk '
        /^[[:space:]]*#/ { next }
        $1 == "iface" && $2 != "lo" { print $2 }
        $1 == "auto" || $1 == "allow-hotplug" {
            for (i = 2; i <= NF; i++) if ($i != "lo") print $i
        }
    ' "${existing[@]}" | sort -u
}

# Vrai seulement si les quatre conditions de la bascule sont déjà réunies.
is_already_configured() {
    dpkg -s "$PACKAGE" >/dev/null 2>&1 || return 1
    systemctl is-active --quiet NetworkManager.service || return 1
    [ -f "$NM_SNIPPET" ] || return 1
    grep -qE '^[[:space:]]*managed[[:space:]]*=[[:space:]]*true' "$NM_SNIPPET" || return 1
    [ -z "$(list_ifupdown_interfaces)" ] || return 1
}

confirm_if_ssh() {
    if [ -z "${SSH_CONNECTION:-}" ] && [ -z "${SSH_CLIENT:-}" ]; then
        return 0
    fi

    warn "Session SSH détectée : la bascule coupe puis reconfigure l'interface."
    warn "Préférez la console de la VM, ou un screen/tmux."

    if [ "$ASSUME_YES" -eq 1 ]; then
        warn "--yes : exécution poursuivie sans confirmation."
        return 0
    fi
    if [ ! -t 0 ]; then
        die "Aucun terminal pour confirmer. Relancez avec --yes si le risque est accepté."
    fi

    local answer
    read -r -p "$(echo -e "${YELLOW}Continuer malgré tout ?${RESET} [o/N] ")" answer
    case "${answer,,}" in
        o|oui|y|yes) ;;
        *) die "Annulé par l'utilisateur." ;;
    esac
}

# -----------------------------------------------------------------------------
# Installation du paquet
# -----------------------------------------------------------------------------
install_network_manager() {
    if dpkg -s "$PACKAGE" >/dev/null 2>&1; then
        local version
        version="$(dpkg -s "$PACKAGE" | awk '/^Version:/ { print $2 }')"
        info "$PACKAGE déjà installé (version $version)."
        return 0
    fi

    info "Installation de $PACKAGE..."
    apt-get update -q || die "Échec de « apt-get update »."
    # Recommandations conservées (contrairement à switch-to-networkmanager.sh) :
    # wpasupplicant et ppp en font partie, et leur absence se paie au moment où
    # la VM sert de poste client Wi-Fi ou de routeur en TP.
    apt-get install -y "$PACKAGE" || die "Échec de l'installation de $PACKAGE."
    success "$PACKAGE installé."
}

# -----------------------------------------------------------------------------
# Passage d'ifupdown à NetworkManager
# -----------------------------------------------------------------------------
reset_interfaces_file() {
    local -a managed=()
    mapfile -t managed < <(list_ifupdown_interfaces)

    if [ -f "$INTERFACES_FILE" ]; then
        cp -a "$INTERFACES_FILE" "$BACKUP_FILE"
        BACKUP_DONE=1
        success "Sauvegarde : $BACKUP_FILE"
        if [ ${#managed[@]} -gt 0 ]; then
            info "Interfaces retirées d'ifupdown : ${managed[*]}"
        else
            info "Aucune interface hors loopback n'était déclarée dans ifupdown."
        fi
    else
        warn "$INTERFACES_FILE absent : création d'un fichier réduit au loopback."
    fi

    cat > "$INTERFACES_FILE" <<'EOF'
# Interfaces réseau gérées par ifupdown — voir interfaces(5).
#
# Fichier réduit au loopback par install_network-manager.sh : toutes les autres
# interfaces sont désormais pilotées par NetworkManager (nmcli, nmtui).

source /etc/network/interfaces.d/*

# Interface de bouclage
auto lo
iface lo inet loopback
EOF
    chown root:root "$INTERFACES_FILE"
    chmod 0644 "$INTERFACES_FILE"
    success "$INTERFACES_FILE réduit au loopback."

    # Le fichier principal continue de sourcer interfaces.d : un fragment oublié
    # là redonnerait la main à ifupdown sur l'interface concernée.
    shopt -s nullglob
    local -a extra=("$INTERFACES_DIR"/*)
    shopt -u nullglob
    if [ ${#extra[@]} -gt 0 ]; then
        warn "$INTERFACES_DIR n'est pas vide et reste sourcé par $INTERFACES_FILE :"
        local f
        for f in "${extra[@]}"; do
            warn "    - $f"
        done
    fi
}

configure_nm_snippet() {
    install -d -m 0755 "$NM_CONF_DIR"
    cat > "$NM_SNIPPET" <<'EOF'
# Déposé par install_network-manager.sh — ne pas éditer à la main.
#
# Debian livre « [ifupdown] managed=false » dans NetworkManager.conf : avec ce
# réglage, NetworkManager laisse de côté toute interface déclarée dans
# /etc/network/interfaces. Le réglage est inversé ici, dans conf.d, plutôt que
# par réécriture du fichier de la distribution : les fichiers de conf.d le
# surchargent et survivent aux mises à jour du paquet network-manager.
[ifupdown]
managed=true
EOF
    chown root:root "$NM_SNIPPET"
    chmod 0644 "$NM_SNIPPET"
    success "Greffon ifupdown en mode « managed » ($NM_SNIPPET)."
}

check_ifupdown_plugin() {
    if [ -f "$NM_CONF_FILE" ] \
        && grep -qE '^[[:space:]]*plugins[[:space:]]*=.*ifupdown' "$NM_CONF_FILE"; then
        info "Greffon ifupdown actif dans $NM_CONF_FILE."
        return 0
    fi

    # Sans le greffon dans la liste « plugins », le managed=true déposé ci-dessus
    # n'est jamais lu. Non bloquant : Debian l'active par défaut, et NM retombe
    # sur une liste compilée quand la clé est absente du fichier.
    warn "La ligne « plugins » de $NM_CONF_FILE ne mentionne pas ifupdown."
    warn "Si les interfaces restent non gérées, ajoutez-y :"
    warn "    [main]"
    warn "    plugins=ifupdown,keyfile"
}

restart_network_manager() {
    info "Activation et redémarrage de NetworkManager..."
    systemctl enable NetworkManager.service >/dev/null 2>&1 \
        || warn "Impossible d'activer NetworkManager au démarrage."
    systemctl restart NetworkManager.service \
        || die "Échec du redémarrage (voir « systemctl status NetworkManager »)."

    # NM a besoin de quelques secondes pour reprendre la main sur les interfaces
    # libérées par ifupdown et pour terminer son DHCP.
    sleep 3

    if command -v nmcli >/dev/null 2>&1; then
        local state
        state="$(nmcli -t -f STATE general status 2>/dev/null || true)"
        if [ -n "$state" ]; then
            success "État de NetworkManager : $state"
        else
            warn "nmcli ne répond pas encore — initialisation sans doute en cours."
        fi
        info "Périphériques vus par NetworkManager :"
        nmcli device status 2>/dev/null || true
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}Réseau confié à NetworkManager.${RESET}"
    echo ""
    if [ "$BACKUP_DONE" -eq 1 ]; then
        echo "  Sauvegarde   : $BACKUP_FILE"
    else
        echo "  Sauvegarde   : aucune ($INTERFACES_FILE n'existait pas)"
    fi
    echo "  Greffon      : $NM_SNIPPET"
    echo "  Journal      : $LOG_FILE"
    echo ""
    echo "  Piloter le réseau : nmtui  (ou nmcli device status)"
    echo ""
    echo "  Restauration :"
    if [ "$BACKUP_DONE" -eq 1 ]; then
        echo "      sudo cp -a $BACKUP_FILE $INTERFACES_FILE"
    fi
    echo "      sudo rm -f $NM_SNIPPET"
    echo "      sudo systemctl restart NetworkManager networking"
    echo ""
    warn "Un redémarrage est conseillé pour repartir d'un état propre."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    setup_logging "$@"

    echo -e "\n${BOLD}=== Bascule du réseau vers NetworkManager (Debian) ===${RESET}\n"

    check_prerequisites

    if is_already_configured && [ "$FORCE" -eq 0 ]; then
        success "NetworkManager est déjà installé, actif et maître des interfaces."
        info "Rien à faire. Utilisez --force pour tout réappliquer."
        exit 0
    fi

    # La confirmation vient avant l'installation : un refus doit laisser la
    # machine strictement dans l'état où on l'a trouvée.
    confirm_if_ssh
    install_network_manager
    reset_interfaces_file
    configure_nm_snippet
    check_ifupdown_plugin
    restart_network_manager
    print_summary
}

main "$@"
