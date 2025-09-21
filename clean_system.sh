#!/bin/bash

# ==============================================================================
# SCRIPT DE NETTOYAGE FINAL POUR TEMPLATE DEBIAN
# ==============================================================================
# ATTENTION : Ce script nettoie en profondeur la VM (logs, cache, historique,
# identifiants uniques) en vue de son clonage.
# Il doit être la dernière opération effectuée avant l'extinction.
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

# --- 1. Nettoyage du gestionnaire de paquets APT ---
clean_system_info "[+] Nettoyage du cache APT..."
apt-get autoremove -y
apt-get autoclean -y
apt-get clean -y

# --- 2. Nettoyage des logs ---
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

# --- 3. Nettoyage des fichiers temporaires ---
clean_system_info "[+] Nettoyage des répertoires temporaires..."
find /tmp -mindepth 1 -delete
find /var/tmp -mindepth 1 -delete

# --- 4. Généralisation de la VM pour le clonage ---

# Nettoyage des règles réseau persistantes (évite les conflits de nom d'interface)
clean_system_info "[+] Suppression des règles udev..."
if [ -f /etc/udev/rules.d/70-persistent-net.rules ]; then
    rm -f /etc/udev/rules.d/70-persistent-net.rules
fi

# Suppression des clés d'hôte SSH (sécurité)
# Elles seront régénérées au prochain démarrage par le service SSH.
clean_system_info "[+] Suppression des clés d'hôte SSH..."
rm -f /etc/ssh/ssh_host_*_key*

# Réinitialisation du machine-id (essentiel pour l'unicité des clones)
clean_system_info "[+] Réinitialisation du machine-id..."
truncate -s 0 /etc/machine-id
if [ -f /var/lib/dbus/machine-id ]; then
    rm /var/lib/dbus/machine-id
    ln -s /etc/machine-id /var/lib/dbus/machine-id
fi

# Utilisation de cloud-init pour la généralisation (approche moderne)
# Si cloud-init est installé, c'est la méthode recommandée pour gérer la
# configuration au premier démarrage (hostname, clés SSH, etc.).
if command -v cloud-init &> /dev/null; then
    clean_system_info "[+] Nettoyage de cloud-init..."
    cloud-init clean --logs --seed
fi

# --- 5. Préparation pour la réinitialisation au prochain démarrage ---
# La présence de ce fichier déclenche la réinitialisation du nom d’hôte et des clés SSH au prochain démarrage via /etc/rc.local
clean_system_info "[+] Création du fichier /etc/do_first_boot pour réinitialisation au prochain démarrage..."
touch /etc/do_first_boot

# --- 6. Nettoyage de l'historique Shell (LA solution à votre problème) ---
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

# --- Finalisation ---
printf '\n'
clean_system_success "✅ Nettoyage terminé !"
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
