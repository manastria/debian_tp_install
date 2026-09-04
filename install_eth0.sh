#!/usr/bin/env bash
# =============================================================================
# NAME
#     install_eth0.sh — Rétablit les noms d'interfaces réseau classiques (eth0)
#
# SYNOPSIS
#     ./install_eth0.sh [--force] [-h|--help]
#
# DESCRIPTION
#     Désactive le nommage prédictible des interfaces réseau (« predictable
#     network interface names » de systemd) sur une machine Debian, afin de
#     retrouver les noms historiques eth0, eth1, … attendus par les sujets de
#     TP.
#
#     Le script ajoute « net.ifnames=0 » et « biosdevname=0 » à la variable
#     GRUB_CMDLINE_LINUX de /etc/default/grub — en conservant les paramètres
#     déjà présents — puis régénère la configuration GRUB avec update-grub. Le
#     renommage ne prend effet qu'au redémarrage suivant.
#
#     Le script ne configure aucune adresse IP et n'installe pas
#     NetworkManager : voir install_network-manager.sh pour cela. Il est
#     idempotent : si les deux paramètres sont déjà présents, il ne modifie
#     rien et sort en succès.
#
# OPTIONS
#     --force      Réécrit /etc/default/grub et régénère GRUB même si les
#                  paramètres sont déjà en place.
#     -h, --help   Affiche cette aide et quitte.
#
# EXAMPLES
#     sudo ./install_eth0.sh
#         Ajoute les paramètres, régénère grub.cfg, puis rappelle qu'un
#         redémarrage est nécessaire.
#
#     sudo ./install_eth0.sh --force
#         Force la réécriture, par exemple après une modification manuelle de
#         /etc/default/grub.
#
# FILES
#     /etc/default/grub                     Fichier modifié.
#     /etc/default/grub.bak-<horodatage>    Sauvegarde, une par exécution.
#     /var/log/tp-install/install_eth0.log  Trace persistante des exécutions.
#
# EXIT CODES
#     0   Succès, ou paramètres déjà en place (rien à faire).
#     1   Option inconnue, /etc/default/grub introuvable, outils GRUB absents,
#         ou échec de la régénération de la configuration GRUB.
# =============================================================================
set -euo pipefail

# -----------------------------------------------------------------------------
# Constantes
# -----------------------------------------------------------------------------
readonly GRUB_FILE="/etc/default/grub"
readonly GRUB_PARAMS=("net.ifnames=0" "biosdevname=0")
readonly TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_FILE="${GRUB_FILE}.bak-${TIMESTAMP}"

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

# Fichier temporaire de write_cmdline, supprimé par cleanup. CLAUDE.md impose un
# seul trap EXIT par script : il est mutualisé avec la restauration des
# descripteurs plutôt que doublé.
_TMP_FILE=""

setup_logging() {
    install -d -m 0750 -o root -g adm "$LOG_DIR"
    [ -e "$LOG_FILE" ] || install -m 0640 -o root -g adm /dev/null "$LOG_FILE"

    # Sauvegarde des descripteurs d'origine, pour les restaurer en fin de script.
    exec 3>&1 4>&2

    # Tout ce que produit le script — y compris update-grub — part à l'écran ET
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
    # Bloc "if" plutôt que "[ … ] && rm" : sous set -e, un test faux en fin de
    # liste ferait remonter un statut non nul depuis le gestionnaire de trap.
    if [ -n "$_TMP_FILE" ]; then
        rm -f "$_TMP_FILE"
    fi
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
    [ -f "$GRUB_FILE" ] \
        || die "$GRUB_FILE introuvable : cette machine ne démarre pas via GRUB."

    if ! command -v update-grub >/dev/null 2>&1 \
        && ! command -v grub-mkconfig >/dev/null 2>&1; then
        die "Ni update-grub ni grub-mkconfig disponibles : impossible de régénérer GRUB."
    fi
}

show_current_interfaces() {
    if command -v ip >/dev/null 2>&1; then
        local names
        names="$(ip -br link show 2>/dev/null | awk '$1 != "lo" { printf "%s ", $1 }')"
        if [ -n "$names" ]; then
            info "Interfaces actuelles : ${names% }"
        fi
    fi
}

# -----------------------------------------------------------------------------
# Lecture et calcul de la ligne de commande noyau
# -----------------------------------------------------------------------------
# /etc/default/grub est un fragment shell : c'est ainsi que grub-mkconfig le lit.
# Le sourcer dans un sous-shell donne la valeur réelle de GRUB_CMDLINE_LINUX,
# guillemets et échappements résolus, plutôt que de réimplémenter un parseur à
# coups de sed.
read_current_cmdline() {
    (
        set +u
        . "$GRUB_FILE" >/dev/null 2>&1 || true
        printf '%s' "${GRUB_CMDLINE_LINUX:-}"
    )
}

build_new_cmdline() {
    local new="$1"
    local param
    for param in "${GRUB_PARAMS[@]}"; do
        # Comparaison encadrée d'espaces : « net.ifnames=0 » ne doit pas être vu
        # comme déjà présent parce que la ligne contient « xxx.net.ifnames=01 ».
        case " $new " in
            *" $param "*) continue ;;
        esac
        new="${new:+$new }$param"
    done
    printf '%s' "$new"
}

