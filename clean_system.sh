#!/bin/bash

# ==============================================================================
# SCRIPT DE NETTOYAGE FINAL POUR TEMPLATE DEBIAN
# ==============================================================================
# Ce script prépare la VM en vue de son clonage.
# Il doit être la dernière opération effectuée avant l'extinction.
#
# --- DEUX MODES DE NETTOYAGE ---
#
# Mode LÉGER (par défaut) : uniquement ce qui est nécessaire à l'unicité des
# clones (clés d'hôte SSH, machine-id, cloud-init si disponible/installable,
# réinitialisation au prochain démarrage) et l'effacement de l'historique.
# Ne touche ni au cache APT, ni aux logs, ni aux fichiers temporaires.
# Sécurité : les clés SSH ne sont supprimées que si un mécanisme de
# régénération au démarrage est confirmé disponible (cloud-init installé,
# ou make_rclocal.sh déjà exécuté) — sinon la VM deviendrait inaccessible
# en SSH au prochain démarrage.
#
# Mode COMPLET (optionnel) : ajoute en plus le nettoyage du cache APT, des
# logs système (rsyslog/journald) et des répertoires temporaires. À activer
# via :
#     CLEAN_SYSTEM_FULL_CLEAN=1 source /chemin/vers/ce/script.sh
#
# En cas de dysfonctionnement constaté sur certaines VMs après un nettoyage
# complet, restez en mode léger (par défaut) le temps d'identifier la cause.
#
# --- PROCÉDURE D'UTILISATION STRICTE ---
# Pour garantir une propreté parfaite sans laisser de traces (historique),
# suivez impérativement ces étapes :
#
# 1. Obtenez un shell root interactif via la commande :
#    $ sudo -i
#
# 2. Une fois dans le shell root (#), exécutez ce script en le "sourçant" :
#    # source /chemin/vers/ce/script.sh
#
# 3. Dès que le script se termine, éteignez la machine SANS QUITTER le shell root :
#    # shutdown -h now
#
# Toute autre méthode laissera des traces de l'opération de nettoyage.
# ==============================================================================

# ==============================================================================
# Mode debug avec journalisation
# ==============================================================================
# 1. Sur la VM cible, activer le debug via
#     ```
#     CLEAN_SYSTEM_DEBUG=1
#     [CLEAN_SYSTEM_DEBUG_LOG=/chemin/log]
#     source /chemin/clean_system.sh
#     ```
#     puis ouvrir le log pour repérer la commande qui précède le logout.
# 2. Après analyse, supprimer le fichier de log si nécessaire pour ne pas laisser de traces.


# --- Sécurité et Robustesse ---
# 'set -e' : Quitte le script immédiatement si une commande échoue.
# 'set -u' : Traite les variables non définies comme une erreur.
CLEAN_SYSTEM_PREV_SHELLOPTS="$(set +o)"
set -eu

# --- Mode debug optionnel ---
CLEAN_SYSTEM_DEBUG="${CLEAN_SYSTEM_DEBUG:-0}"
CLEAN_SYSTEM_DEBUG_LOG="${CLEAN_SYSTEM_DEBUG_LOG:-/root/clean_system_debug.log}"
CLEAN_SYSTEM_DEBUG_ACTIVE=0
CLEAN_SYSTEM_DEBUG_PREV_XTRACE=0
CLEAN_SYSTEM_DEBUG_PREV_PS4=""
CLEAN_SYSTEM_DEBUG_PREV_PS4_WAS_SET=0
CLEAN_SYSTEM_DEBUG_PREV_XTRACEFD=""
CLEAN_SYSTEM_DEBUG_PREV_XTRACEFD_WAS_SET=0
__CLEAN_SYSTEM_DEBUG_PREV_RETURN_TRAP=""
__CLEAN_SYSTEM_DEBUG_PREV_ERR_TRAP=""

clean_system_debug_cleanup() {
    if [[ "${CLEAN_SYSTEM_DEBUG_ACTIVE}" -ne 1 ]]; then
        return 0
    fi

    if [[ "${CLEAN_SYSTEM_DEBUG_PREV_XTRACE}" -eq 0 ]]; then
        set +x
    fi

    if [[ "${CLEAN_SYSTEM_DEBUG_PREV_PS4_WAS_SET}" -eq 1 ]]; then
        PS4="${CLEAN_SYSTEM_DEBUG_PREV_PS4}"
    else
        unset PS4
    fi

    if [[ -n "${__CLEAN_SYSTEM_DEBUG_PREV_RETURN_TRAP}" ]]; then
        eval "${__CLEAN_SYSTEM_DEBUG_PREV_RETURN_TRAP}"
    else
        trap - RETURN
    fi

    if [[ -n "${__CLEAN_SYSTEM_DEBUG_PREV_ERR_TRAP}" ]]; then
        eval "${__CLEAN_SYSTEM_DEBUG_PREV_ERR_TRAP}"
    else
        trap - ERR
    fi

    exec 200>&-

    if [[ "${CLEAN_SYSTEM_DEBUG_PREV_XTRACEFD_WAS_SET}" -eq 1 ]]; then
        BASH_XTRACEFD="${CLEAN_SYSTEM_DEBUG_PREV_XTRACEFD}"
    else
        unset BASH_XTRACEFD
    fi

    CLEAN_SYSTEM_DEBUG_ACTIVE=0
}

