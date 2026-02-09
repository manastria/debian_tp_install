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
#    - Suppression des clés SSH du serveur (+ régénération au boot)
#    - Génération d'un hostname aléatoire au premier démarrage
#    - Remplissage de zéro (zerofill) pour optimiser la compression OVA
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
            sed -n '3,/^#=====/{ /^#=====/d; s/^#  \?//p }' "$0"
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
log_section "1/7 — Nettoyage APT"

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
log_section "2/7 — Journaux et fichiers temporaires"

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
log_section "3/7 — Historiques shell"

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
log_section "4/7 — Identifiants réseau"

run "Troncature de /etc/machine-id (sera regénéré au boot)" \
    "truncate -s 0 /etc/machine-id && rm -f /var/lib/dbus/machine-id 2>/dev/null || true"

run "Suppression des baux DHCP" \
    "rm -f /var/lib/dhcp/*.leases /var/lib/NetworkManager/*.lease 2>/dev/null || true"

run "Suppression des règles udev persistantes (interfaces réseau)" \
    "rm -f /etc/udev/rules.d/70-persistent-net.rules 2>/dev/null || true"

run "Nettoyage cloud-init (si installé)" \
    "command -v cloud-init &>/dev/null && cloud-init clean --logs --seed 2>/dev/null || true"

#===============================================================================
#  5. CLÉS SSH DU SERVEUR
#===============================================================================
log_section "5/7 — Clés SSH du serveur"

if $SSH_REGEN; then
    run "Suppression des clés SSH du serveur" \
        "rm -f /etc/ssh/ssh_host_*"

    # Service systemd pour régénérer les clés SSH au boot
    if ! $DRY_RUN; then
        log_step "Création du service de régénération SSH au boot"

        cat > /etc/systemd/system/ssh-regen-keys.service << 'UNIT'
[Unit]
Description=Régénérer les clés SSH du serveur au premier démarrage
Before=ssh.service sshd.service
ConditionPathExists=!/etc/ssh/ssh_host_ed25519_key

[Service]
Type=oneshot
ExecStart=/usr/bin/ssh-keygen -A
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

        systemctl daemon-reload
        systemctl enable ssh-regen-keys.service
        log_ok "Service ssh-regen-keys.service activé"
    else
        log_skip "Création du service ssh-regen-keys.service"
    fi
else
    log_warn "Régénération SSH désactivée (--no-ssh-regen)"
fi

#===============================================================================
#  6. HOSTNAME ALÉATOIRE AU BOOT (optionnel)
#===============================================================================
log_section "6/7 — Hostname aléatoire au boot"

if $RANDOM_HOSTNAME; then
    if ! $DRY_RUN; then
        log_step "Création du service de hostname aléatoire"

        cat > /usr/local/bin/set-random-hostname.sh << 'SCRIPT'
#!/usr/bin/env bash
#
# Génère un hostname aléatoire au format : labo-XXXX
# où XXXX est un identifiant hexadécimal de 4 caractères.
#
# S'exécute UNE SEULE FOIS au premier boot, puis se désactive.
#

SENTINEL="/etc/hostname-initialized"

# Sécurité : ne jamais écraser un hostname déjà personnalisé
if [[ -f "$SENTINEL" ]]; then
    logger "random-hostname: sentinelle présente, rien à faire."
    exit 0
fi

PREFIX="labo"
SUFFIX=$(head -c 2 /dev/urandom | od -An -tx1 | tr -d ' \n')
NEW_HOSTNAME="${PREFIX}-${SUFFIX}"

hostnamectl set-hostname "$NEW_HOSTNAME"
echo "$NEW_HOSTNAME" > /etc/hostname

# Mettre à jour /etc/hosts
sed -i "s/127\.0\.1\.1.*/127.0.1.1\t${NEW_HOSTNAME}/" /etc/hosts
if ! grep -q '127\.0\.1\.1' /etc/hosts; then
    echo -e "127.0.1.1\t${NEW_HOSTNAME}" >> /etc/hosts
fi

# Créer la sentinelle et désactiver le service
touch "$SENTINEL"
systemctl disable random-hostname.service
logger "Hostname défini sur : $NEW_HOSTNAME (service désactivé)"
SCRIPT

        chmod +x /usr/local/bin/set-random-hostname.sh

        # Supprimer la sentinelle pour que le prochain boot la déclenche
        rm -f /etc/hostname-initialized

        cat > /etc/systemd/system/random-hostname.service << 'UNIT'
[Unit]
Description=Générer un hostname aléatoire au premier démarrage uniquement
Before=network-pre.target
Wants=network-pre.target
After=systemd-machine-id-setup.service
ConditionPathExists=!/etc/hostname-initialized

[Service]
Type=oneshot
ExecStart=/usr/local/bin/set-random-hostname.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
UNIT

        systemctl daemon-reload
        systemctl enable random-hostname.service
        log_ok "Service random-hostname.service activé"
    else
        log_skip "Création du service random-hostname.service"
    fi
else
    log_warn "Hostname aléatoire désactivé (--no-random-hostname)"
fi

#===============================================================================
#  7. ZEROFILL — Remplissage de zéros pour compression optimale
#===============================================================================
log_section "7/7 — Zerofill (optimisation compression)"

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
