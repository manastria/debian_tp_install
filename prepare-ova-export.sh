#!/usr/bin/env bash
#===============================================================================
#
#  prepare-ova-export.sh
#
#  Prépare une VM Debian/Ubuntu pour export en .ova (labo étudiant)
#
#  Actions :
#    - Nettoyage des caches APT, journaux, fichiers temporaires
#    - Purge des historiques bash/zsh de tous les utilisateurs
#    - Armement du relais de réinitialisation au premier démarrage
#      (hostname vm-XXXXXXXX + clés d'hôte SSH)
#    - Remplissage de zéro (zerofill) pour optimiser la compression OVA
#
#  Le mécanisme de réinitialisation n'est PAS embarqué ici : ce script arme le
#  relais partagé du dépôt (/etc/rc.local + rc-local.service +
#  ssh-regen-keys.service), le même que celui vérifié par clean_system.sh.
#  Si le relais manque, il tente de l'installer via make_rclocal.sh situé à
#  côté de ce script ; à défaut, il CONSERVE les clés SSH plutôt que de rendre
#  le clone inaccessible.
#
#  Usage :
#    Méthode recommandée (aucune trace dans l'historique) :
#      $ sudo -i
#      # source /chemin/vers/prepare-ova-export.sh [OPTIONS]
#      (la VM s'éteint automatiquement)
#
#    Méthode classique (rapide, trace minime) :
#      $ sudo ./prepare-ova-export.sh [OPTIONS]
#
#  Options :
#    --no-ssh-regen      Ne pas régénérer les clés SSH au redémarrage
#    --no-random-hostname Ne pas générer de hostname aléatoire au boot
#    --no-zerofill       Ne pas remplir le disque de zéros (plus rapide)
#    --dry-run           Afficher les actions sans les exécuter
#    -h, --help          Afficher l'aide
#
#===============================================================================

set -euo pipefail

# ── Détection : sourcé ou exécuté ? ──────────────────────────────────────────
# Si sourcé (source script.sh), on peut faire unset HISTFILE à la fin
# pour ne laisser aucune trace dans l'historique du shell parent.
SOURCED=false
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    SOURCED=true
fi

# Répertoire du dépôt, résolu depuis BASH_SOURCE et non depuis $0 : ce script
# est prévu pour être sourcé, cas où $0 vaut le nom du shell appelant.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# ── Couleurs ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Options par défaut ────────────────────────────────────────────────────────
SSH_REGEN=true
RANDOM_HOSTNAME=true
ZEROFILL=true
DRY_RUN=false

# ── Parsing des arguments ─────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-ssh-regen)      SSH_REGEN=false ;;
        --no-random-hostname) RANDOM_HOSTNAME=false ;;
        --no-zerofill)       ZEROFILL=false ;;
        --dry-run)           DRY_RUN=true ;;
        -h|--help)
            # « # \{0,2\} » et non « #  \? » : une ligne réduite à « # » est
            # ainsi imprimée comme ligne vide, ce qui restitue les paragraphes.
            sed -n '3,/^#=====/{ /^#=====/d; s/^# \{0,2\}//p }' "$0"
            exit 0
            ;;
        *) echo -e "${RED}Option inconnue : $1${NC}"; exit 1 ;;
    esac
    shift
done

# ── Fonctions utilitaires ─────────────────────────────────────────────────────
log_section() { echo -e "\n${BLUE}${BOLD}══════════════════════════════════════════════${NC}"; echo -e "${BLUE}${BOLD}  $1${NC}"; echo -e "${BLUE}${BOLD}══════════════════════════════════════════════${NC}"; }
log_step()    { echo -e "  ${CYAN}▶${NC} $1"; }
log_ok()      { echo -e "  ${GREEN}✔${NC} $1"; }
log_warn()    { echo -e "  ${YELLOW}⚠${NC} $1"; }
log_skip()    { echo -e "  ${YELLOW}⏭${NC} $1 (dry-run)"; }

run() {
    if $DRY_RUN; then
        log_skip "$1"
    else
        log_step "$1"
        shift
        eval "$@"
        log_ok "OK"
    fi
}

# ── Relais de réinitialisation au premier démarrage ───────────────────────────
# Mêmes tests que clean_system_rc_local_ready() dans clean_system.sh : le relais
# est prêt si rc.local est exécutable, contient le drapeau, et que son unité est
# activée. Garder les deux vérifications identiques est délibéré — c'est le
# contrat du mécanisme partagé.
first_boot_relay_ready() {
    [[ -x /etc/rc.local ]] || return 1
    grep -q "do_first_boot" /etc/rc.local 2>/dev/null || return 1
    systemctl is-enabled --quiet rc-local.service 2>/dev/null || return 1
    return 0
}