# -----------------------------------------------------------------------------
# Modification de /etc/default/grub
# -----------------------------------------------------------------------------
backup_grub() {
    cp -a "$GRUB_FILE" "$BACKUP_FILE"
    success "Sauvegarde : $BACKUP_FILE"
}

write_cmdline() {
    local new_cmdline="$1"

    _TMP_FILE="$(mktemp)"

    # Le motif exige le « = » juste après le nom : GRUB_CMDLINE_LINUX_DEFAULT,
    # qui commence par la même chaîne, ne doit surtout pas être touché.
    if grep -qE '^[[:space:]]*GRUB_CMDLINE_LINUX=' "$GRUB_FILE"; then
        # La valeur est passée par l'environnement, pas par « awk -v » : awk
        # interprète les échappements d'une affectation -v, ce qui abîmerait un
        # paramètre contenant une contre-oblique.
        repl="GRUB_CMDLINE_LINUX=\"${new_cmdline}\"" awk '
            /^[[:space:]]*GRUB_CMDLINE_LINUX=/ {
                # Seule la première affectation est remplacée ; les éventuelles
                # suivantes sont supprimées, car le fichier étant sourcé de haut
                # en bas, elles écraseraient la valeur qu on vient d écrire.
                if (!seen) { print ENVIRON["repl"]; seen = 1 }
                next
            }
            { print }
        ' "$GRUB_FILE" > "$_TMP_FILE"
    else
        cat "$GRUB_FILE" > "$_TMP_FILE"
        {
            echo ""
            echo "# Ajouté par install_eth0.sh — noms d'interfaces classiques (eth0, eth1, …)"
            printf 'GRUB_CMDLINE_LINUX="%s"\n' "$new_cmdline"
        } >> "$_TMP_FILE"
    fi

    install -m 0644 -o root -g root "$_TMP_FILE" "$GRUB_FILE"
    rm -f "$_TMP_FILE"
    _TMP_FILE=""

    success "GRUB_CMDLINE_LINUX = \"${new_cmdline}\""
}

regenerate_grub() {
    info "Régénération de la configuration GRUB..."
    if command -v update-grub >/dev/null 2>&1; then
        # update-grub est le wrapper Debian : il connaît le bon chemin de sortie
        # (BIOS comme UEFI), inutile de le deviner à sa place.
        update-grub || die "Échec de update-grub — /etc/default/grub reste modifié, restaurez $BACKUP_FILE si besoin."
    else
        grub-mkconfig -o /boot/grub/grub.cfg \
            || die "Échec de grub-mkconfig — restaurez $BACKUP_FILE si besoin."
    fi
    success "Configuration GRUB régénérée."
}

# -----------------------------------------------------------------------------
# Avertissements post-modification
# -----------------------------------------------------------------------------
check_config_references() {
    local -a files=("/etc/network/interfaces")
    local -a hits=()
    local f

    shopt -s nullglob
    files+=(/etc/network/interfaces.d/*)
    shopt -u nullglob

    for f in "${files[@]}"; do
        [ -f "$f" ] || continue
        # Noms « prédictibles » (enp0s3, ens33, eno1, enx00…) : ce sont eux qui
        # disparaîtront au prochain démarrage au profit de eth0, eth1, …
        if grep -qE '(^|[^a-z0-9])(en[pos][0-9a-z]+|enx[0-9a-f]+)([^a-z0-9]|$)' "$f"; then
            hits+=("$f")
        fi
    done

    if [ ${#hits[@]} -gt 0 ]; then
        warn "Ces fichiers désignent des interfaces qui n'existeront plus après redémarrage :"
        for f in "${hits[@]}"; do
            warn "    - $f"
        done
        warn "Adaptez-les (eth0, eth1, …) avant de redémarrer, sous peine de démarrer sans réseau."
    fi
}

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}Noms d'interfaces classiques configurés.${RESET}"
    echo ""
    echo "  Sauvegarde   : $BACKUP_FILE"
    echo "  Journal      : $LOG_FILE"
    echo ""
    echo "  Restauration : sudo cp -a $BACKUP_FILE $GRUB_FILE && sudo update-grub"
    echo ""
    warn "Le renommage en eth0 ne prend effet qu'au prochain redémarrage."
}

# -----------------------------------------------------------------------------
# Point d'entrée
# -----------------------------------------------------------------------------
main() {
    setup_logging "$@"

    echo -e "\n${BOLD}=== Noms d'interfaces réseau classiques (eth0) ===${RESET}\n"

    check_prerequisites
    show_current_interfaces

    local current new
    current="$(read_current_cmdline)"
    new="$(build_new_cmdline "$current")"

    if [ "$new" = "$current" ] && [ "$FORCE" -eq 0 ]; then
        success "net.ifnames=0 et biosdevname=0 sont déjà dans GRUB_CMDLINE_LINUX."
        info "Rien à faire. Utilisez --force pour réécrire et régénérer GRUB malgré tout."
        exit 0
    fi

    info "Ancienne valeur : GRUB_CMDLINE_LINUX=\"${current}\""
    backup_grub
    write_cmdline "$new"
    regenerate_grub
    check_config_references
    print_summary
}

main "$@"