if [[ "${CLEAN_SYSTEM_DEBUG}" == "1" ]]; then
    if [[ ${PS4+x} ]]; then
        CLEAN_SYSTEM_DEBUG_PREV_PS4="${PS4}"
        CLEAN_SYSTEM_DEBUG_PREV_PS4_WAS_SET=1
    fi
    if [[ "$-" == *x* ]]; then
        CLEAN_SYSTEM_DEBUG_PREV_XTRACE=1
    fi

    __CLEAN_SYSTEM_DEBUG_PREV_RETURN_TRAP="$(trap -p RETURN || true)"
    __CLEAN_SYSTEM_DEBUG_PREV_ERR_TRAP="$(trap -p ERR || true)"

    mkdir -p "$(dirname "${CLEAN_SYSTEM_DEBUG_LOG}")"
    exec 200>>"${CLEAN_SYSTEM_DEBUG_LOG}"
    printf '\n===== debug session %s =====\n' "$(date '+%Y-%m-%d %H:%M:%S')" >&200
    echo "[DEBUG] Mode debug actif. Journal : ${CLEAN_SYSTEM_DEBUG_LOG}"
    echo "[DEBUG] Mode debug actif. Journal : ${CLEAN_SYSTEM_DEBUG_LOG}" >&200

    if [[ ${BASH_XTRACEFD+x} ]]; then
        CLEAN_SYSTEM_DEBUG_PREV_XTRACEFD="${BASH_XTRACEFD}"
        CLEAN_SYSTEM_DEBUG_PREV_XTRACEFD_WAS_SET=1
    fi

    BASH_XTRACEFD=200
    PS4='+ $(date "+%Y-%m-%d %H:%M:%S") [${BASH_SOURCE##*/}:${LINENO}] '

    if [[ "${CLEAN_SYSTEM_DEBUG_PREV_XTRACE}" -eq 0 ]]; then
        set -x
    fi

    CLEAN_SYSTEM_DEBUG_ACTIVE=1
    trap clean_system_debug_cleanup RETURN
    trap clean_system_debug_cleanup ERR
fi

# --- Mode de nettoyage complet (optionnel, désactivé par défaut) ---
# CLEAN_SYSTEM_FULL_CLEAN=1 source clean_system.sh pour activer en plus le
# nettoyage APT/logs/tmp/udev (voir en-tête du fichier).
CLEAN_SYSTEM_FULL_CLEAN="${CLEAN_SYSTEM_FULL_CLEAN:-0}"

# --- Couleurs optionnelles pour l'affichage ---
CLEAN_SYSTEM_COLOR_RESET=""
CLEAN_SYSTEM_COLOR_INFO=""
CLEAN_SYSTEM_COLOR_SUCCESS=""
CLEAN_SYSTEM_COLOR_ACTION=""
CLEAN_SYSTEM_COLOR_WARN=""

if [[ -t 1 ]]; then
    CLEAN_SYSTEM_COLOR_RESET=$'\033[0m'
    CLEAN_SYSTEM_COLOR_INFO=$'\033[1;34m'
    CLEAN_SYSTEM_COLOR_SUCCESS=$'\033[1;32m'
    CLEAN_SYSTEM_COLOR_ACTION=$'\033[1;33m'
    CLEAN_SYSTEM_COLOR_WARN=$'\033[1;31m'
fi

clean_system_print_color() {
    local color="$1"
    shift
    if [[ -n "$color" ]]; then
        printf '%b%s%b\n' "$color" "$*" "$CLEAN_SYSTEM_COLOR_RESET"
    else
        printf '%s\n' "$*"
    fi
}

clean_system_info() {
    clean_system_print_color "$CLEAN_SYSTEM_COLOR_INFO" "$@"
}

clean_system_success() {
    clean_system_print_color "$CLEAN_SYSTEM_COLOR_SUCCESS" "$@"
}

clean_system_action() {
    clean_system_print_color "$CLEAN_SYSTEM_COLOR_ACTION" "$@"
}

clean_system_warn() {
    clean_system_print_color "$CLEAN_SYSTEM_COLOR_WARN" "$@"
}