# Installe le relais s'il manque, en déléguant à make_rclocal.sh trouvé à côté
# de ce script. Renvoie 1 si le relais reste indisponible : l'appelant décide
# alors de ne PAS supprimer les clés SSH.
ensure_first_boot_relay() {
    if first_boot_relay_ready; then
        log_ok "Relais de réinitialisation déjà en place"
        return 0
    fi

    local installer="${SCRIPT_DIR}/make_rclocal.sh"
    if [[ -x "$installer" ]]; then
        log_step "Relais absent — installation via make_rclocal.sh"
        "$installer" || true
        if first_boot_relay_ready; then
            log_ok "Relais installé"
            return 0
        fi
    fi

    log_warn "Relais de réinitialisation indisponible (make_rclocal.sh introuvable ?)"
    return 1
}

# Les versions antérieures de ce script posaient leur propre mécanisme :
# random-hostname.service, /usr/local/bin/set-random-hostname.sh, sentinelle
# /etc/hostname-initialized, hostname au format labo-XXXX. Le laisser en place
# ferait cohabiter deux générateurs de hostname au premier démarrage, dans un
# ordre non garanti — d'où ce retrait, exécuté avant l'armement du relais.
remove_legacy_hostname_mechanism() {
    local found=false
    if [[ -f /etc/systemd/system/random-hostname.service ]]; then
        found=true
    fi
    if [[ -f /usr/local/bin/set-random-hostname.sh ]]; then
        found=true
    fi
    if ! $found; then
        return 0
    fi

    if $DRY_RUN; then
        log_skip "Retrait de l'ancien mécanisme random-hostname.service"
        return 0
    fi

    log_step "Retrait de l'ancien mécanisme random-hostname.service"
    systemctl disable random-hostname.service &>/dev/null || true
    rm -f /etc/systemd/system/random-hostname.service
    rm -f /usr/local/bin/set-random-hostname.sh
    rm -f /etc/hostname-initialized
    systemctl daemon-reload &>/dev/null || true
    log_ok "Ancien mécanisme retiré"
}

# ── Vérifications ─────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Ce script doit être exécuté en root (sudo).${NC}"
    # 'return' si sourcé (ne tue pas le shell), 'exit' sinon
    $SOURCED && return 1 || exit 1
fi

if ! grep -qiE 'debian|ubuntu' /etc/os-release 2>/dev/null; then
    echo -e "${YELLOW}⚠ Système non Debian/Ubuntu détecté. Le script peut ne pas fonctionner correctement.${NC}"
    read -rp "Continuer quand même ? [y/N] " confirm
    [[ "$confirm" =~ ^[yYoO]$ ]] || exit 0
fi

echo -e "${BOLD}"
echo '  ╔═══════════════════════════════════════════════════╗'
echo '  ║   Préparation VM pour export OVA (labo étudiant) ║'
echo '  ╚═══════════════════════════════════════════════════╝'
echo -e "${NC}"
echo -e "  SSH regen ......... $(${SSH_REGEN} && echo -e "${GREEN}oui${NC}" || echo -e "${YELLOW}non${NC}")"
echo -e "  Random hostname ... $(${RANDOM_HOSTNAME} && echo -e "${GREEN}oui${NC}" || echo -e "${YELLOW}non${NC}")"
echo -e "  Zerofill .......... $(${ZEROFILL} && echo -e "${GREEN}oui${NC}" || echo -e "${YELLOW}non${NC}")"
echo -e "  Dry-run ........... $(${DRY_RUN} && echo -e "${YELLOW}oui${NC}" || echo -e "${GREEN}non${NC}")"
echo

if ! $DRY_RUN; then
    echo -e "${RED}${BOLD}⚠ ATTENTION : Ce script va nettoyer irréversiblement la VM.${NC}"
    echo -e "${RED}  La VM va s'éteindre à la fin du processus.${NC}"
    read -rp "  Confirmer l'exécution ? [y/N] " confirm
    [[ "$confirm" =~ ^[yYoO]$ ]] || { echo "Annulé."; exit 0; }
fi

#===============================================================================
#  1. NETTOYAGE APT
#===============================================================================
log_section "1/6 — Nettoyage APT"

run "Suppression des paquets orphelins" \
    "apt-get -y autoremove --purge 2>/dev/null || true"

run "Nettoyage du cache APT" \
    "apt-get -y clean && apt-get -y autoclean"

run "Suppression des listes APT" \
    "rm -rf /var/lib/apt/lists/*"