clean_system_error() {
    if [[ -n "$CLEAN_SYSTEM_COLOR_WARN" ]]; then
        printf '%b%s%b\n' "$CLEAN_SYSTEM_COLOR_WARN" "$*" "$CLEAN_SYSTEM_COLOR_RESET" >&2
    else
        printf '%s\n' "$*" >&2
    fi
}

# Vérifie que make_rclocal.sh a bien été exécuté sur cette VM : /etc/rc.local
# doit contenir la logique de réinitialisation (do_first_boot) et le service
# rc-local.service doit être activé. Sans ça, planter /etc/do_first_boot ou
# supprimer les clés SSH en comptant sur ce relais serait sans effet.
clean_system_rc_local_ready() {
    [ -x /etc/rc.local ] || return 1
    grep -q "do_first_boot" /etc/rc.local 2>/dev/null || return 1
    systemctl is-enabled --quiet rc-local.service 2>/dev/null || return 1
    return 0
}

# --- Gardes-fous ---

# 1. Vérifier si le script est sourcé.
# ${BASH_SOURCE[0]} est le chemin du script.
# ${0} est le nom du processus en cours. Ils sont différents si le script est sourcé.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    clean_system_error "ERREUR : Ce script ne doit pas être exécuté, mais sourcé."
    clean_system_error "Utilisez la commande : source ${BASH_SOURCE[0]}"
    exit 1
fi

# 2. Vérifier les privilèges root.
if [[ "$(id -u)" -ne 0 ]]; then
   clean_system_error "ERREUR : Ce script doit être sourcé depuis un shell root."
   clean_system_error "Commencez par obtenir un shell root avec 'sudo -i' ou 'sudo su -'."
   return 1
fi

clean_system_info "--- Démarrage du nettoyage de la VM ---"
if [[ "${CLEAN_SYSTEM_FULL_CLEAN}" == "1" ]]; then
    clean_system_info "Mode complet activé (CLEAN_SYSTEM_FULL_CLEAN=1) : APT, logs, tmp et udev inclus."
else
    clean_system_info "Mode léger (par défaut) : APT, logs, tmp et udev ne seront PAS touchés."
    clean_system_info "-> CLEAN_SYSTEM_FULL_CLEAN=1 source ... pour activer le nettoyage complet."
fi

# --- 1. Réinitialisation du machine-id (essentiel pour l'unicité des clones) ---
clean_system_info "[+] Réinitialisation du machine-id..."
truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ]; then
    rm /var/lib/dbus/machine-id
    ln -s /etc/machine-id /var/lib/dbus/machine-id
fi

# --- 2. cloud-init pour la généralisation (approche moderne) ---
# cloud-init sait régénérer proprement clés SSH/hostname/réseau au premier
# démarrage. On l'installe s'il est absent, en mode best-effort : l'absence
# de réseau ne doit pas faire échouer le reste du script.
CLEAN_SYSTEM_CLOUD_INIT_OK=0
if ! command -v cloud-init &> /dev/null; then
    clean_system_info "[+] cloud-init absent, tentative d'installation..."
    if apt-get update -qq > /dev/null 2>&1 && apt-get install -y cloud-init > /dev/null 2>&1; then
        clean_system_success "cloud-init installé."
    else
        clean_system_warn "Installation de cloud-init impossible (pas de réseau ?), étape ignorée."
    fi
fi

if command -v cloud-init &> /dev/null; then
    CLEAN_SYSTEM_CLOUD_INIT_OK=1
    # Sur une VM sans service de métadonnées cloud (VirtualBox), forcer le
    # datasource "None" : sans cela, cloud-init sonde AWS/Azure/GCE/... au
    # démarrage, ce qui ralentit le boot, voire se désactive faute de réponse.
    if [ ! -f /etc/cloud/cloud.cfg.d/99-datasource-none.cfg ]; then
        cat > /etc/cloud/cloud.cfg.d/99-datasource-none.cfg <<'EOF'
datasource_list: [ None ]
EOF
    fi
    clean_system_info "[+] Nettoyage de cloud-init..."
    cloud-init clean --logs --seed
fi

# --- 3. Réinitialisation au prochain démarrage via /etc/rc.local ---
# La présence de /etc/do_first_boot déclenche la réinitialisation du nom
# d'hôte et des clés SSH au prochain démarrage, via /etc/rc.local. On vérifie
# que make_rclocal.sh a bien été exécuté avant de s'y fier : sinon le flag
# planté ici ne serait jamais consommé.
CLEAN_SYSTEM_RC_LOCAL_OK=0
if clean_system_rc_local_ready; then
    CLEAN_SYSTEM_RC_LOCAL_OK=1
    clean_system_info "[+] Création du fichier /etc/do_first_boot pour réinitialisation au prochain démarrage..."
    touch /etc/do_first_boot
else
    clean_system_warn "[!] /etc/rc.local ne semble pas prêt (make_rclocal.sh a-t-il été exécuté ?)."
    clean_system_warn "    /etc/do_first_boot n'est pas créé : le hostname ne sera pas réinitialisé par ce relais."
fi

# --- 4. Suppression des clés d'hôte SSH (sécurité) ---
# On ne supprime les clés que si un mécanisme de régénération au démarrage
# est confirmé (cloud-init ou rc.local + do_first_boot) : sinon la VM se
# retrouverait sans clé SSH, donc inaccessible en SSH au prochain démarrage.
if [[ "${CLEAN_SYSTEM_CLOUD_INIT_OK}" -eq 1 || "${CLEAN_SYSTEM_RC_LOCAL_OK}" -eq 1 ]]; then
    clean_system_info "[+] Suppression des clés d'hôte SSH..."
    rm -f /etc/ssh/ssh_host_*_key*
else
    clean_system_warn "[!] Aucun mécanisme de régénération SSH confirmé (ni cloud-init, ni rc.local)."
    clean_system_warn "    Clés d'hôte SSH CONSERVÉES pour ne pas rendre la VM inaccessible en SSH."
    clean_system_warn "    -> Lancez make_rclocal.sh (ou assurez un accès réseau pour cloud-init), puis relancez ce script."
fi

# --- 5. Nettoyage de l'historique Shell (LA solution à votre problème) ---
clean_system_info "[+] Effacement de l'historique shell..."

# Efface l'historique de la session courante en mémoire
history -c
history -w  # Écrit un historique vide sur le disque

# Supprime les fichiers d'historique de tous les utilisateurs
find /root /home -type f -name ".*_history" -delete

# La commande MAGIQUE : désactive l'enregistrement de l'historique pour
# la session shell courante. Ainsi, lors du logout ou du shutdown, rien
# ne sera écrit.
unset HISTFILE

# --- 6. Nettoyage complet (optionnel, CLEAN_SYSTEM_FULL_CLEAN=1) ---
if [[ "${CLEAN_SYSTEM_FULL_CLEAN}" == "1" ]]; then

    # Nettoyage du gestionnaire de paquets APT
    clean_system_info "[+] Nettoyage du cache APT..."
    apt-get autoremove -y
    apt-get autoclean -y
    apt-get clean -y

    # Nettoyage des logs
    clean_system_info "[+] Nettoyage des logs système (rsyslog et journald)..."

    # Arrêt du service de logging pour éviter de nouveaux logs pendant le nettoyage
    if systemctl is-active --quiet rsyslog; then
        clean_system_info "Le service rsyslog est actif, arrêt en cours..."
        systemctl stop rsyslog
    else
        clean_system_info "Info : Le service rsyslog n'est pas installé ou est déjà inactif."
    fi

    # Nettoyage des logs traditionnels (/var/log)
    # Utilisation de find pour être plus précis et efficace
    find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
    find /var/log -type f -name "*.gz" -delete
    find /var/log -type f -name "*.1" -delete
    truncate -s 0 /var/log/btmp
    truncate -s 0 /var/log/dmesg
    truncate -s 0 /var/log/lastlog
    rm -rf /var/log/apt/*

    # Nettoyage du journal systemd (très important !)
    journalctl --rotate
    journalctl --vacuum-time=1s

    # Nettoyage des fichiers temporaires
    clean_system_info "[+] Nettoyage des répertoires temporaires..."
    find /tmp -mindepth 1 -delete
    find /var/tmp -mindepth 1 -delete

    # Nettoyage des règles réseau persistantes (évite les conflits de nom d'interface)
    clean_system_info "[+] Suppression des règles udev..."
    if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
        rm -f /etc/udev/rules.d/70-persistent-net.rules
    fi
else
    clean_system_info "[i] Nettoyage complet ignoré (APT, logs, tmp, udev)."
fi

# --- Finalisation ---
printf '\n'
clean_system_success "✅ Nettoyage terminé !"
if [[ "${CLEAN_SYSTEM_FULL_CLEAN}" != "1" ]]; then
    clean_system_info "(mode léger : APT, logs, tmp et udev non touchés — CLEAN_SYSTEM_FULL_CLEAN=1 pour un nettoyage complet)"
fi
clean_system_action "========================================================================"
clean_system_action "ACTION REQUISE :"
clean_system_action "Arrêtez la VM MAINTENANT sans vous déconnecter avec la commande :"
clean_system_action "shutdown -h now"
clean_system_action "Ne pas se déconnecter puis se reconnecter, car cela recréerait un historique."
clean_system_action "========================================================================"

if [[ -n "${CLEAN_SYSTEM_PREV_SHELLOPTS:-}" ]]; then
    eval "${CLEAN_SYSTEM_PREV_SHELLOPTS}"
    unset CLEAN_SYSTEM_PREV_SHELLOPTS
fi