run "Suppression des fichiers .deb en cache" \
    "find /var/cache/apt/archives -name '*.deb' -delete 2>/dev/null || true"

#===============================================================================
#  2. NETTOYAGE DES JOURNAUX ET FICHIERS TEMPORAIRES
#===============================================================================
log_section "2/6 — Journaux et fichiers temporaires"

run "Arrêt de rsyslog (évite la recréation de logs pendant le nettoyage)" \
    "systemctl is-active --quiet rsyslog && systemctl stop rsyslog || true"

run "Rotation et nettoyage des journaux systemd" \
    "journalctl --rotate 2>/dev/null || true; journalctl --vacuum-time=1s 2>/dev/null || true"

run "Troncature des fichiers de log" '
    find /var/log -type f \( -name "*.log" -o -name "*.gz" -o -name "*.xz" \
        -o -name "*.old" -o -name "*.1" -o -name "*.2" \) -delete 2>/dev/null || true
    find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null || true
    # Fichiers spéciaux : tronquer plutôt que supprimer (certains services en dépendent)
    for f in /var/log/btmp /var/log/wtmp /var/log/lastlog /var/log/dmesg; do
        [[ -f "$f" ]] && truncate -s 0 "$f"
    done
    rm -rf /var/log/apt/* 2>/dev/null || true
'

run "Nettoyage de /tmp et /var/tmp" \
    "rm -rf /tmp/* /tmp/.* /var/tmp/* /var/tmp/.* 2>/dev/null || true"

run "Suppression du cache thumbnails et caches utilisateurs" '
    find /home /root -type d -name ".cache" -exec rm -rf {} + 2>/dev/null || true
    find /home /root -type d -name ".thumbnails" -exec rm -rf {} + 2>/dev/null || true
    find /home /root -name ".wget-hsts" -delete 2>/dev/null || true
    find /home /root -name ".lesshst" -delete 2>/dev/null || true
    find /home /root -name ".viminfo" -delete 2>/dev/null || true
    find /home /root -name ".python_history" -delete 2>/dev/null || true
    find /home /root -name ".sudo_as_admin_successful" -delete 2>/dev/null || true
'

run "Suppression du cache man-db" \
    "rm -rf /var/cache/man/* 2>/dev/null || true"

run "Suppression des fichiers core dump" \
    "find / -xdev -name 'core' -o -name 'core.*' -delete 2>/dev/null || true"

#===============================================================================
#  3. PURGE DES HISTORIQUES SHELL (tous les utilisateurs)
#===============================================================================
log_section "3/6 — Historiques shell"

run "Purge des historiques bash et zsh (tous les utilisateurs)" '
    # Root
    for f in /root/.bash_history /root/.zsh_history /root/.history; do
        rm -f "$f" 2>/dev/null || true
    done
    cat /dev/null > /root/.bash_history 2>/dev/null || true

    # Chaque utilisateur avec un home
    while IFS=: read -r _ _ uid _ _ home _; do
        [[ -d "$home" ]] || continue
        for f in "$home/.bash_history" "$home/.zsh_history" "$home/.history"; do
            rm -f "$f" 2>/dev/null || true
        done
    done < /etc/passwd

    # Purger aussi la session courante
    history -c 2>/dev/null || true
    export HISTSIZE=0
'

#===============================================================================
#  4. NETTOYAGE RÉSEAU (machine-id, DHCP leases)
#===============================================================================
log_section "4/6 — Identifiants réseau"

run "Troncature de /etc/machine-id (sera regénéré au boot)" \
    "truncate -s 0 /etc/machine-id && rm -f /var/lib/dbus/machine-id 2>/dev/null || true"

run "Suppression des baux DHCP" \
    "rm -f /var/lib/dhcp/*.leases /var/lib/NetworkManager/*.lease 2>/dev/null || true"

run "Suppression des règles udev persistantes (interfaces réseau)" \
    "rm -f /etc/udev/rules.d/70-persistent-net.rules 2>/dev/null || true"

run "Nettoyage cloud-init (si installé)" \
    "command -v cloud-init &>/dev/null && cloud-init clean --logs --seed 2>/dev/null || true"

#===============================================================================
#  5. RÉINITIALISATION AU PREMIER DÉMARRAGE (relais partagé)
#===============================================================================
log_section "5/6 — Réinitialisation au premier démarrage"

# Ce script n'embarque plus son propre mécanisme : il arme celui que pose
# make_rclocal.sh, et que clean_system.sh vérifie. Deux mécanismes concurrents
# sur la même VM réécriraient le hostname deux fois au premier démarrage.
remove_legacy_hostname_mechanism

RELAY_OK=false
if $DRY_RUN; then
    if first_boot_relay_ready; then
        log_ok "Relais de réinitialisation déjà en place"
    else
        log_skip "Installation du relais via make_rclocal.sh"
    fi
    # En dry-run, on montre la suite comme si le relais était disponible :
    # l'intérêt du mode est justement d'afficher toutes les actions prévues.
    RELAY_OK=true
elif ensure_first_boot_relay; then
    RELAY_OK=true
fi

# ── Clés d'hôte SSH ──────────────────────────────────────────────────────────
# Elles ne sont supprimées que si leur régénération est garantie. Sans le
# relais, un clone démarrerait sans clé d'hôte, donc inaccessible en SSH :
# mieux vaut un template avec des clés partagées qu'un template injoignable.
if $SSH_REGEN; then
    if $RELAY_OK; then
        run "Suppression des clés d'hôte SSH (régénérées par ssh-regen-keys.service)" \
            "rm -f /etc/ssh/ssh_host_*"
    else
        log_warn "Clés d'hôte SSH CONSERVÉES : aucune régénération garantie."
        log_warn "  -> lancez make_rclocal.sh sur cette VM, puis relancez ce script."
    fi
else
    log_warn "Régénération SSH désactivée (--no-ssh-regen)"
fi

# ── Hostname aléatoire ───────────────────────────────────────────────────────
# Le drapeau est le seul déclencheur : rc.local le consomme au démarrage
# suivant, génère vm-XXXXXXXX, met /etc/hosts à jour, puis le supprime.
if $RANDOM_HOSTNAME; then
    if $RELAY_OK; then
        run "Armement de /etc/do_first_boot (hostname vm-XXXXXXXX au prochain démarrage)" \
            "touch /etc/do_first_boot"
    else
        log_warn "Hostname aléatoire impossible : relais indisponible."
    fi
else
    log_warn "Hostname aléatoire désactivé (--no-random-hostname)"
fi

#===============================================================================
#  6. ZEROFILL — Remplissage de zéros pour compression optimale
#===============================================================================
log_section "6/6 — Zerofill (optimisation compression)"

if $ZEROFILL; then
    if ! $DRY_RUN; then
        log_step "Vidage des buffers disque (sync)"
        sync

        log_step "Remplissage de l'espace libre avec des zéros..."
        echo -e "  ${YELLOW}  (cela peut prendre plusieurs minutes)${NC}"

        # On utilise dd car il est toujours disponible
        dd if=/dev/zero of=/var/tmp/zerofill bs=1M 2>/dev/null || true
        rm -f /var/tmp/zerofill

        # Même chose pour /tmp si partition séparée
        dd if=/dev/zero of=/tmp/zerofill bs=1M 2>/dev/null || true
        rm -f /tmp/zerofill

        # Même chose pour /boot si partition séparée
        dd if=/dev/zero of=/boot/zerofill bs=1M 2>/dev/null || true
        rm -f /boot/zerofill

        sync
        log_ok "Zerofill terminé"
    else
        log_skip "Zerofill"
    fi
else
    log_warn "Zerofill désactivé (--no-zerofill)"
fi

#===============================================================================
#  RÉSUMÉ FINAL
#===============================================================================
echo
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════${NC}"
echo -e "${GREEN}${BOLD}  ✔ Préparation terminée !${NC}"
echo -e "${GREEN}${BOLD}══════════════════════════════════════════════${NC}"
echo
echo -e "  Prochaines étapes :"
echo -e "    ${CYAN}1.${NC} Éteindre la VM :  ${BOLD}sudo shutdown -h now${NC}"
echo -e "    ${CYAN}2.${NC} Depuis l'hôte, exporter en OVA :"
echo -e "       ${BOLD}VBoxManage export <vm-name> -o <fichier>.ova${NC}"
echo -e "    ${CYAN}3.${NC} (Optionnel) Compresser davantage :"
echo -e "       ${BOLD}xz -9 <fichier>.ova${NC}"
echo

if ! $DRY_RUN; then
    # ── Nettoyage final de l'historique de la session courante ─────────────
    # Si le script est sourcé, on désactive l'enregistrement de l'historique
    # pour que RIEN ne soit écrit au logout/shutdown (y compris la commande
    # source elle-même).
    if $SOURCED; then
        history -c
        history -w
        unset HISTFILE
        log_ok "HISTFILE désactivé — aucune trace dans l'historique"
    fi

    echo -e "${YELLOW}La VM va s'éteindre dans 10 secondes...${NC}"
    echo -e "${YELLOW}Ctrl+C pour annuler l'arrêt.${NC}"
    sleep 10
    shutdown -h now
fi
